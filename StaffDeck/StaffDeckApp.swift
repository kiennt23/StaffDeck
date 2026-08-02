import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct StaffDeckApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .onAppear(perform: installMacAppIcon)
                .task { await model.start() }
        }
        #if os(macOS)
        .defaultSize(width: 1_260, height: 820)
        #endif
    }

    private func installMacAppIcon() {
        #if os(macOS)
        guard
            let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
            let icon = NSImage(contentsOf: iconURL)
        else { return }
        NSApplication.shared.applicationIconImage = icon
        #endif
    }
}
