import AppKit
import SwiftUI

@main
struct TransmissionRemoteMacApp: App {
    @State private var appModel = AppModel()

    init() {
        AppIcon.install()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowResizability(.contentMinSize)
        .commands {
            SidebarCommands()
            ToolbarCommands()
        }
    }
}

private enum AppIcon {
    @MainActor
    static func install() {
        guard
            let iconURL = Bundle.main.url(forResource: "TransmissionRemoteMac", withExtension: "icns"),
            let icon = NSImage(contentsOf: iconURL)
        else {
            return
        }

        NSApplication.shared.applicationIconImage = icon
    }
}
