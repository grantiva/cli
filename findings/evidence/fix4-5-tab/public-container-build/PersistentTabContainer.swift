import SwiftUI
import UIKit

/// Owns the public tab models so their accessibility identity exists before presentation.
struct PersistentTabContainer<Landmarks: View, Favorites: View, DeepLinks: View>: UIViewControllerRepresentable {
    @Binding var selection: Navigator.Tab
    @ViewBuilder var landmarks: Landmarks
    @ViewBuilder var favorites: Favorites
    @ViewBuilder var deepLinks: DeepLinks

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeUIViewController(context: Context) -> UITabBarController {
        let coordinator = context.coordinator
        let landmarksHost = UIHostingController(rootView: HostedTab(content: landmarks, environment: context.environment))
        let favoritesHost = UIHostingController(rootView: HostedTab(content: favorites, environment: context.environment))
        let deepLinksHost = UIHostingController(rootView: HostedTab(content: deepLinks, environment: context.environment))
        coordinator.landmarks = landmarksHost
        coordinator.favorites = favoritesHost
        coordinator.deepLinks = deepLinksHost

        let landmarksTab = UITab(title: "Landmarks", image: UIImage(systemName: "map"), identifier: Navigator.Tab.landmarks.rawValue) { _ in landmarksHost }
        let favoritesTab = UITab(title: "Favorites", image: UIImage(systemName: "heart"), identifier: Navigator.Tab.favorites.rawValue) { _ in favoritesHost }
        let deepLinksTab = UITab(title: "Deep Links", image: UIImage(systemName: "link"), identifier: Navigator.Tab.deepLinks.rawValue) { _ in deepLinksHost }
        favoritesTab.accessibilityIdentifier = "heart"

        let controller = UITabBarController(tabs: [landmarksTab, favoritesTab, deepLinksTab])
        controller.delegate = coordinator
        controller.selectedTab = controller.tabs.first { $0.identifier == selection.rawValue }
        return controller
    }

    func updateUIViewController(_ controller: UITabBarController, context: Context) {
        let coordinator = context.coordinator
        coordinator.selection = $selection
        // Update the environment and inputs without replacing hosts, tabs, or stack identity.
        coordinator.landmarks?.rootView = HostedTab(content: landmarks, environment: context.environment)
        coordinator.favorites?.rootView = HostedTab(content: favorites, environment: context.environment)
        coordinator.deepLinks?.rootView = HostedTab(content: deepLinks, environment: context.environment)
        if controller.selectedTab?.identifier != selection.rawValue {
            controller.selectedTab = controller.tabs.first { $0.identifier == selection.rawValue }
        }
    }

    final class Coordinator: NSObject, UITabBarControllerDelegate {
        var selection: Binding<Navigator.Tab>
        var landmarks: UIHostingController<HostedTab<Landmarks>>?
        var favorites: UIHostingController<HostedTab<Favorites>>?
        var deepLinks: UIHostingController<HostedTab<DeepLinks>>?

        init(selection: Binding<Navigator.Tab>) {
            self.selection = selection
        }

        func tabBarController(_ tabBarController: UITabBarController, didSelectTab selectedTab: UITab, previousTab: UITab?) {
            if let tab = Navigator.Tab(rawValue: selectedTab.identifier), selection.wrappedValue != tab {
                selection.wrappedValue = tab
            }
        }
    }

    /// Hosting controllers form a new SwiftUI root; explicitly carry the inherited environment.
    struct HostedTab<Content: View>: View {
        var content: Content
        var environment: EnvironmentValues

        var body: some View {
            content.environment(\.self, environment)
        }
    }
}
