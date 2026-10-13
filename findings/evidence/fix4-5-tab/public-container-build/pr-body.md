The Favorites tab loses its `heart` accessibility identifier while unselected. Replace the failed SwiftUI-owned tab hook with a public `UITabBarController` and three stable `UITab` objects, setting Favorites accessibility identity before assigning the tabs.

Retain the existing SwiftUI navigation stacks, labels, symbols, service environment, deep links and persistence hooks. Hosting controllers remain stable across updates, and UIKit selection and Navigator selection synchronize in both directions.

Validation: clean Landmarks (UI Testing) / UITesting generic simulator build passed; source diff check passed. Controller-owned iOS 26 and 27 cold/selected/unselected, selector, relaunch, navigation/state and stock/negative control checks remain required. Compile success does not prove accessibility projection. No runtime checks claimed.
