{-# LANGUAGE OverloadedStrings #-}
{- |
   Module      : Text.Pandoc.Writers.StarMath
   Copyright   : Copyright (C) 2026 John MacFarlane
   License     : GNU GPL, version 2 or above

   Maintainer  : John MacFarlane <jgm@berkeley.edu>
   Stability   : alpha
   Portability : portable

Conversion of a Pandoc math element to StarMath.
-}
module Text.Pandoc.Writers.StarMath
  ( writeStarMath
  ) where

import Control.Monad.Except (throwError)
import qualified Data.Text as T
import Text.Pandoc.Class.PandocMonad (PandocMonad, report)
import Text.Pandoc.Definition
import Text.Pandoc.Error (PandocError(PandocSomeError))
import Text.Pandoc.Logging
import Text.Pandoc.Options (WriterOptions)
import Text.Pandoc.Writers.ODF (firstMath)
import Text.TeXMath (DisplayType(..), readTeX)
import qualified Text.TeXMath as TM

-- | Produce StarMath from the first math element in a Pandoc document.
writeStarMath :: PandocMonad m
              => WriterOptions
              -> Pandoc
              -> m T.Text
writeStarMath _ doc =
  case firstMath doc of
    Nothing -> throwError $
      PandocSomeError "Cannot write StarMath: document contains no math."
    Just (mathType, math) ->
      case readTeX math of
        Left e -> do
          report $ CouldNotConvertTeXMath math e
          throwError $
            PandocSomeError "Cannot write StarMath: could not convert TeX math."
        Right exps -> return $ TM.writeStarMath (displayType mathType) exps

displayType :: MathType -> DisplayType
displayType InlineMath  = DisplayInline
displayType DisplayMath = DisplayBlock
