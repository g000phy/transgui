import SwiftUI
import TransmissionRPC

struct TorrentTable: View {
    @AppStorage(TorrentTableColumnPreferences.storageKey)
    private var encodedColumnPreferences = TorrentTableColumnPreferences.defaultValue.encoded

    let torrents: [Torrent]
    @Binding var selectedTorrentID: Torrent.ID?
    let canRunTorrentCommand: Bool
    let start: (Torrent.ID) -> Void
    let forceStart: (Torrent.ID) -> Void
    let stop: (Torrent.ID) -> Void
    let remove: (Torrent.ID, Bool) -> Void
    let setPriority: (Torrent.ID, BandwidthPriority) -> Void
    let reannounce: (Torrent.ID) -> Void
    let verify: (Torrent.ID) -> Void

    var body: some View {
        Table(torrents, selection: $selectedTorrentID) {
            tableColumn(at: 0)
            tableColumn(at: 1)
            tableColumn(at: 2)
            tableColumn(at: 3)
            tableColumn(at: 4)
            tableColumn(at: 5)
            tableColumn(at: 6)

            Group {
                tableColumn(at: 7)
                tableColumn(at: 8)
                tableColumn(at: 9)
                tableColumn(at: 10)
                tableColumn(at: 11)
            }
        }
        .contextMenu(forSelectionType: Torrent.ID.self) { selection in
            TorrentContextMenu(
                torrentID: selection.first ?? selectedTorrentID,
                canRunTorrentCommand: canRunTorrentCommand,
                start: start,
                forceStart: forceStart,
                stop: stop,
                remove: remove,
                setPriority: setPriority,
                reannounce: reannounce,
                verify: verify
            )
        }
    }

    private var columnPreferences: TorrentTableColumnPreferences {
        TorrentTableColumnPreferences(encoded: encodedColumnPreferences)
    }

    @TableColumnBuilder<Torrent, Never>
    private func tableColumn(at index: Int) -> some TableColumnContent<Torrent, Never> {
        let columns = columnPreferences.visibleColumns
        if columns.indices.contains(index) {
            tableColumn(columns[index])
        }
    }

    @TableColumnBuilder<Torrent, Never>
    private func tableColumn(_ column: TorrentTableColumn) -> some TableColumnContent<Torrent, Never> {
        switch column {
        case .name:
            TableColumn(column.title) { torrent in
                Text(torrent.name)
                    .lineLimit(1)
            }
            .width(min: 160, ideal: 260, max: .infinity)

        case .progress:
            TableColumn(column.title) { torrent in
                ProgressView(value: torrent.percentDone)
                    .controlSize(.small)
            }
            .width(min: 80, ideal: 120, max: .infinity)

        case .size:
            TableColumn(column.title) { torrent in
                Text(ByteFormat.compactFileSize(torrent.totalSize))
                    .monospacedDigit()
            }
            .width(min: 60, ideal: 64, max: 120)

        case .sizeLeft:
            TableColumn(column.title) { torrent in
                Text(ByteFormat.compactFileSize(torrent.leftUntilDone))
                    .monospacedDigit()
            }
            .width(min: 68, ideal: 72, max: 130)

        case .status:
            TableColumn(column.title) { torrent in
                Text(torrent.status.displayName)
                    .foregroundStyle(torrent.status == .unknown ? .secondary : .primary)
                    .lineLimit(1)
            }
            .width(min: 80, ideal: 90, max: .infinity)

        case .seeds:
            TableColumn(column.title) { torrent in
                Text(count(torrent.seedCount))
                    .monospacedDigit()
            }
            .width(min: 45, ideal: 50, max: 90)

        case .peers:
            TableColumn(column.title) { torrent in
                Text(count(torrent.peerCount))
                    .monospacedDigit()
            }
            .width(min: 45, ideal: 50, max: 90)

        case .downSpeed:
            TableColumn(column.title) { torrent in
                Text(ByteFormat.compactTransferRate(torrent.rateDownload))
                    .monospacedDigit()
            }
            .width(min: 72, ideal: 78, max: .infinity)

        case .upSpeed:
            TableColumn(column.title) { torrent in
                Text(ByteFormat.compactTransferRate(torrent.rateUpload))
                    .monospacedDigit()
            }
            .width(min: 70, ideal: 74, max: .infinity)

        case .eta:
            TableColumn(column.title) { torrent in
                Text(eta(torrent))
                    .monospacedDigit()
            }
            .width(min: 56, ideal: 60, max: 120)

        case .ratio:
            TableColumn(column.title) { torrent in
                Text(ratio(torrent.uploadRatio))
                    .monospacedDigit()
                    .foregroundStyle(ratioColor(torrent.uploadRatio))
            }
            .width(min: 52, ideal: 56, max: 100)

        case .priority:
            TableColumn(column.title) { torrent in
                Menu {
                    ForEach(BandwidthPriority.allCases) { priority in
                        Button {
                            setPriority(torrent.id, priority)
                        } label: {
                            if torrent.bandwidthPriority == priority {
                                Label(priority.title, systemImage: "checkmark")
                            } else {
                                Text(priority.title)
                            }
                        }
                    }
                } label: {
                    Text(torrent.bandwidthPriority?.title ?? "Normal")
                }
                .menuStyle(.button)
                .controlSize(.small)
                .disabled(!canRunTorrentCommand)
            }
            .width(min: 80, ideal: 84, max: 150)
        }
    }

    private func count(_ value: Int?) -> String {
        guard let value else {
            return "-"
        }
        return value.formatted()
    }

