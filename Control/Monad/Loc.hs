{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE CPP #-}
{-|
 * Stack traces are only provided for explicitly annotated program points.
   For now there is the TH macro 'withLocTH' to help with this.
   Eventually a preprocessor could be written to automatically insert calls
   to 'withLoc' at every do statement.
-}
module Control.Monad.Loc where
import Language.Haskell.TH.Syntax (qLocation, Loc(..), Q, Exp)
import Text.PrettyPrint
#if TRANSFORMERS
import Control.Monad.Trans
import Control.Monad.Trans.Error
import Control.Monad.Trans.List
import Control.Monad.Trans.Reader
import Control.Monad.Trans.State
import Control.Monad.Trans.Writer
import Control.Monad.Trans.RWS
#else
import Control.Monad.Error
import Control.Monad.List
import Control.Monad.Reader
import Control.Monad.State
import Control.Monad.Writer
import Control.Monad.RWS
#endif

-- | Generating stack traces for failures
class Monad m => MonadLoc m where
  -- | 'withLoc' records the given source location in the failure trace
  --   if the underlying monad supports recording stack traces
  --
  --   By default 'withLoc' is defined as the identity on its second argument
  withLoc :: String -> m a -> m a
  getLoc :: m [String]

-- instance MonadLoc a where withLoc _ = id


{-| Given a list of source locations and a Showable error, @showFailWithStackTrace@ produces output of the form

>       <exception details>
>        in <module a>(<file a.hs>): (12,6)
>           <module b>(<file b.hs>): (11,7)
>           ...

-}
showFailWithStackTrace :: Show e => [String] -> e -> String
showFailWithStackTrace trace e = render$
             text (show e) $$
             text " in" <+> (vcat (map text $ reverse trace))

-- | 'withLocTH' is a convenient TH macro which expands to 'withLoc' @\<source location\>@
--   Usage:
--
--  > f x = $withLocTH $ do
withLocTH :: Q Exp
withLocTH = do
  loc <- qLocation
  let loc_msg = showLoc loc
  [| withLoc loc_msg |]
 where
   showLoc Loc{loc_module=mod, loc_filename=filename, loc_start=start} = render $
                     {- text package <> char '.' <> -}
                     text mod <> parens (text filename) <> colon <+> text (show start)


-- ----------
-- Instances
-- ----------

instance (Error e, MonadLoc m) => MonadLoc (ErrorT e m) where
  withLoc l (ErrorT m) = ErrorT (withLoc l m)
  getLoc  = lift getLoc

instance MonadLoc m => MonadLoc (ListT m) where
  withLoc l (ListT m) = ListT (withLoc l m)
  getLoc  = lift getLoc

instance MonadLoc m => MonadLoc (ReaderT r m) where
  withLoc l (ReaderT m) = ReaderT $ \env -> (withLoc l (m env))
  getLoc  = lift getLoc

instance (Monoid w, MonadLoc m) => MonadLoc (WriterT w  m) where
  withLoc l (WriterT m) = WriterT (withLoc l m)
  getLoc  = lift getLoc

instance MonadLoc m => MonadLoc (StateT s m) where
  withLoc l (StateT m) = StateT $ \s -> (withLoc l (m s))
  getLoc  = lift getLoc

instance (Monoid w, MonadLoc m) => MonadLoc (RWST r w s m) where
  withLoc l (RWST m) = RWST $ \env s -> (withLoc l (m env s))
  getLoc  = lift getLoc