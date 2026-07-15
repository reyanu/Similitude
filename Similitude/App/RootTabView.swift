import SwiftUI

enum AppTab: Hashable {
    case home, compare, studio, timeline, profile
}

struct RootTabView: View {
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeView(selection: $selection)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)

            CompareView()
                .tabItem { Label("Compare", systemImage: "person.2.fill") }
                .tag(AppTab.compare)

            StudioView()
                .tabItem { Label("Studio", systemImage: "paintbrush.fill") }
                .tag(AppTab.studio)

            TimelineView()
                .tabItem { Label("Timeline", systemImage: "calendar") }
                .tag(AppTab.timeline)

            SettingsView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
    }
}

#Preview {
    RootTabView()
}
