{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE ScopedTypeVariables #-}
{- |
   Module      : Text.Pandoc.Readers.CommonMark
   Copyright   : Copyright (C) 2015-2024 John MacFarlane
   License     : GNU GPL, version 2 or above

   Maintainer  : John MacFarlane <jgm@berkeley.edu>
   Stability   : alpha
   Portability : portable

Conversion of CommonMark-formatted plain text to 'Pandoc' document.

CommonMark is a strongly specified variant of Markdown: http://commonmark.org.
-}
module Text.Pandoc.Readers.CommonMark (readCommonMark)
where

import Commonmark
import Commonmark.Extensions
import Commonmark.Inlines (InlineParser)
import Commonmark.Pandoc
import Commonmark.TokParsers (satisfyTok, symbol)
import Control.Applicative ((<|>))
import Data.Char (isAlphaNum)
import Data.Text (Text)
import qualified Data.Text as T
import Text.Pandoc.Class.PandocMonad (PandocMonad)
import Text.Pandoc.Definition
import Text.Pandoc.Builder as B
import Text.Pandoc.Options
import Text.Pandoc.Readers.Metadata (yamlMetaBlock)
import Control.Monad (MonadPlus(mzero), (<=<))
import Control.Monad.Except (  MonadError(throwError) )
import Control.Monad.State.Strict (State, evalState, get, put)
import Data.Functor.Identity (Identity, runIdentity)
import Data.Typeable
import Text.Pandoc.Parsing.Citations (citeKey)
import Text.Pandoc.Parsing.State (ParserState)
import Text.Pandoc.Parsing (runParserT, getInput, getPosition,
                            runF, defaultParserState, option, many1, many,
                            manyTill, lookAhead, eof, try, notFollowedBy,
                            anyChar,
                            Sources(..), ToSources(..), ParsecT, Future,
                            incSourceLine, fromParsecError)
import Text.Pandoc.Walk (walk, walkM)
import qualified Data.Attoparsec.Text as A
import qualified Text.Parsec as P

-- | Parse a CommonMark formatted string into a 'Pandoc' structure.
readCommonMark :: (PandocMonad m, ToSources a)
               => ReaderOptions -> a -> m Pandoc
readCommonMark opts s
  | isEnabled Ext_yaml_metadata_block opts = do
    let sources = toSources s
    let firstSourceName = case unSources sources of
                               ((pos,_):_) -> sourceName pos
                               _ -> ""
    let toks = concatMap sourceToToks (unSources sources)
    res <- runParserT (do meta <- yamlMetaBlock (metaValueParser opts)
                          pos <- getPosition
                          rest <- getInput
                          let rest' = case rest of
                                -- update position of first source (#7863):
                                Sources ((_,t):xs) -> Sources ((pos,t):xs)
                                _ -> rest
                          return (meta, rest'))
                      defaultParserState firstSourceName sources
    case res of
      Left _ -> readCommonMarkBody opts sources toks
      Right (meta, rest) -> do
        -- strip off metadata section and parse body
        let body = concatMap sourceToToks (unSources rest)
        Pandoc _ bs <- readCommonMarkBody opts sources body
        return $ Pandoc (runF meta defaultParserState) bs
  | otherwise = do
    let sources = toSources s
    let toks = concatMap sourceToToks (unSources sources)
    readCommonMarkBody opts sources toks

makeFigures :: Block -> Block
makeFigures (Para [Image (ident,classes,kvs) alt (src,tit)])
  | not (null alt) =
  Figure (ident,[],[])
    (Caption Nothing [Plain alt])
    [Plain [Image ("",classes,kvs) alt (src,tit)]]
makeFigures b = b

makeFigureDivs :: Block -> Block
makeFigureDivs (Div (ident, classes, kvs) blocks)
  | "figure" `elem` classes
  , Just (body, figCaption) <- figureDivParts blocks =
      Figure (ident, filter (/= "figure") classes, kvs) figCaption body
makeFigureDivs b = b

figureDivParts :: [Block] -> Maybe ([Block], Caption)
figureDivParts blocks =
  case break isCaptionDiv blocks of
    (body, []) ->
      Just (body, Caption Nothing [])
    (before, Div (_, _, captionKvs) captionBlocks : after) ->
      let shortCaption = lookup "short-caption" captionKvs >>= textShortCaption
      in Just (before ++ after, Caption shortCaption captionBlocks)
    _ ->
      Nothing

isCaptionDiv :: Block -> Bool
isCaptionDiv (Div (_, classes, _) _) = "caption" `elem` classes
isCaptionDiv _ = False

textShortCaption :: Text -> Maybe [Inline]
textShortCaption t
  | T.null (T.strip t) = Nothing
  | otherwise = Just (textInlines t)

sourceToToks :: (SourcePos, Text) -> [Tok]
sourceToToks (pos, s) = map adjust $ tokenize (sourceName pos) s
 where
   adjust = case sourceLine pos of
              1 -> id
              n -> \tok -> tok{ tokPos =
                                  incSourceLine (tokPos tok) (n - 1) }


metaValueParser :: Monad m
                => ReaderOptions -> ParsecT Sources st m (Future st MetaValue)
metaValueParser opts = do
  inp <- option "" $ T.pack <$> many1 anyChar
  let toks = concatMap sourceToToks (unSources (toSources inp))
  case runIdentity (parseCommonmarkWith (specFor opts) toks) of
     Left _ -> mzero
     Right (Cm bls :: Cm () Blocks) -> return $ return $ B.toMetaValue bls

readCommonMarkBody :: PandocMonad m => ReaderOptions -> Sources -> [Tok] -> m Pandoc
readCommonMarkBody opts s toks =
  (if isEnabled Ext_figure_divs opts
      then walk makeFigureDivs
      else id) .
  (if isEnabled Ext_implicit_figures opts
      then walk makeFigures
      else id) .
  (if isEnabled Ext_citations opts
      then resolveCommonMarkCitations
      else id) .
  (if isEnabled Ext_tex_math_gfm opts
      then walk handleGfmMath
      else id) .
  (if readerStripComments opts
      then walk stripBlockComments . walk stripInlineComments
      else id) <$>
  if isEnabled Ext_sourcepos opts || isEnabled Ext_sourcepos_sparse opts
     then case runIdentity (parseCommonmarkWith (specFor opts) toks) of
            Left err -> throwError $ fromParsecError s err
            Right (Cm bls :: Cm SourceRange Blocks) ->
              return $ (if isEnabled Ext_sourcepos_sparse opts &&
                           not (isEnabled Ext_sourcepos opts)
                           then sparseSourcepos
                           else id) $ B.doc bls
     else case runIdentity (parseCommonmarkWith (specFor opts) toks) of
            Left err -> throwError $ fromParsecError s err
            Right (Cm bls :: Cm () Blocks) -> return $ B.doc bls

sparseSourceposStride :: Int
sparseSourceposStride = 10

sparseSourcepos :: Pandoc -> Pandoc
sparseSourcepos = walk sparseSourceposInlines

data SparseSourceposState = SparseSourceposState
  { sparseSourceposWords :: !Int }

sparseSourceposInlines :: [Inline] -> [Inline]
sparseSourceposInlines ils =
  evalState (concat <$> mapM sparseSourceposInline ils)
            (SparseSourceposState 0)

sparseSourceposInline :: Inline -> State SparseSourceposState [Inline]
sparseSourceposInline inline@(Span attr ils)
  | isSourceposWrapper attr = do
      st <- get
      let wordsSinceAnchor = sparseSourceposWords st + inlinesWordCount ils
      let keepAnchor = containsSparseSourceposAnchor ils ||
                       wordsSinceAnchor >= sparseSourceposStride
      if keepAnchor
         then put (SparseSourceposState 0) >> return [inline]
         else put (SparseSourceposState wordsSinceAnchor) >> return ils
sparseSourceposInline inline = do
  st <- get
  put $ SparseSourceposState $
    sparseSourceposWords st + inlineWordCount inline
  return [inline]

containsSparseSourceposAnchor :: [Inline] -> Bool
containsSparseSourceposAnchor = any go
 where
  go Code{} = True
  go Cite{} = True
  go Math{} = True
  go Link{} = True
  go Image{} = True
  go (Emph ils) = containsSparseSourceposAnchor ils
  go (Underline ils) = containsSparseSourceposAnchor ils
  go (Strong ils) = containsSparseSourceposAnchor ils
  go (Strikeout ils) = containsSparseSourceposAnchor ils
  go (Superscript ils) = containsSparseSourceposAnchor ils
  go (Subscript ils) = containsSparseSourceposAnchor ils
  go (SmallCaps ils) = containsSparseSourceposAnchor ils
  go (Quoted _ ils) = containsSparseSourceposAnchor ils
  go (Span _ ils) = containsSparseSourceposAnchor ils
  go _ = False

inlinesWordCount :: [Inline] -> Int
inlinesWordCount = sum . map inlineWordCount

inlineWordCount :: Inline -> Int
inlineWordCount (Str t) = length (T.words t)
inlineWordCount (Emph ils) = inlinesWordCount ils
inlineWordCount (Underline ils) = inlinesWordCount ils
inlineWordCount (Strong ils) = inlinesWordCount ils
inlineWordCount (Strikeout ils) = inlinesWordCount ils
inlineWordCount (Superscript ils) = inlinesWordCount ils
inlineWordCount (Subscript ils) = inlinesWordCount ils
inlineWordCount (SmallCaps ils) = inlinesWordCount ils
inlineWordCount (Quoted _ ils) = inlinesWordCount ils
inlineWordCount (Cite _ ils) = inlinesWordCount ils
inlineWordCount (Link _ ils _) = inlinesWordCount ils
inlineWordCount (Image _ ils _) = inlinesWordCount ils
inlineWordCount (Span _ ils) = inlinesWordCount ils
inlineWordCount _ = 0

handleGfmMath :: Block -> Block
handleGfmMath (CodeBlock ("",["math"],[]) raw) = Para [Math DisplayMath raw]
handleGfmMath x = walk handleGfmMathInline x

handleGfmMathInline :: Inline -> Inline
handleGfmMathInline (Math InlineMath math'') =
  let math' = T.replace "\\\\{" "\\{" . T.replace "\\\\}" "\\}" $ math''
              -- see #10631
      (ticks, rest) = T.span (== '`') math'
  in  if T.null ticks
         then Math InlineMath math'
         else case T.stripSuffix ticks rest of
                Just middle | not (T.null middle) && (T.last middle /= '`')
                             -> Math InlineMath middle
                _ -> Math InlineMath math'
handleGfmMathInline x = x

stripBlockComments :: Block -> Block
stripBlockComments (RawBlock (B.Format "html") s) =
  RawBlock (B.Format "html") (removeComments s)
stripBlockComments x = x

stripInlineComments :: Inline -> Inline
stripInlineComments (RawInline (B.Format "html") s) =
  RawInline (B.Format "html") (removeComments s)
stripInlineComments x = x

removeComments :: Text -> Text
removeComments s =
  either (const s) id $ A.parseOnly pRemoveComments s
 where
  pRemoveComments = mconcat <$> A.many'
    ("" <$ (A.string "<!--" *> A.scan (0 :: Int) scanChar <* A.char '>') <|>
     (A.takeWhile1 (/= '<')) <|>
     (A.string "<"))
  scanChar st c =
    case c of
      '-' -> Just (st + 1)
      '>' | st >= 2 -> Nothing
      _ -> Just 0

specFor :: (Monad m, Typeable m, Typeable a,
            Rangeable (Cm a Inlines), Rangeable (Cm a Blocks))
        => ReaderOptions -> SyntaxSpec m (Cm a Inlines) (Cm a Blocks)
specFor opts = foldr ($) defaultSyntaxSpec exts
 where
  exts = [ (hardLineBreaksSpec <>) | isEnabled Ext_hard_line_breaks opts ] ++
         [ (smartPunctuationSpec <>) | isEnabled Ext_smart opts ] ++
         [ (strikethroughSpec <>) | isEnabled Ext_strikeout opts ] ++
         [ (superscriptSpec <>) | isEnabled Ext_superscript opts ] ++
         [ (subscriptSpec <>) | isEnabled Ext_subscript opts ] ++
         [ (mathSpec <>) | isEnabled Ext_tex_math_dollars opts ] ++
         [ (fancyListSpec <>) | isEnabled Ext_fancy_lists opts ] ++
         [ (fencedDivSpec <>) | isEnabled Ext_fenced_divs opts ] ++
         [ (bracketedSpanSpec <>) | isEnabled Ext_bracketed_spans opts ] ++
         [ (commonmarkCitationSpec <>)
           | isEnabled Ext_citations opts ] ++
         [ (rawAttributeSpec <>) | isEnabled Ext_raw_attribute opts ] ++
         [ (attributesSpec <>) | isEnabled Ext_attributes opts ] ++
         [ (alertSpec <>) | isEnabled Ext_alerts opts ] ++
         [ (<> pipeTableSpec) | isEnabled Ext_pipe_tables opts ] ++
            -- see #6739
         [ (autolinkSpec <>) | isEnabled Ext_autolink_bare_uris opts ] ++
         [ (emojiSpec <>) | isEnabled Ext_emoji opts ] ++
         [ (autoIdentifiersSpec <>)
           | isEnabled Ext_gfm_auto_identifiers opts
           , not (isEnabled Ext_ascii_identifiers opts) ] ++
         [ (autoIdentifiersAsciiSpec <>)
           | isEnabled Ext_gfm_auto_identifiers opts
           , isEnabled Ext_ascii_identifiers opts ] ++
         [ (implicitHeadingReferencesSpec <>)
           | isEnabled Ext_implicit_header_references opts ] ++
         [ (footnoteSpec <>) | isEnabled Ext_footnotes opts ] ++
         [ (definitionListSpec <>) | isEnabled Ext_definition_lists opts ] ++
         [ (taskListSpec <>) | isEnabled Ext_task_lists opts ] ++
         [ (wikilinksSpec TitleAfterPipe <>)
           | isEnabled Ext_wikilinks_title_after_pipe opts ] ++
         [ (wikilinksSpec TitleBeforePipe <>)
           | isEnabled Ext_wikilinks_title_before_pipe opts ] ++
         [ (rebaseRelativePathsSpec <>)
           | isEnabled Ext_rebase_relative_paths opts ]

commonmarkCitationSpec :: Monad m
                       => SyntaxSpec m (Cm a Inlines) bl
commonmarkCitationSpec = mempty
  { syntaxInlineParsers =
      [ citationGroupParser
      , bareCitationParser
      ]
  }

citationGroupParser :: Monad m => InlineParser m (Cm a Inlines)
citationGroupParser = try $ do
  symbol '['
  notFollowedBy $ symbol '^'
  toks <- manyTill anyCitationTok (symbol ']')
  notFollowedByCitationSuffix
  case parseCitationGroup (untokenize toks) of
    Just citations ->
      return $ Cm $ B.singleton $
        Cite citations [Str $ "[" <> untokenize toks <> "]"]
    Nothing -> mzero

bareCitationParser :: Monad m => InlineParser m (Cm a Inlines)
bareCitationParser = try $ do
  suppressAuthor <- option False (True <$ symbol '-')
  ident <- parseCitationId
  let mode = if suppressAuthor then SuppressAuthor else AuthorInText
  return $ Cm $ B.singleton $
    Cite [emptyCitation ident mode]
         [Str $ (if suppressAuthor then "-@" else "@") <> ident]

notFollowedByCitationSuffix :: Monad m => InlineParser m ()
notFollowedByCitationSuffix =
  notFollowedBy $ symbol '(' <|> symbol '[' <|> symbol '{'

anyCitationTok :: Monad m => InlineParser m Tok
anyCitationTok = satisfyTok $ \case
  Tok LineEnd _ _ -> False
  _ -> True

parseCitationId :: Monad m => InlineParser m Text
parseCitationId = do
  symbol '@'
  bracedCitationId <|> simpleCitationId

bracedCitationId :: Monad m => InlineParser m Text
bracedCitationId = try $ do
  symbol '{'
  toks <- many1 $ satisfyTok $ \case
    Tok Spaces _ _ -> False
    Tok LineEnd _ _ -> False
    Tok (Symbol '}') _ _ -> False
    _ -> True
  symbol '}'
  return $ untokenize toks

simpleCitationId :: Monad m => InlineParser m Text
simpleCitationId = do
  first <- satisfyTok isCitationIdStart
  rest <- many $ satisfyTok isCitationIdRest
  return $ untokenize (first:rest)

isCitationIdStart :: Tok -> Bool
isCitationIdStart = \case
  Tok WordChars _ _ -> True
  Tok (Symbol '_') _ _ -> True
  Tok (Symbol '*') _ _ -> True
  _ -> False

isCitationIdRest :: Tok -> Bool
isCitationIdRest = \case
  Tok WordChars _ _ -> True
  Tok (Symbol '_') _ _ -> True
  Tok (Symbol c) _ _ -> c `elem` (":.#$%&-+?<>~/" :: String)
  _ -> False

resolveCommonMarkCitations :: Pandoc -> Pandoc
resolveCommonMarkCitations =
  flip evalState 1 .
  walkM numberCitation .
  walk suppressCitesInContainers .
  walk suppressIntrawordCites

numberCitation :: Inline -> State Int Inline
numberCitation (Cite citations fallback) = do
  noteNum <- get
  put $ noteNum + 1
  return $ Cite (map (\c -> c{ citationNoteNum = noteNum }) citations) fallback
numberCitation x = return x

suppressCitesInContainers :: Inline -> Inline
suppressCitesInContainers (Link attr ils target) =
  Link attr (concatMap citationToFallback ils) target
suppressCitesInContainers (Span attr ils)
  | isSourceposWrapper attr = Span attr ils
  | otherwise = Span attr (concatMap citationToFallback ils)
suppressCitesInContainers x = x

suppressIntrawordCites :: [Inline] -> [Inline]
suppressIntrawordCites = go []
 where
  go acc [] = reverse acc
  go acc (x:xs)
    | startsWithCitation x
    , Just prev <- previousInline acc
    , endsWithAlphaNum prev =
        go (reverse (citationToFallback x) ++ acc) xs
    | otherwise = go (x:acc) xs

  previousInline [] = Nothing
  previousInline (x:_) = Just x

citationToFallback :: Inline -> [Inline]
citationToFallback (Cite _ fallback) = fallback
citationToFallback (Span attr ils) = [Span attr (concatMap citationToFallback ils)]
citationToFallback (Link attr ils target) =
  [Link attr (concatMap citationToFallback ils) target]
citationToFallback x = [x]

startsWithCitation :: Inline -> Bool
startsWithCitation Cite{} = True
startsWithCitation (Span attr [x])
  | isSourceposWrapper attr = startsWithCitation x
startsWithCitation _ = False

lastMeaningful :: [Inline] -> Maybe Inline
lastMeaningful = \case
  [] -> Nothing
  x:xs
    | isSpaceInline x -> lastMeaningful xs
    | otherwise -> Just x

endsWithAlphaNum :: Inline -> Bool
endsWithAlphaNum (Str t) =
  case T.unsnoc t of
    Just (_, c) -> isAlphaNum c
    Nothing -> False
endsWithAlphaNum (Span _ ils) =
  maybe False endsWithAlphaNum $ lastMeaningful $ reverse ils
endsWithAlphaNum _ = False

isSourceposWrapper :: Attr -> Bool
isSourceposWrapper ("", [], kvs) =
  lookup "wrapper" kvs == Just "1" && lookup "data-pos" kvs /= Nothing
isSourceposWrapper _ = False

parseCitationGroup :: Text -> Maybe [Citation]
parseCitationGroup =
  nonEmpty <=< traverse parseCitationItem . filter (not . T.null) .
    map T.strip . T.splitOn ";"
 where
  nonEmpty [] = Nothing
  nonEmpty xs = Just xs

parseCitationItem :: Text -> Maybe Citation
parseCitationItem t =
  either (const Nothing) Just $
    P.runParser citationItemParser defaultParserState "citation" t

citationItemParser :: ParsecT Text ParserState Identity Citation
citationItemParser = do
  prefix <- T.pack <$> manyTill anyChar (lookAhead $ citeKey True)
  (suppressAuthor, ident) <- citeKey True
  suffix <- T.pack <$> many anyChar
  eof
  let mode = if suppressAuthor then SuppressAuthor else NormalCitation
  return (emptyCitation ident mode)
    { citationPrefix = textInlines prefix
    , citationSuffix = textInlines suffix
    }

emptyCitation :: Text -> CitationMode -> Citation
emptyCitation ident mode = Citation
  { citationId = ident
  , citationPrefix = []
  , citationSuffix = []
  , citationMode = mode
  , citationNoteNum = 0
  , citationHash = 0
  }

textInlines :: Text -> [Inline]
textInlines = B.toList . B.text . T.strip

isSpaceInline :: Inline -> Bool
isSpaceInline Space = True
isSpaceInline SoftBreak = True
isSpaceInline LineBreak = True
isSpaceInline (Str t) = T.null t
isSpaceInline _ = False
