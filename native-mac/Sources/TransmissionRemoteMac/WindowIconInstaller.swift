import AppKit
import SwiftUI

struct WindowIconInstaller: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)

        DispatchQueue.main.async {
            installIcon(for: view)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            installIcon(for: nsView)
        }
    }

    private func installIcon(for view: NSView) {
        guard let icon = AppIcon.image else {
            return
        }

        NSApplication.shared.applicationIconImage = icon
        view.window?.miniwindowImage = icon
        view.window?.representedURL = nil
        view.window?.tabbingMode = .disallowed
    }
}
