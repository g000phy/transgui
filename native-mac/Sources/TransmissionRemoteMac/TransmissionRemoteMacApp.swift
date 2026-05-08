import SwiftUI

@main
struct TransmissionRemoteMacApp: App {
    @State private var appModel = AppModel()

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