    private func eta(_ torrent: Torrent) -> String {
        if torrent.leftUntilDone == 0 || torrent.percentDone >= 1 {
            return "Done"
        }

        if let eta = torrent.eta, eta > 0 {
            return DurationFormat.compact(seconds: eta)
        }

        if let leftUntilDone = torrent.leftUntilDone, torrent.rateDownload > 0 {
            return DurationFormat.compact(seconds: Int(leftUntilDone / torrent.rateDownload))
        }

        return "-"
    }

    private func ratio(_ value: Double?) -> String {
        guard let value, value >= 0 else {
            return "-"
        }
        return value.formatted(.number.precision(.fractionLength(2)))
    }

    private func ratioColor(_ value: Double?) -> Color {
        guard let value, value >= 0 else {
            return .secondary
        }

        if value < 1 {
            return .orange
        }

        if value < 2 {
            return Color(red: 0.55, green: 0.68, blue: 0.12)
        }

        return .green
    }
}

private struct TorrentContextMenu: View {
    let torrentID: Torrent.ID?
    let canRunTorrentCommand: Bool
    let start: (Torrent.ID) -> Void
    let forceStart: (Torrent.ID) -> Void
    let stop: (Torrent.ID) -> Void
    let remove: (Torrent.ID, Bool) -> Void
    let setPriority: (Torrent.ID, BandwidthPriority) -> Void
    let reannounce: (Torrent.ID) -> Void
    let verify: (Torrent.ID) -> Void

    private var canRun: Bool {
        canRunTorrentCommand && torrentID != nil
    }

    var body: some View {
        Button {
            run(start)
        } label: {
            Label("Start", systemImage: "play.circle")
        }
        .disabled(!canRun)

        Button {
            run(forceStart)
        } label: {
            Label("Force Start", systemImage: "play.circle.fill")
        }
        .disabled(!canRun)

        Button {
            run(stop)
        } label: {
            Label("Stop", systemImage: "pause.circle")
        }
        .disabled(!canRun)

        Divider()

        Button(role: .destructive) {
            run { remove($0, false) }
        } label: {
            Label("Remove", systemImage: "trash")
        }
        .disabled(!canRun)

        Button(role: .destructive) {
            run { remove($0, true) }
        } label: {
            Label("Remove Torrent and Data", systemImage: "trash.fill")
        }
        .disabled(!canRun)

        Divider()

        Menu {
            ForEach(BandwidthPriority.allCases) { priority in
                Button {
                    run { setPriority($0, priority) }
                } label: {
                    Label(priority.title, systemImage: priority.systemImage)
                }
            }
        } label: {
            Label("Priority", systemImage: "arrow.up.arrow.down.circle")
        }
        .disabled(!canRun)

        Divider()

        Button {
            run(reannounce)
        } label: {
            Label("Reannounce", systemImage: "antenna.radiowaves.left.and.right")
        }
        .disabled(!canRun)

        Button {
            run(verify)
        } label: {
            Label("Verify", systemImage: "checkmark.seal")
        }
        .disabled(!canRun)
    }

    private func run(_ action: (Torrent.ID) -> Void) {
        guard let torrentID else {
            return
        }

        action(torrentID)
    }
}

private extension BandwidthPriority {
    var systemImage: String {
        switch self {
        case .low:
            "arrow.down.circle"
        case .normal:
            "minus.circle"
        case .high:
            "arrow.up.circle"
        }
    }
}

extension TorrentStatus {
    var displayName: String {
        switch self {
        case .stopped:
            "Stopped"
        case .checkWait:
            "Waiting check"
        case .check:
            "Checking"
        case .downloadWait:
            "Queued"
        case .download:
            "Downloading"
        case .seedWait:
            "Waiting seed"
        case .seed:
            "Seeding"
        case .unknown:
            "Unknown"
        }
    }
}

enum ByteFormat {
    static func fileSize(_ byteCount: Int64) -> String {
        fileFormatter.string(fromByteCount: byteCount)
    }

    static func compactFileSize(_ byteCount: Int64?) -> String {
        guard let byteCount else {
            return "-"
        }
        return compact(byteCount: byteCount)
    }

    static func transferRate(_ byteCount: Int64) -> String {
        "\(fileFormatter.string(fromByteCount: byteCount))/s"
    }

    static func compactTransferRate(_ byteCount: Int64) -> String {
        "\(compact(byteCount: byteCount))/s"
    }

    private static func compact(byteCount: Int64) -> String {
        let units: [(threshold: Double, suffix: String)] = [
            (1_099_511_627_776, "TB"),
            (1_073_741_824, "GB"),
            (1_048_576, "MB"),
            (1_024, "KB")
        ]

        let absoluteByteCount = abs(Double(byteCount))
        let sign = byteCount < 0 ? "-" : ""

        guard let unit = units.first(where: { absoluteByteCount >= $0.threshold }) else {
            return "\(byteCount)B"
        }

        let value = absoluteByteCount / unit.threshold
        let precision = value >= 100 ? 0 : value >= 10 ? 1 : 2
        let formatted = value.formatted(.number.precision(.fractionLength(0...precision)))
        return "\(sign)\(formatted)\(unit.suffix)"
    }

    private static var fileFormatter: ByteCountFormatter {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        return formatter
    }
}

enum DurationFormat {
    static func compact(seconds: Int) -> String {
        guard seconds >= 0 else {
            return "-"
        }

        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        let seconds = seconds % 60

        if days > 0 {
            return "\(days)d \(hours)h"
        }

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }

        return "\(seconds)s"
    }
}
