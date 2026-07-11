import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            CompareView()
                .tabItem { Label("Compare", systemImage: "person.2.fill") }

            StudioView()
                .tabItem { Label("Studio", systemImage: "paintbrush.fill") }

            TimelineView()
                .tabItem { Label("Timeline", systemImage: "calendar") }

            SettingsView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}

#Preview {
    RootTabView()
}
