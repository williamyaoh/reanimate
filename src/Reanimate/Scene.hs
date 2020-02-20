{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ApplicativeDo #-}
module Reanimate.Scene where

import           Control.Monad.Fix
import           Control.Monad.ST
import           Data.List
import           Data.STRef
import           Reanimate.Animation
import           Reanimate.Effect
import           Reanimate.Svg.Constructors
import           Graphics.SvgTree (Tree(None))

type ZIndex = Int

(#) :: a -> (a -> b) -> b
o # f = f o

-- (seq duration, par duration)
-- [(Time, Animation, ZIndex)]
-- Map Time [(Animation, ZIndex)]
type Gen s = ST s (Duration -> Time -> (SVG, ZIndex))
newtype Scene s a = M { unM :: Time -> ST s (a, Duration, Duration, [Gen s]) }

instance Functor (Scene s) where
  fmap f action = M $ \t -> do
    (a, d1, d2, gens) <- unM action t
    return (f a, d1, d2, gens)

instance Applicative (Scene s) where
  pure a = M $ \_ -> return (a, 0, 0, [])
  f <*> g = M $ \t -> do
    (f', s1, p1, gen1) <- unM f t
    (g', s2, p2, gen2) <- unM g (t+s1)
    return (f' g', s1+s2, max p1 (s1+p2), gen1++gen2)

instance Monad (Scene s) where
  return = pure
  f >>= g = M $ \t -> do
    (a, s1, p1, gen1) <- unM f t
    (b, s2, p2, gen2) <- unM (g a) (t+s1)
    return (b, s1+s2, max p1 (s1+p2), gen1++gen2)

instance MonadFix (Scene s) where
  mfix fn = M $ \t -> mfix (\v -> let (a,_s,_p,_gens) = v in unM (fn a) t)

liftST :: ST s a -> Scene s a
liftST action = M $ \_ -> action >>= \a -> return (a, 0, 0, [])

sceneAnimation :: (forall s. Scene s a) -> Animation
sceneAnimation action =
  runST (do
    (_, s, p, gens) <- unM action 0
    let dur = max s p
    genFns <- sequence gens
    return $ mkAnimation dur (\t ->
      mkGroup $
      map fst $
      sortOn snd
      [ spriteRender dur (t*dur)
      | spriteRender <- genFns ])
  )

fork :: Scene s a -> Scene s a
fork (M action) = M $ \t -> do
  (a, s, p, gens) <- action t
  return (a, 0, max s p, gens)

play :: Animation -> Scene s ()
play ani = newSpriteA ani >>= destroySprite

queryNow :: Scene s Time
queryNow = M $ \t -> return (t, 0, 0, [])

-- Wait until all forked and sequential animations have finished.
waitAll :: Scene s a -> Scene s a
waitAll (M action) = M $ \t -> do
  (a, s, p, gens) <- action t
  return (a, max s p, 0, gens)

waitUntil :: Time -> Scene s ()
waitUntil tNew = do
  now <- queryNow
  wait (max 0 (tNew - now))

wait :: Duration -> Scene s ()
wait d = M $ \_ ->
  return ((), d, 0, [])

adjustZ :: (ZIndex -> ZIndex) -> Scene s a -> Scene s a
adjustZ fn (M action) = M $ \t -> do
    (a, s, p, gens) <- action t
    return (a, s, p, map genFn gens)
  where
    genFn gen = do
      frameGen <- gen
      return $ \d t ->
        let (svg, z) = frameGen d t
        in (svg, fn z)

withSceneDuration :: Scene s () -> Scene s Duration
withSceneDuration s = do
  t1 <- queryNow
  s
  t2 <- queryNow
  return (t2-t1)

fromParams :: Gen s -> Scene s ()
fromParams gen = M $ \_ -> return ((), 0, 0, [gen])

simpleParam :: (a -> SVG) -> a -> Scene s (Var s a)
simpleParam render def = do
  v <- newVar def
  _ <- newSprite $ render <$> unVar v
  return v

newtype Var s a = Var (STRef s (Time -> a))

newVar :: a -> Scene s (Var s a)
newVar def = Var <$> liftST (newSTRef (const def))

readVar :: Var s a -> Scene s a
readVar (Var ref) = liftST (readSTRef ref) <*> queryNow

writeVar :: Var s a -> a -> Scene s ()
writeVar var val = modifyVar var (const val)

modifyVar :: Var s a -> (a -> a) -> Scene s ()
modifyVar (Var ref) fn = do
  now <- queryNow
  liftST $ modifySTRef ref $ \prev t ->
    if t < now
      then prev t
      else fn (prev t)

tweenVar :: Var s a -> Duration -> (a -> Time -> a) -> Scene s ()
tweenVar (Var ref) dur fn = do
  now <- queryNow
  liftST $ modifySTRef ref $ \prev t ->
    fn (prev t) (max 0 (min dur $ t-now)/dur)
  wait dur

unVar :: Var s a -> Frame s a
unVar (Var ref) = Frame $ do
  fn <- readSTRef ref
  return $ \real_t _d _t -> fn real_t

findVar :: (a -> Bool) -> [Var s a] -> Scene s (Var s a)
findVar _cond [] = error "Variable not found."
findVar cond (v:vs) = do
  val <- readVar v
  if cond val then return v else findVar cond vs

applyVar :: Var s a -> Sprite s -> (a -> SVG -> SVG) -> Scene s ()
applyVar var sprite fn =
  spriteModify sprite $ do
    varFn <- unVar var
    return $ \(svg, zindex) ->
      (fn varFn svg, zindex)

data Sprite s = Sprite Time (STRef s (Duration, ST s (Duration -> Time -> SVG -> (SVG, ZIndex))))

newtype Frame s a = Frame { unFrame :: ST s (Time -> Duration -> Time -> a) }

instance Functor (Frame s) where
  fmap fn (Frame gen) = Frame $ do
    m <- gen
    return (\real_t d t -> fn $ m real_t d t)

instance Applicative (Frame s) where
  pure v = Frame $ return (\_ _ _ -> v)
  Frame f <*> Frame g = Frame $ do
    m1 <- f
    m2 <- g
    return $ \real_t d t ->
      m1 real_t d t (m2 real_t d t)

-- Time in seconds.
spriteT :: Frame s Time
spriteT = Frame $ return (\_real_t _d t -> t)

spriteDuration :: Frame s Duration
spriteDuration = Frame $ return (\_real_t d _t -> d)

newSprite :: Frame s SVG -> Scene s (Sprite s)
newSprite render = do
  now <- queryNow
  ref <- liftST $ newSTRef (-1, return $ \_d _t svg -> (svg, 0))
  fromParams $ do
    fn <- unFrame render
    (spriteDur, spriteEffectGen) <- readSTRef ref
    spriteEffect <- spriteEffectGen
    return $ \d absT ->
      let relD = (if spriteDur < 0 then d else spriteDur)-now
          relT = absT-now in
      if relT < 0 || (relD+now/=d && relD <= relT)
        then (None, 0)
        else spriteEffect relD relT (fn absT relD relT)
  return $ Sprite now ref

newSpriteA :: Animation -> Scene s (Sprite s)
newSpriteA = newSpriteA' SyncStretch

newSpriteA' :: Sync -> Animation -> Scene s (Sprite s)
newSpriteA' sync animation =
  newSprite (getAnimationFrame sync animation <$> spriteT <*> spriteDuration)
    <* wait (duration animation)

newSpriteSVG :: SVG -> Scene s (Sprite s)
newSpriteSVG = newSprite . pure

getAnimationFrame :: Sync -> Animation -> Time -> Duration -> SVG
getAnimationFrame sync (Animation aDur aGen) t d =
  case sync of
    SyncStretch -> aGen (t/d)
    SyncLoop    -> aGen (takeFrac $ t/aDur)
    SyncDrop    -> if t > aDur then None else aGen (t/aDur)
    SyncFreeze  -> aGen (min 1 $ t/aDur)
  where
    takeFrac f = snd (properFraction f :: (Int, Double))

data Sync
  = SyncStretch
  | SyncLoop
  | SyncDrop
  | SyncFreeze

destroySprite :: Sprite s -> Scene s ()
destroySprite (Sprite _ ref) = do
  now <- queryNow
  liftST $ modifySTRef ref $ \(ttl, render) ->
    (if ttl < 0 then now else min ttl now, render)

spriteModify :: Sprite s -> Frame s ((SVG,ZIndex) -> (SVG, ZIndex)) -> Scene s ()
spriteModify (Sprite born ref) modFn =
  liftST $ modifySTRef ref $ \(ttl, renderGen) ->
    (ttl, do
      render <- renderGen
      modRender <- unFrame modFn
      return $ \relD relT ->
        let absT = relT + born
        in modRender absT relD relT . render relD relT)

spriteMap :: Sprite s -> (SVG -> SVG) -> Scene s ()
spriteMap sprite fn = spriteModify sprite $ pure $ \(svg, zindex) -> (fn svg, zindex)

spriteTween :: Sprite s -> Duration -> (Double -> SVG -> SVG) -> Scene s ()
spriteTween sprite@(Sprite born _) dur fn = do
    now <- queryNow
    let tDelta = now - born
    spriteModify sprite $ do
      t <- spriteT
      return $ \(svg, zindex) ->
        (fn (clamp 0 1 $ (t-tDelta)/dur) svg, zindex)
    wait dur
  where
    clamp a b v
      | v < a     = a
      | v > b     = b
      | otherwise = v

spriteVar :: Sprite s -> a -> (a -> SVG -> SVG) -> Scene s (Var s a)
spriteVar sprite def fn = do
  v <- newVar def
  spriteModify sprite $ do
    getV <- unVar v
    return $ \(svg, zindex) ->
      (fn getV svg, zindex)
  return v

spriteE :: Sprite s -> Effect -> Scene s ()
spriteE (Sprite born ref) effect = do
  now <- queryNow
  liftST $ modifySTRef ref $ \(ttl, renderGen) ->
    (ttl, do
      render <- renderGen
      return $ \d t svg ->
        let (svg', z) = render d t svg
        in (delayE (max 0 $ now-born) effect d t svg', z))

spriteZ :: Sprite s -> ZIndex -> Scene s ()
spriteZ (Sprite born ref) zindex = do
  now <- queryNow
  liftST $ modifySTRef ref $ \(ttl, renderGen) ->
    (ttl, do
      render <- renderGen
      return $ \d t svg ->
        let (svg', z) = render d t svg
        in (svg', if t < now-born then z else zindex))

{-
data Var s a = Var (STRef s (Time -> a))
data Sprite s = Sprite (STRef s (Duration, Duration -> Time -> (SVG, ZIndex)))

newVar :: a -> Scene s (Var s a)
readVar :: Var s a -> Scene s a
writeVar :: Var s a -> a -> Scene s ()
modifyVar :: Var s a -> (a -> a) -> Scene s ()
freezeVar :: Var s a -> ST s (Time -> a)

newSprite :: ST s (Time -> Time -> SVG) -> Scene s (Sprite s)
destroySprite :: Sprite s -> Scene s ()
spriteE :: Sprite s -> Effect -> Scene s ()

newBlock :: Var s Position -> Number -> Scene s (Sprite s)
-}


-- FIXME: Move this somewhere more appropriate
transition :: Effect -- ^ Effect to be applied at the beginning of the second animation
           -> Effect -- ^ Effect to be applied at the end of first animation
           -> Double -- ^ Duration of the transition
           -> Animation -- ^ First animation
           -> Animation -- ^ Second animation
           -> Animation -- ^ Animation consisting of first animation, followed by second animation with transition based on given effects in between
transition tIn tOut tT a b = sceneAnimation $ do
  fork $ play $ a
    # applyE (overEnding tT tOut)
  wait (duration a - tT)
  play $ b
    # applyE (overBeginning tT tIn)

transitions :: Effect -> Effect -> Double -> [Animation] -> Animation
transitions _ _ _ [] = pause 0
transitions tIn tOut tT (x:xs) =
  foldl (transition tIn tOut tT) x xs
