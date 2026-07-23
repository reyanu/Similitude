import SwiftUI

@main
struct SimilitudeApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .tint(Brand.accent)
                // The brand palette is dark navy/purple with white text on
                // every page, so the app always renders in dark appearance.
                .preferredColorScheme(.dark)
        }
    }
}
