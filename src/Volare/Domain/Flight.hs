module Volare.Domain.Flight
    ( getFlights
    , getFlight
    , getFlightRecords
    , addFlight
    , updateFlight
    , deleteFlight
    ) where

import qualified Codec.IGC as IGC
import Control.Monad
    ( filterM
    , when
    )
import Control.Monad.IO.Class (MonadIO)
import Control.Monad.Trans.Reader (ReaderT)
import Control.Monad.Trans.State
    ( evalState
    , get
    , put
    )
import Data.Foldable (forM_)
import Data.List
    ( maximumBy
    , minimumBy
    )
import Data.Ord (comparing)
import qualified Data.Text as T
import Data.Time (UTCTime(UTCTime))
import Database.Persist
    ( (=.)
    , (==.)
    )
import qualified Database.Persist as P

import qualified Volare.Model as M


getFlights :: (MonadIO m, P.PersistQuery backend, backend ~ P.PersistEntityBackend M.Flight) =>
              ReaderT backend m [P.Entity M.Flight]
getFlights = P.selectList [] [P.Desc M.FlightTime]


getFlight :: (MonadIO m, P.PersistQuery backend, backend ~ P.PersistEntityBackend M.Flight) =>
             P.Key M.Flight ->
             ReaderT backend m (Maybe (P.Entity M.Flight))
getFlight flightId = P.selectFirst [M.FlightId ==. flightId] []


getFlightRecords :: (MonadIO m, P.PersistQuery backend, backend ~ P.PersistEntityBackend M.Flight) =>
                    P.Key M.Flight ->
                    ReaderT backend m [P.Entity M.Record]
getFlightRecords flightId = P.selectList [M.RecordFlightId ==. flightId] [P.Asc M.RecordIndex]


addFlight :: (MonadIO m, P.PersistStore backend, backend ~ P.PersistEntityBackend M.Flight) =>
             T.Text ->
             IGC.IGC ->
             ReaderT backend m (P.Key M.Flight)
addFlight name igc = do
    let records = filterRecords $ IGC.records igc
        value selector property = realToFrac $ property $ IGC.position $ selector (comparing (property . IGC.position)) records
    flightId <- P.insert $ M.Flight name
                                    (UTCTime (IGC.date igc) (IGC.time $ head records))
                                    (round (IGC.time (last records) - IGC.time (head records)))
                                    (value minimumBy IGC.latitude)
                                    (value maximumBy IGC.latitude)
                                    (value minimumBy IGC.longitude)
                                    (value maximumBy IGC.longitude)
                                    (value minimumBy IGC.altitude)
                                    (value maximumBy IGC.altitude)
    forM_ (zip records [1..]) $ \(record, index) -> do
        let position = IGC.position record
        P.insert $ M.Record flightId
                            index
                            (UTCTime (IGC.date igc) (IGC.time record))
                            (realToFrac $ IGC.latitude position)
                            (realToFrac $ IGC.longitude position)
                            (realToFrac $ IGC.altitude position)
    return flightId
  where
    filterRecords records =
        case reverse $ dropWhileNotFlying $ reverse $ dropWhileNotFlying records of
            [] -> records
            body -> let start = IGC.time $ head body
                        pre record = IGC.time record < start - 60
                        end = IGC.time $ last body
                        post record = IGC.time record > end + 60
                    in flip evalState Nothing $ filterM valid $ takeWhile (not . post) $ dropWhile pre records
    dropWhileNotFlying records = map fst $ dropWhile (not . uncurry flying) $ zip records (drop 10 records)
    flying record next = let duration = abs $ IGC.time next - IGC.time record
                             dist = IGC.distance (IGC.position next) (IGC.position record)
                             speed = dist / realToFrac duration
                         in speed > 5 && speed < 10
    valid record = do
        previousRecord <- get
        let altitude = IGC.altitude $ IGC.position record
            time = IGC.time record
            v = maybe True (\p -> abs (IGC.altitude (IGC.position p) - altitude) / realToFrac (time - IGC.time p) < 100) previousRecord
        when v $
            put $ Just record
        return v


updateFlight :: (MonadIO m, P.PersistStore backend, backend ~ P.PersistEntityBackend M.Flight) =>
                P.Key M.Flight ->
                Maybe T.Text ->
                ReaderT backend m ()
updateFlight flightId name =
    forM_ name $ \newName ->
        P.update flightId [M.FlightName =. newName]


deleteFlight :: (MonadIO m, P.PersistStore backend, P.DeleteCascade M.Flight backend) =>
                P.Key M.Flight ->
                ReaderT backend m ()
deleteFlight = P.deleteCascade
