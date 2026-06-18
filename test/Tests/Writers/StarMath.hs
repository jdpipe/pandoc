{-# LANGUAGE OverloadedStrings #-}
module Tests.Writers.StarMath (tests) where

import qualified Data.Text as T
import Test.Tasty
import Test.Tasty.HUnit
import Tests.Helpers
import Text.Pandoc
import Text.Pandoc.Builder

tests :: [TestTree]
tests =
  [ testCase "inline math uses inline StarMath rendering" $
      starmath (para $ math "\\frac{a}{b}") @?= "size*0.7 {a over b}"
  , testCase "display math uses display StarMath rendering" $
      starmath (para $ displayMath "\\frac{a}{b}") @?= "{a over b}"
  , testCase "uses first math element" $
      starmath (para (math "x") <> para (math "y")) @?= "x"
  , testCase "no math is an error" $ do
      result <- runIO $ writeStarMath def $ toPandoc $ para "no math"
      case result of
        Left (PandocSomeError msg) ->
          msg @?= "Cannot write StarMath: document contains no math."
        Left e -> assertFailure $ "Unexpected error: " <> show e
        Right _ -> assertFailure "Expected StarMath writer to fail"
  ]

starmath :: ToPandoc a => a -> String
starmath = T.unpack . purely (writeStarMath def) . toPandoc
