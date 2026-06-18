{-# LANGUAGE OverloadedStrings #-}
module Tests.Writers.ODF (tests) where

import Codec.Archive.Zip
import qualified Data.ByteString.Lazy.Char8 as BL8
import Data.List (isInfixOf)
import qualified Data.Text as T
import Test.Tasty
import Test.Tasty.HUnit
import Tests.Helpers
import Text.Pandoc
import Text.Pandoc.Builder
import Text.Pandoc.Writers.Shared (defField)

tests :: [TestTree]
tests =
  [ testCase "inline math uses text mode" $ do
      arch <- odfArchive $ para (math "x^2")
      settings arch @?~ "config:name=\"IsTextMode\" config:type=\"boolean\">true"
      settings arch @?!~ "BaseFontHeight"
      content arch @?~ "display=\"inline\""
  , testCase "display math does not use text mode" $ do
      arch <- odfArchive $ para (displayMath "x^2")
      settings arch @?~ "config:name=\"IsTextMode\" config:type=\"boolean\">false"
      content arch @?~ "display=\"block\""
  , testCase "base font height is optional" $ do
      arch <- odfArchiveWith
        def{ writerVariables =
               defField "formula-base-font-height" ("18pt" :: T.Text) mempty }
        (para (displayMath "x^2"))
      settings arch @?~ "config:name=\"BaseFontHeight\" config:type=\"short\">18"
  , testCase "uses first math element" $ do
      arch <- odfArchive $ para (math "x") <> para (math "y")
      content arch @?~ "<mi>x</mi>"
      content arch @?!~ "<mi>y</mi>"
  , testCase "no math is an error" $ do
      result <- runIO $ writeODF def $ toPandoc $ para "no math"
      case result of
        Left (PandocSomeError msg) ->
          msg @?= "Cannot write ODF formula: document contains no math."
        Left e -> assertFailure $ "Unexpected error: " <> show e
        Right _ -> assertFailure "Expected ODF formula writer to fail"
  , testCase "invalid base font height is an error" $ do
      result <- runIO $
        writeODF
          def{ writerVariables =
                 defField "formula-base-font-height" ("large" :: T.Text) mempty }
          (toPandoc $ para (math "x"))
      case result of
        Left (PandocSomeError msg) ->
          msg @?= "Invalid formula-base-font-height large. Expected an integer point size, optionally followed by 'pt'."
        Left e -> assertFailure $ "Unexpected error: " <> show e
        Right _ -> assertFailure "Expected invalid formula-base-font-height to fail"
  ]

odfArchive :: ToPandoc a => a -> IO Archive
odfArchive = odfArchiveWith def

odfArchiveWith :: ToPandoc a => WriterOptions -> a -> IO Archive
odfArchiveWith opts =
  fmap toArchive . runIOorExplode . writeODF opts . toPandoc

settings :: Archive -> String
settings = entry "settings.xml"

content :: Archive -> String
content = entry "content.xml"

entry :: FilePath -> Archive -> String
entry fp arch =
  case findEntryByPath fp arch of
    Nothing -> error $ "Missing " <> fp
    Just e  -> BL8.unpack $ fromEntry e

(@?~) :: String -> String -> Assertion
haystack @?~ needle =
  assertBool ("Expected to find " <> show needle <> " in " <> show haystack)
    (needle `isInfixOf` haystack)

(@?!~) :: String -> String -> Assertion
haystack @?!~ needle =
  assertBool ("Expected not to find " <> show needle <> " in " <> show haystack)
    (not $ needle `isInfixOf` haystack)
