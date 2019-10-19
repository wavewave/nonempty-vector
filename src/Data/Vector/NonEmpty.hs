{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE Trustworthy #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE NoImplicitPrelude #-}
-- |
-- Module       : Data.Vector.NonEmpty
-- Copyright 	: 2019 Emily Pillmore
-- License	: BSD
--
-- Maintainer	: Emily Pillmore <emilypi@cohomolo.gy>
-- Stability	: Experimental
-- Portability	: TypeFamilies, MPTC, Rank2Types, DataTypeable, CPP
--
-- A library for non-empty boxed vectors (that is, polymorphic arrays capable of
-- holding any Haskell value). Non-empty vectors come in two flavors:
--
--  * mutable
--
--  * immutable
--
-- and support a rich interface of both list-like operations, and bulk
-- array operations.
--
-- For unboxed non-empty arrays, use "Data.Vector.NonEmpty.Unboxed"
--
-- Credit to Roman Leshchinskiy for the original Vector library
-- upon which this is based.
--
module Data.Vector.NonEmpty
( -- * Boxed non-empty vectors
  NonEmptyVector

  -- * Accessors

  -- ** Length information
, length

  -- ** Indexing
, head, last, (!), (!?)
, unsafeIndex

  -- ** Monadic Indexing
, headM, lastM, indexM, unsafeIndexM

  -- ** Extracting subvectors (slicing)
, tail, slice, init, take, drop, splitAt
, unsafeSlice, unsafeTake, unsafeDrop

  -- * Construction

  -- ** Initialization
, singleton, replicate, generate
, iterateN

  -- ** Monad Initialization
, replicateM, generateM, iterateNM

  -- ** Unfolding
, unfoldr, unfoldrN, unfoldrM, unfoldrNM
, constructN, constructrN

  -- ** Enumeration
, enumFromN, enumFromStepN
, enumFromTo, enumFromThenTo

  -- ** Concatenation
, cons, snoc, (++), concat, concat1

  -- ** Restricting memory usage
, force

  -- * Conversion

  -- ** To/from non-empty lists
, fromNonEmpty, toNonEmpty

  -- ** To/from vector
, toVector, fromVector

  -- ** From list
, fromList

  -- * Modifying NonEmptyVectors

  -- ** Bulk Updates
, (//), update, update_
, unsafeUpd, unsafeUpdate, unsafeUpdate_
) where


import Prelude (Eq, Ord, Read, Show, Num, Enum, (.))


import Control.Applicative
import Control.DeepSeq hiding (force)
import Control.Monad (Monad)
import Control.Monad.Fail
import Control.Monad.Zip (MonadZip)

import Data.Data (Data)
import Data.Foldable hiding (length, concat)
import Data.Functor
import Data.Int
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Maybe
import Data.Semigroup (Semigroup(..), (<>))
import Data.Traversable as Traversable
import Data.Typeable (Typeable)
import Data.Vector (Vector)
import qualified Data.Vector as V

import GHC.Generics


newtype NonEmptyVector a = NonEmptyVector
    { _neVec :: V.Vector a
    } deriving
      ( Eq, Ord, Show, Read
      , Data, Typeable, Generic, NFData
      , Functor, Applicative, Monad
      , MonadFail, MonadZip, Alternative
      , Semigroup
      )

-- ---------------------------------------------------------------------- --
-- Instances

instance Foldable NonEmptyVector where
    foldMap f = foldMap f . _neVec

instance Traversable NonEmptyVector where
    traverse f = fmap NonEmptyVector . traverse f . _neVec

-- ---------------------------------------------------------------------- --
-- Accessors + Indexing

length :: NonEmptyVector a -> Int
length = V.length . _neVec
{-# INLINE length #-}

-- | /O(1)/ First element.
--
head :: NonEmptyVector a -> a
head = V.unsafeHead . _neVec
{-# INLINE head #-}

-- | /O(1)/ Last element.
--
last :: NonEmptyVector a -> a
last = V.unsafeLast . _neVec
{-# INLINE last #-}

(!) :: NonEmptyVector a -> Int -> a
(!) (NonEmptyVector as) n = as V.! n
{-# INLINE (!) #-}

(!?) :: NonEmptyVector a -> Int -> Maybe a
(NonEmptyVector as) !? n = as V.!? n
{-# INLINE (!?) #-}

unsafeIndex :: NonEmptyVector a -> Int -> a
unsafeIndex (NonEmptyVector as) n = V.unsafeIndex as n
{-# INLINE unsafeIndex #-}

-- ---------------------------------------------------------------------- --
-- Monadic Indexing

indexM :: Monad m => NonEmptyVector a -> Int -> m a
indexM (NonEmptyVector v) n = V.indexM v n
{-# INLINE indexM #-}

headM :: Monad m => NonEmptyVector a -> m a
headM (NonEmptyVector v) = V.unsafeHeadM v
{-# INLINE headM #-}

lastM :: Monad m => NonEmptyVector a -> m a
lastM (NonEmptyVector v) = V.unsafeLastM v
{-# INLINE lastM #-}

unsafeIndexM :: Monad m => NonEmptyVector a -> Int -> m a
unsafeIndexM (NonEmptyVector v) n = V.unsafeIndexM v n
{-# INLINE unsafeIndexM #-}

-- ---------------------------------------------------------------------- --
-- Extracting subvectors (slicing)

tail :: NonEmptyVector a -> Vector a
tail = V.unsafeTail . _neVec
{-# INLINE tail #-}

slice :: Int -> Int -> NonEmptyVector a -> Vector a
slice i n = V.slice i n . _neVec

init :: NonEmptyVector a -> Vector a
init = V.unsafeInit . _neVec

take :: Int -> NonEmptyVector a -> Vector a
take n = V.take n . _neVec

drop :: Int ->  NonEmptyVector a -> Vector a
drop n = V.drop n . _neVec

splitAt :: Int -> NonEmptyVector a -> (Vector a, Vector a)
splitAt n = V.splitAt n . _neVec

unsafeSlice :: Int -> Int -> NonEmptyVector a -> Vector a
unsafeSlice i n = V.unsafeSlice i n . _neVec

unsafeTake :: Int -> NonEmptyVector a -> Vector a
unsafeTake n = V.unsafeTake n . _neVec

unsafeDrop :: Int -> NonEmptyVector a -> Vector a
unsafeDrop n = V.unsafeDrop n . _neVec

-- ---------------------------------------------------------------------- --
-- Construction

singleton :: a -> NonEmptyVector a
singleton = NonEmptyVector . V.singleton
{-# INLINE singleton #-}

replicate :: Int -> a -> Maybe (NonEmptyVector a)
replicate n a = fromVector (V.replicate n a)
{-# INLINE replicate #-}

generate :: Int -> (Int -> a) -> Maybe (NonEmptyVector a)
generate n f = fromVector (V.generate n f)
{-# INLINE generate #-}

iterateN :: Int -> (a -> a) -> a -> Maybe (NonEmptyVector a)
iterateN n f a = fromVector (V.iterateN n f a)
{-# INLINE iterateN #-}

-- ---------------------------------------------------------------------- --
-- Monadic Initialization

replicateM :: Monad m => Int -> m a -> m (Maybe (NonEmptyVector a))
replicateM n a = fmap fromVector (V.replicateM n a)
{-# INLINE replicateM #-}

generateM :: Monad m => Int -> (Int -> m a) -> m (Maybe (NonEmptyVector a))
generateM n f = fmap fromVector (V.generateM n f)
{-# INLINE generateM #-}

iterateNM :: Monad m => Int -> (a -> m a) -> a -> m (Maybe (NonEmptyVector a))
iterateNM n f a = fmap fromVector (V.iterateNM n f a)
{-# INLINE iterateNM #-}

-- ---------------------------------------------------------------------- --
-- Unfolding

unfoldr :: (b -> Maybe (a, b)) -> b -> Maybe (NonEmptyVector a)
unfoldr f b = fromVector (V.unfoldr f b)

unfoldrN :: Int -> (b -> Maybe (a, b)) -> b -> Maybe (NonEmptyVector a)
unfoldrN n f b = fromVector (V.unfoldrN n f b)

unfoldrM :: Monad m => (b -> m (Maybe (a, b))) -> b -> m (Maybe (NonEmptyVector a))
unfoldrM f b = fmap fromVector (V.unfoldrM f b)

unfoldrNM :: Monad m => Int -> (b -> m (Maybe (a, b))) -> b -> m (Maybe (NonEmptyVector a))
unfoldrNM n f b = fmap fromVector (V.unfoldrNM n f b)

constructN :: Int -> (Vector a -> a) -> Maybe (NonEmptyVector a)
constructN n f = fromVector (V.constructN n f)

constructrN :: Int -> (Vector a -> a) -> Maybe (NonEmptyVector a)
constructrN n f = fromVector (V.constructrN n f)

-- ---------------------------------------------------------------------- --
-- Enumeration

enumFromN :: Num a => a -> Int -> Maybe (NonEmptyVector a)
enumFromN a n = fromVector (V.enumFromN a n)

enumFromStepN :: Num a => a -> a -> Int -> Maybe (NonEmptyVector a)
enumFromStepN a0 a1 n = fromVector (V.enumFromStepN a0 a1 n)

enumFromTo :: Enum a => a -> a -> Maybe (NonEmptyVector a)
enumFromTo a0 a1 = fromVector (V.enumFromTo a0 a1)

enumFromThenTo :: Enum a => a -> a -> a -> Maybe (NonEmptyVector a)
enumFromThenTo a0 a1 a2 = fromVector (V.enumFromThenTo a0 a1 a2)

-- ---------------------------------------------------------------------- --
-- Concatenation

cons :: a -> NonEmptyVector a -> NonEmptyVector a
cons a (NonEmptyVector as) = NonEmptyVector (V.cons a as)
{-# INLINE cons #-}

snoc :: NonEmptyVector a -> a -> NonEmptyVector a
snoc (NonEmptyVector as) a = NonEmptyVector (V.snoc as a)
{-# INLINE snoc #-}

(++) :: NonEmptyVector a -> NonEmptyVector a -> NonEmptyVector a
NonEmptyVector v ++ NonEmptyVector v' = NonEmptyVector (v <> v')
{-# INLINE (++) #-}

concat :: [NonEmptyVector a] -> Maybe (NonEmptyVector a)
concat [] = Nothing
concat (a:as) = Just (concat1 (a :| as))

concat1 :: NonEmpty (NonEmptyVector a) -> NonEmptyVector a
concat1 = NonEmptyVector . foldl' (\v (NonEmptyVector a) -> v <> a) V.empty

-- ---------------------------------------------------------------------- --
-- Conversion

fromNonEmpty :: NonEmpty a -> NonEmptyVector a
fromNonEmpty = NonEmptyVector . V.fromList . toList
{-# INLINE fromNonEmpty #-}

toNonEmpty :: NonEmptyVector a -> NonEmpty a
toNonEmpty = NonEmpty.fromList . toList . _neVec
{-# INLINE toNonEmpty #-}

toVector :: NonEmptyVector a -> V.Vector a
toVector = _neVec
{-# INLINE toVector #-}

fromVector :: V.Vector a -> Maybe (NonEmptyVector a)
fromVector v = if V.null v then Nothing else Just (NonEmptyVector v)
{-# INLINE fromVector #-}

fromList :: [a] -> Maybe (NonEmptyVector a)
fromList = fromVector . V.fromList
{-# INLINE fromList #-}

-- ---------------------------------------------------------------------- --
-- Restricting memory usage

force :: NonEmptyVector a -> NonEmptyVector a
force (NonEmptyVector a) = NonEmptyVector (V.force a)

-- ---------------------------------------------------------------------- --
-- Restricting memory usage

(//) :: NonEmptyVector a -> [(Int, a)] -> NonEmptyVector a
NonEmptyVector v // us = NonEmptyVector (v V.// us)

update :: NonEmptyVector a -> Vector (Int, a) -> NonEmptyVector a
update (NonEmptyVector v) v' = NonEmptyVector (V.update v v')

update_ :: NonEmptyVector a -> Vector Int -> Vector a -> NonEmptyVector a
update_ (NonEmptyVector v) is as = NonEmptyVector (V.update_ v is as)

unsafeUpd :: NonEmptyVector a -> [(Int, a)] -> NonEmptyVector a
unsafeUpd (NonEmptyVector v) us = NonEmptyVector (V.unsafeUpd v us)

unsafeUpdate :: NonEmptyVector a -> Vector (Int, a) -> NonEmptyVector a
unsafeUpdate (NonEmptyVector v) us = NonEmptyVector (V.unsafeUpdate v us)

unsafeUpdate_ :: NonEmptyVector a -> Vector Int -> Vector a -> NonEmptyVector a
unsafeUpdate_ (NonEmptyVector v) is as = NonEmptyVector (V.unsafeUpdate_ v is as)
