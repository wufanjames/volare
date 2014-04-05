module Volare.Handler.Root (
    getRootR
) where

import Text.Blaze.Html (Html)
import Yesod.Core (defaultLayout)
import Yesod.Core.Widget (setTitle)

import Volare.Foundation
import Volare.Handler.Utils (addCommonLibraries)
import Volare.Settings (widgetFile)


getRootR :: Handler Html
getRootR =
    defaultLayout $ do
        setTitle "Volare"
        addCommonLibraries
        $(widgetFile "root")