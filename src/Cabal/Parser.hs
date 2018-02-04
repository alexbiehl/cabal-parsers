module Cabal.Parser
    ( compatParseGenericPackageDescription
    , ParseResult(..)
    , GenericPackageDescription
    ) where

import           Control.Monad

import           Data.ByteString                       (ByteString)
import qualified Data.Text                             as T
import qualified Data.Text.Encoding                    as T
import qualified Data.Text.Encoding.Error              as T

import           Distribution.InstalledPackageInfo     (PError (..))
import           Distribution.PackageDescription       (GenericPackageDescription (..),
                                                        specVersion)
import           Distribution.PackageDescription.Parse (parseGenericPackageDescription)
import           Distribution.ParseUtils               (ParseResult (..))
import           Distribution.Version                  (mkVersion)

import qualified Cabal.Parser.V200                     as V200

unpackUTF8 :: ByteString -> String
unpackUTF8 raw = case T.unpack t of
                '\65279':cs -> cs
                cs          -> cs
  where
    t = T.decodeUtf8With T.lenientDecode raw

-- | Augmented version of 'parseGenericPackageDescription' which additional compatibility checks
compatParseGenericPackageDescription :: ByteString -> ParseResult GenericPackageDescription
compatParseGenericPackageDescription bs = case parseGenericPackageDescription (unpackUTF8 bs) of
                                            pe@(ParseFailed {})  -> pe
                                            pok@(ParseOk _pwarns gpd) ->
                                              case go (specVersion (packageDescription gpd)) of
                                                Nothing   -> pok
                                                Just perr -> ParseFailed perr
 where
   go v = msum $ [ goV200 | v < mkVersion [2,1]  ]
              ++ [ goV124 | v < mkVersion [1,25] ]
              ++ [ goV122 | v < mkVersion [1,23] ]

   goV200 :: Maybe PError
   goV200 = case V200.parseGenericPackageDescription (unpackUTF8 bs) of
              V200.ParseFailed perr -> Just $! convertPerr perr
              V200.ParseOk _ _      -> Nothing
     where
       convertPerr :: V200.PError -> PError
       convertPerr (V200.AmbiguousParse s lno) = AmbiguousParse ("[v2.0] " ++ s) lno
       convertPerr (V200.FromString s mlno)    = FromString     ("[v2.0] " ++ s) mlno
       convertPerr (V200.NoParse s lno)        = NoParse        ("[v2.0] " ++ s) lno
       convertPerr (V200.TabsError lno)        = TabsError                       lno

   goV124 :: Maybe PError
   goV124 = Nothing -- TODO

   goV122 :: Maybe PError
   goV122 = Nothing -- TODO
