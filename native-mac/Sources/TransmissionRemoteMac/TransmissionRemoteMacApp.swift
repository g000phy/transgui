import AppKit
import SwiftUI

@main
struct TransmissionRemoteMacApp: App {
    @State private var appModel = AppModel()

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
        AppIcon.install()
    }

    var body: some Scene {
        Window("Transmission Remote Mac", id: "main") {
            ContentView()
                .environment(appModel)
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowResizability(.contentMinSize)
        .commands {
            SidebarCommands()
            ToolbarCommands()
        }

        Settings {
            SettingsView()
        }
    }
}

enum AppIcon {
    static var image: NSImage? {
        guard let iconURL = Bundle.main.url(forResource: "TransmissionRemoteMac", withExtension: "icns") else {
            return nil
        }

        return NSImage(contentsOf: iconURL)
    }

    @MainActor
    static func install() {
        guard let image else {
            return
        }

        NSApplication.shared.applicationIconImage = image
    }
}
