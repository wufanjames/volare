module Volare.Handler.AMEDAS (
    getDataR
) where

import Control.Applicative ((<$>))
import Control.Monad.IO.Class (liftIO)
import Data.Aeson ((.=))
import qualified Data.Aeson as JSON
import qualified Data.Text as T
import Data.Time (UTCTime(..),
                  fromGregorian,
                  hoursToTimeZone,
                  localDay,
                  localTimeOfDay,
                  todHour,
                  toGregorian,
                  utcToLocalTime)
import qualified Service.AMEDAS as AMEDAS
import System.Directory (createDirectoryIfMissing,
                         doesFileExist)
import System.FilePath (takeDirectory)
import Text.Printf (printf)
import Text.Read (readMaybe)
import Yesod.Core.Handler (lookupGetParam,
                           notFound)

import Volare.Foundation


getDataR :: Int ->
            Int ->
            Int ->
            Int ->
            Handler JSON.Value
getDataR year month day hour = do
  nwLatitude <- (>>= readMaybe . T.unpack) <$> lookupGetParam "nwlat"
  nwLongitude <- (>>= readMaybe . T.unpack) <$> lookupGetParam "nwlng"
  seLatitude <- (>>= readMaybe . T.unpack) <$> lookupGetParam "selat"
  seLongitude <- (>>= readMaybe . T.unpack) <$> lookupGetParam "selng"
  case (nwLatitude, nwLongitude, seLatitude, seLongitude) of
    (Just nwLat, Just nwLng, Just seLat, Just seLng) -> do
      let utcTime = UTCTime (fromGregorian (fromIntegral year) month day) (fromIntegral $ hour * 60 * 60)
          jst = hoursToTimeZone 9
          jstTime = utcToLocalTime jst utcTime
          (y, m, d) = toGregorian $ localDay jstTime
          h = todHour $ localTimeOfDay jstTime
          f (Item _ _ item) = let t = AMEDAS.time item
                              in h * 60 <= t && t < (h + 1) * 60
          load station = filter f <$> loadItems station (fromIntegral y) m d
      liftIO $ JSON.toJSON . concat <$> mapM load (AMEDAS.stations (nwLat, nwLng) (seLat, seLng))
    _ -> notFound


loadItems :: AMEDAS.Station ->
             Int ->
             Int ->
             Int ->
             IO [Item]
loadItems station year month day = do
  let path = printf "./data/amedas/%d/%04d/%04d%02d%02d.csv" (AMEDAS.prec station) (AMEDAS.block station) year month day
  b <- doesFileExist path
  items <- if b then
               AMEDAS.load path
           else do
             createDirectoryIfMissing True $ takeDirectory path
             items <- AMEDAS.download station year month day
             -- TODO
             -- Save to a temporary file and move it
             AMEDAS.save path items
             return items
  return $ map (Item (AMEDAS.latitude station) (AMEDAS.longitude station)) items


data Item = Item Float Float AMEDAS.Item

instance JSON.ToJSON Item where
    toJSON (Item latitude longitude item) =
        let hour = (AMEDAS.time item `div` 60 + (24 - 9)) `mod` 24
            minute = AMEDAS.time item `mod` 60
        in JSON.object [
               "time"          .= (hour * 60 + minute),
               "latitude"      .= latitude,
               "longitude"     .= longitude,
               "precipitation" .= AMEDAS.precipitation item,
               "temperature"   .= AMEDAS.temperature item,
               "windSpeed"     .= AMEDAS.windSpeed item,
               "windDirection" .= AMEDAS.windDirection item,
               "sunshine"      .= AMEDAS.sunshine item
           ]