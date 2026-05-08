import AppKit
import CoreServices
import Foundation

enum DefaultAppManager {
    static let bundleIdentifier = "com.g000phy.TransmissionRemoteMac"
    static let torrentContentType = "org.bittorrent.torrent"

    static func makeDefault() -> DefaultAppStatus {
        registerCurrentBundle()

        _ = LSSetDefaultHandlerForURLScheme("magnet" as CFString, bundleIdentifier as CFString)
        _ = LSSetDefaultRoleHandlerForContentType(
            torrentContentType as CFString,
            .all,
            bundleIdentifier as CFString
        )

        return currentStatus()
    }

    static func currentStatus() -> DefaultAppStatus {
        let magnetHandler = URL(string: "magnet:?xt=urn:btih:0000000000000000000000000000000000000000")
            .flatMap(NSWorkspace.shared.urlForApplication(toOpen:))
            .flatMap { Bundle(url: $0)?.bundleIdentifier }

        let torrentHandler = LSCopyDefaultRoleHandlerForContentType(
            torrentContentType as CFString,
            .all
        )?.takeRetainedValue() as String?

        return DefaultAppStatus(
            isMagnetDefault: magnetHandler == bundleIdentifier,
            isTorrentDefault: torrentHandler == bundleIdentifier,
            magnetHandler: magnetHandler,
            torrentHandler: torrentHandler
        )
    }

    private static func registerCurrentBundle() {
        LSRegisterURL(Bundle.main.bundleURL as CFURL, true)
    }
}

struct DefaultAppStatus: Equatable {
    let isMagnetDefault: Bool
    let isTorrentDefault: Bool
    let magnetHandler: String?
    let torrentHandler: String?

    var isFullyDefault: Bool {
        isMagnetDefault && isTorrentDefault
    }
}
