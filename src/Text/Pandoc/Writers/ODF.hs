{-# LANGUAGE OverloadedStrings #-}
{- |
   Module      : Text.Pandoc.Writers.ODF
   Copyright   : Copyright (C) 2026 John MacFarlane
   License     : GNU GPL, version 2 or above

   Maintainer  : John MacFarlane <jgm@berkeley.edu>
   Stability   : alpha
   Portability : portable

Conversion of a Pandoc math element to an OpenDocument Formula file.
-}
module Text.Pandoc.Writers.ODF
  ( writeODF
  , formulaDocumentSettings
  , firstMath
  ) where

import Codec.Archive.Zip
import Control.Applicative ((<|>))
import Control.Monad.Except (throwError)
import qualified Data.ByteString.Lazy as B
import Data.Char (isDigit)
import qualified Data.Text as T
import Data.Time (formatTime, defaultTimeLocale)
import Text.DocLayout
import Text.DocTemplates (FromContext(lookupContext))
import Text.Pandoc.Class.PandocMonad (PandocMonad, report)
import qualified Text.Pandoc.Class.PandocMonad as P
import Text.Pandoc.Definition
import Text.Pandoc.Error (PandocError(PandocSomeError))
import Text.Pandoc.Logging
import Text.Pandoc.Options (WriterOptions(..))
import Text.Pandoc.Shared (tshow)
import Text.Pandoc.UTF8 (fromStringLazy)
import Text.Pandoc.Walk (query)
import Text.Pandoc.Writers.Shared (lookupMetaString)
import Text.Pandoc.XML
import Text.TeXMath (DisplayType(..), readTeX, writeMathML, writeStarMath)
import qualified Text.XML.Light as XL

-- | Produce an OpenDocument Formula file from the first math element in
-- a Pandoc document.
writeODF :: PandocMonad m
         => WriterOptions
         -> Pandoc
         -> m B.ByteString
writeODF opts doc@(Pandoc meta _) =
  case firstMath doc of
    Nothing -> throwError $
      PandocSomeError "Cannot write ODF formula: document contains no math."
    Just (mathType, math) -> do
      case readTeX math of
        Left e -> do
          report $ CouldNotConvertTeXMath math e
          throwError $
            PandocSomeError "Cannot write ODF formula: could not convert TeX math."
        Right exps -> do
          epochtime <- floor <$> P.getPOSIXTime
          utctime <- P.getTimestamp
          let dt = case mathType of
                     InlineMath  -> DisplayInline
                     DisplayMath -> DisplayBlock
          let conf = XL.useShortEmptyTags (const False) XL.defaultConfigPP
          let mathml = XL.ppcTopElement conf $
                annotateMathML (writeMathML dt exps) (writeStarMath dt exps)
          let isTextMode = mathType == InlineMath
          mbBaseFontHeight <- formulaBaseFontHeightFrom opts meta
          let mimetypeEntry = toEntry "mimetype" epochtime $
                fromStringLazy "application/vnd.oasis.opendocument.formula"
          let archive = addEntryToArchive mimetypeEntry $
                foldr addEntryToArchive emptyArchive
                  [ toEntry "META-INF/manifest.xml" epochtime manifest
                  , toEntry "meta.xml" epochtime $
                      metaXml (T.pack $ formatTime defaultTimeLocale "%FT%XZ" utctime)
                  , toEntry "settings.xml" epochtime $
                      formulaDocumentSettings isTextMode mbBaseFontHeight
                  , toEntry "content.xml" epochtime $
                      fromStringLazy mathml
                  ]
          return $ fromArchive archive

firstMath :: Pandoc -> Maybe (MathType, T.Text)
firstMath doc =
  case query go doc of
    x:_ -> Just x
    []  -> Nothing
 where
  go (Math mathType math) = [(mathType, math)]
  go _                    = []

-- | Annotate MathML with the StarMath source used by LibreOffice's formula
-- editor. This keeps imported formulas editable without forcing LibreOffice
-- to reconstruct source from the MathML tree.
annotateMathML :: XL.Element -> T.Text -> XL.Element
annotateMathML e starmath =
  math $ XL.unode "semantics"
    [ cs
    , XL.unode "annotation" (annotAttrs, T.unpack starmath)
    ]
 where
  cs = case XL.elChildren e of
         []  -> XL.unode "mrow" ()
         [x] -> x
         xs  -> XL.unode "mrow" xs
  math childs = XL.Element q as [XL.Elem childs] l
    where
      XL.Element q as _ l = e
  annotAttrs = [XL.Attr (XL.unqual "encoding") "StarMath 5.0"]

formulaBaseFontHeightFrom :: PandocMonad m => WriterOptions -> Meta -> m (Maybe Int)
formulaBaseFontHeightFrom opts meta =
  case lookupContext "formula-base-font-height" (writerVariables opts) <|>
       nonEmpty (lookupMetaString "formula-base-font-height" meta) of
    Nothing -> return Nothing
    Just t ->
      case parsePointSize t of
        Just n  -> return $ Just n
        Nothing -> throwError $ PandocSomeError $
          "Invalid formula-base-font-height " <> t <>
          ". Expected an integer point size, optionally followed by 'pt'."
 where
  nonEmpty t
    | T.null t  = Nothing
    | otherwise = Just t
  parsePointSize t =
    let t' = T.strip t
        (digits, unit) = T.span isDigit t'
    in if T.null digits || T.toLower (T.strip unit) `notElem` ["", "pt"]
          then Nothing
          else Just (read $ T.unpack digits)

-- | Formula-specific document settings.
formulaDocumentSettings :: Bool -> Maybe Int -> B.ByteString
formulaDocumentSettings isTextMode mbBaseFontHeight = fromStringLazy $ render Nothing
    $ text "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
    $$
    inTags True "office:document-settings"
      [("xmlns:office","urn:oasis:names:tc:opendocument:xmlns:office:1.0")
      ,("xmlns:xlink","http://www.w3.org/1999/xlink")
      ,("xmlns:config","urn:oasis:names:tc:opendocument:xmlns:config:1.0")
      ,("xmlns:ooo","http://openoffice.org/2004/office")
      ,("office:version","1.3")] (
       inTagsSimple "office:settings" $
         inTags False "config:config-item-set"
           [("config:name", "ooo:configuration-settings")] $
             vcat
               [ configItem "IsTextMode" "boolean" $
                   if isTextMode then "true" else "false"
               , maybe empty
                   (configItem "BaseFontHeight" "short" . tshow)
                   mbBaseFontHeight
               ])

configItem :: T.Text -> T.Text -> T.Text -> Doc String
configItem itemName itemType =
  inTags False "config:config-item"
    [("config:name", itemName), ("config:type", itemType)] . text . T.unpack

manifest :: B.ByteString
manifest = fromStringLazy $ render Nothing
    $ text "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
    $$
    inTags True "manifest:manifest"
      [("xmlns:manifest","urn:oasis:names:tc:opendocument:xmlns:manifest:1.0")
      ,("manifest:version","1.3")]
      (
        vcat
          [ fileEntry "application/vnd.oasis.opendocument.formula" "/" True
          , fileEntry "application/xml" "content.xml" False
          , fileEntry "application/xml" "settings.xml" False
          , fileEntry "application/xml" "meta.xml" False
          ]
      )
 where
  fileEntry mediaType fullPath versioned =
    selfClosingTag "manifest:file-entry" $
      [("manifest:media-type", mediaType)
      ,("manifest:full-path", fullPath)] ++
      [("manifest:version", "1.3") | versioned]

metaXml :: T.Text -> B.ByteString
metaXml timestamp = fromStringLazy $ render Nothing
    $ text "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
    $$
    inTags True "office:document-meta"
      [("xmlns:office","urn:oasis:names:tc:opendocument:xmlns:office:1.0")
      ,("xmlns:dc","http://purl.org/dc/elements/1.1/")
      ,("xmlns:meta","urn:oasis:names:tc:opendocument:xmlns:meta:1.0")
      ,("office:version","1.3")]
      (
        inTags True "office:meta" [] $
          inTagsSimple "meta:generator" "Pandoc"
          $$
          inTagsSimple "meta:creation-date" (text $ T.unpack timestamp)
          $$
          inTagsSimple "dc:date" (text $ T.unpack timestamp)
      )
