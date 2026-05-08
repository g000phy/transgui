import SwiftUI
import TransmissionRPC

struct TorrentTable: View {
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
        GeometryReader { proxy in
            let layout = TorrentTableLayout(width: proxy.size.width)

            VStack(spacing: 0) {
                header(layout: layout)
                    .frame(height: 30)
                    .padding(.horizontal, 8)

                Divider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(torrents) { torrent in
                            row(torrent, layout: layout)
                                .padding(.horizontal, 8)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private func header(layout: TorrentTableLayout) -> some View {
        HStack(spacing: 0) {
            headerCell("Name", width: layout.name)
            headerCell("Size", width: layout.size)
            headerCell("Size left", width: layout.sizeLeft)
            headerCell("Status", width: layout.status)
            headerCell("Seeds", width: layout.seeds)
            headerCell("Peers", width: layout.peers)
            headerCell("Down speed", width: layout.downSpeed)
            headerCell("Up speed", width: layout.upSpeed)
            headerCell("ETA", width: layout.eta)
            headerCell("Ratio", width: layout.ratio)
            headerCell("Priority", width: layout.priority)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func row(_ torrent: Torrent, layout: TorrentTableLayout) -> some View {
        let isSelected = selectedTorrentID == torrent.id

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor : Color.clear)

            VStack(spacing: 6) {
                HStack(spacing: 0) {
                    rowCell(torrent.name, width: layout.name, isSelected: isSelected)
                    rowCell(ByteFormat.compactFileSize(torrent.totalSize), width: layout.size, isSelected: isSelected, monospaced: true)
                    rowCell(ByteFormat.compactFileSize(torrent.leftUntilDone), width: layout.sizeLeft, isSelected: isSelected, monospaced: true)
                    rowCell(torrent.status.displayName, width: layout.status, isSelected: isSelected)
                    rowCell(count(torrent.seedCount), width: layout.seeds, isSelected: isSelected, monospaced: true)
                    rowCell(count(torrent.peerCount), width: layout.peers, isSelected: isSelected, monospaced: true)
                    rowCell(ByteFormat.compactTransferRate(torrent.rateDownload), width: layout.downSpeed, isSelected: isSelected, monospaced: true)
                    rowCell(ByteFormat.compactTransferRate(torrent.rateUpload), width: layout.upSpeed, isSelected: isSelected, monospaced: true)
                    rowCell(eta(torrent), width: layout.eta, isSelected: isSelected, monospaced: true)
                    rowCell(ratio(torrent.uploadRatio), width: layout.ratio, isSelected: isSelected, color: isSelected ? .white : ratioColor(torrent.uploadRatio), monospaced: true)

                    priorityMenu(for: torrent)
                        .frame(width: layout.priority, alignment: .leading)
                }

                FullWidthProgressBar(value: torrent.percentDone, isSelected: isSelected)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .frame(height: 56)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTorrentID = torrent.id
        }
        .contextMenu {
            TorrentContextMenu(
                torrentID: torrent.id,
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

    private func headerCell(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .lineLimit(1)
            .frame(width: width, alignment: .leading)
    }

    private func rowCell(
        _ title: String,
        width: CGFloat,
        isSelected: Bool,
        color: Color? = nil,
        monospaced: Bool = false
    ) -> some View {
        Text(title)
            .lineLimit(1)
            .truncationMode(.tail)
            .font(monospaced ? .body.monospacedDigit() : .body)
            .foregroundStyle(color ?? (isSelected ? Color.white : Color.primary))
            .frame(width: width, alignment: .leading)
    }

    private func priorityMenu(for torrent: Torrent) -> some View {
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
                .lineLimit(1)
        }
        .menuStyle(.button)
        .controlSize(.small)
        .disabled(!canRunTorrentCommand)
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

private struct FullWidthProgressBar: View {
    let value: Double
    let isSelected: Bool

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(isSelected ? .white.opacity(0.28) : .secondary.opacity(0.15))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(isSelected ? .white.opacity(0.92) : Color.accentColor)
                        .frame(width: proxy.size.width * min(max(value, 0), 1))
                }
        }
        .frame(height: 4)
    }
}

private struct TorrentTableLayout {
    let name: CGFloat
    let size: CGFloat
    let sizeLeft: CGFloat
    let status: CGFloat
    let seeds: CGFloat
    let peers: CGFloat
    let downSpeed: CGFloat
    let upSpeed: CGFloat
    let eta: CGFloat
    let ratio: CGFloat
    let priority: CGFloat

    init(width: CGFloat) {
        let base: [CGFloat] = [180, 64, 72, 90, 50, 50, 78, 74, 60, 56, 84]
        let minimum: [CGFloat] = [150, 60, 68, 80, 45, 45, 72, 70, 56, 52, 80]
        let baseTotal = base.reduce(0, +)
        let minimumTotal = minimum.reduce(0, +)
        let available = max(width - 16, minimumTotal)

        let values: [CGFloat]
        if available >= baseTotal {
            let scale = available / baseTotal
            values = base.map { $0 * scale }
        } else {
            let progress = max(0, min(1, (available - minimumTotal) / (baseTotal - minimumTotal)))
            values = zip(minimum, base).map { minValue, baseValue in
                minValue + (baseValue - minValue) * progress
            }
        }

        self.name = values[0]
        self.size = values[1]
        self.sizeLeft = values[2]
        self.status = values[3]
        self.seeds = values[4]
        self.peers = values[5]
        self.downSpeed = values[6]
        self.upSpeed = values[7]
        self.eta = values[8]
        self.ratio = values[9]
        self.priority = values[10]
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
