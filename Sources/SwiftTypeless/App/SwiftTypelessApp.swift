import SwiftUI

@main
struct SwiftTypelessApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(AppState.shared)
                .frame(width: 480, height: 600)
                .background(Color.appBackground)
                .preferredColorScheme(.dark)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 480, height: 600)
    }
}
