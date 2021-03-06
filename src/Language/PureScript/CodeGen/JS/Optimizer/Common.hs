-- |
-- Common functions used by the various optimizer phases
--
module Language.PureScript.CodeGen.JS.Optimizer.Common where

import Prelude.Compat

import Data.Text (Text)
import Data.List (foldl')
import Data.Maybe (fromMaybe)

import Language.PureScript.Crash
import Language.PureScript.CodeGen.JS.AST
import Language.PureScript.PSString (mkString)

applyAll :: [a -> a] -> a -> a
applyAll = foldl' (.) id

replaceIdent :: Text -> JS -> JS -> JS
replaceIdent var1 js = everywhereOnJS replace
  where
  replace (JSVar _ var2) | var1 == var2 = js
  replace other = other

replaceIdents :: [(Text, JS)] -> JS -> JS
replaceIdents vars = everywhereOnJS replace
  where
  replace v@(JSVar _ var) = fromMaybe v $ lookup var vars
  replace other = other

isReassigned :: Text -> JS -> Bool
isReassigned var1 = everythingOnJS (||) check
  where
  check :: JS -> Bool
  check (JSFunction _ _ args _) | var1 `elem` args = True
  check (JSVariableIntroduction _ arg _) | var1 == arg = True
  check (JSAssignment _ (JSVar _ arg) _) | var1 == arg = True
  check (JSFor _ arg _ _ _) | var1 == arg = True
  check (JSForIn _ arg _ _) | var1 == arg = True
  check _ = False

isRebound :: JS -> JS -> Bool
isRebound js d = any (\v -> isReassigned v d || isUpdated v d) (everythingOnJS (++) variablesOf js)
  where
  variablesOf (JSVar _ var) = [var]
  variablesOf _ = []

isUsed :: Text -> JS -> Bool
isUsed var1 = everythingOnJS (||) check
  where
  check :: JS -> Bool
  check (JSVar _ var2) | var1 == var2 = True
  check (JSAssignment _ target _) | var1 == targetVariable target = True
  check _ = False

targetVariable :: JS -> Text
targetVariable (JSVar _ var) = var
targetVariable (JSAccessor _ _ tgt) = targetVariable tgt
targetVariable (JSIndexer _ _ tgt) = targetVariable tgt
targetVariable _ = internalError "Invalid argument to targetVariable"

isUpdated :: Text -> JS -> Bool
isUpdated var1 = everythingOnJS (||) check
  where
  check :: JS -> Bool
  check (JSAssignment _ target _) | var1 == targetVariable target = True
  check _ = False

removeFromBlock :: ([JS] -> [JS]) -> JS -> JS
removeFromBlock go (JSBlock ss sts) = JSBlock ss (go sts)
removeFromBlock _  js = js

isFn :: (Text, Text) -> JS -> Bool
isFn (moduleName, fnName) (JSAccessor _ x (JSVar _ y)) =
  x == fnName && y == moduleName
isFn (moduleName, fnName) (JSIndexer _ (JSStringLiteral _ x) (JSVar _ y)) =
  x == mkString fnName && y == moduleName
isFn _ _ = False

isDict :: (Text, Text) -> JS -> Bool
isDict (moduleName, dictName) (JSAccessor _ x (JSVar _ y)) = x == dictName && y == moduleName
isDict _ _ = False

isDict' :: [(Text, Text)] -> JS -> Bool
isDict' xs js = any (`isDict` js) xs
