import SwiftUI
import TransmissionRPC

struct TorrentTable: View {
    private static let leadingInset: CGFloat = 8
    private static let trailingInset: CGFloat = 16

    @State private var columnWidths = TorrentTableColumn.defaultWidths
    @State private var resizeStartWidths: [TorrentTableColumn: CGFloat] = [:]
    @State private var userResizedColumns = false

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
            let layout = TorrentTableLayout(
                width: proxy.size.width,
                columnWidths: columnWidths,
                scalesColumns: !userResizedColumns
            )
            let bodyHeight = max(proxy.size.height - 31, 0)

            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    header(layout: layout)
                        .frame(width: layout.rowWidth, height: 30, alignment: .leading)
                        .padding(.leading, Self.leadingInset)
                        .padding(.trailing, Self.trailingInset)

                    Divider()

                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            ForEach(torrents) { torrent in
                                row(torrent, layout: layout)
                                    .padding(.leading, Self.leadingInset)
                                    .padding(.trailing, Self.trailingInset)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .frame(height: bodyHeight, alignment: .top)
                }
                .frame(width: layout.tableWidth, height: proxy.size.height, alignment: .topLeading)
            }
        }
    }

    private func header(layout: TorrentTableLayout) -> some View {
        HStack(spacing: 0) {
            ForEach(TorrentTableColumn.allCases) { column in
                headerCell(column, width: layout.width(for: column))
            }

            Spacer(minLength: 0)
                .frame(width: layout.trailingGutter)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func row(_ torrent: Torrent, layout: TorrentTableLayout) -> some View {
        let isSelected = selectedTorrentID == torrent.id

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor : Color.clear)
                .frame(width: layout.visibleRowWidth, height: 56)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 0) {
                    rowCell(torrent.name, width: layout.width(for: .name), isSelected: isSelected)
                    rowCell(ByteFormat.compactFileSize(torrent.totalSize), width: layout.width(for: .size), isSelected: isSelected, monospaced: true)
                    rowCell(ByteFormat.compactFileSize(torrent.leftUntilDone), width: layout.width(for: .sizeLeft), isSelected: isSelected, monospaced: true)
                    rowCell(torrent.status.displayName, width: layout.width(for: .status), isSelected: isSelected)
                    rowCell(count(torrent.seedCount), width: layout.width(for: .seeds), isSelected: isSelected, monospaced: true)
                    rowCell(count(torrent.peerCount), width: layout.width(for: .peers), isSelected: isSelected, monospaced: true)
                    rowCell(ByteFormat.compactTransferRate(torrent.rateDownload), width: layout.width(for: .downSpeed), isSelected: isSelected, monospaced: true)
                    rowCell(ByteFormat.compactTransferRate(torrent.rateUpload), width: layout.width(for: .upSpeed), isSelected: isSelected, monospaced: true)
                    rowCell(eta(torrent), width: layout.width(for: .eta), isSelected: isSelected, monospaced: true)
                    rowCell(ratio(torrent.uploadRatio), width: layout.width(for: .ratio), isSelected: isSelected, color: isSelected ? .white : ratioColor(torrent.uploadRatio), monospaced: true)

                    priorityMenu(for: torrent, isSelected: isSelected)
                        .frame(width: layout.width(for: .priority), alignment: .leading)

                    Spacer(minLength: 0)
                        .frame(width: layout.trailingGutter)
                }

                FullWidthProgressBar(value: torrent.percentDone, isSelected: isSelected)
                    .frame(width: layout.progressWidth, alignment: .leading)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .frame(height: 56)
        .frame(width: layout.rowWidth, alignment: .leading)
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

    private func headerCell(_ column: TorrentTableColumn, width: CGFloat) -> some View {
        Text(column.title)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(width: 1, height: 18)
                    .padding(.trailing, 4)
                    .overlay {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 12, height: 30)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 1)
                                    .onChanged { value in
                                        resizeColumn(column, translation: value.translation.width)
                                    }
                                    .onEnded { _ in
                                        resizeStartWidths[column] = nil
                                    }
                            )
                    }
            }
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

    private func priorityMenu(for torrent: Torrent, isSelected: Bool) -> some View {
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
            HStack(spacing: 6) {
                Text(torrent.bandwidthPriority?.title ?? "Normal")
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .imageScale(.small)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.white.opacity(0.18) : Color.secondary.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
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

    private func resizeColumn(_ column: TorrentTableColumn, translation: CGFloat) {
        let startWidth = resizeStartWidths[column] ?? columnWidths[column, default: column.defaultWidth]
        resizeStartWidths[column] = startWidth
        columnWidths[column] = max(column.minimumWidth, startWidth + translation)
        userResizedColumns = true
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

private enum TorrentTableColumn: Int, CaseIterable, Identifiable {
    case name
    case size
    case sizeLeft
    case status
    case seeds
    case peers
    case downSpeed
    case upSpeed
    case eta
    case ratio
    case priority

    var id: Self { self }

    var title: String {
        switch self {
        case .name: "Name"
        case .size: "Size"
        case .sizeLeft: "Size left"
        case .status: "Status"
        case .seeds: "Seeds"
        case .peers: "Peers"
        case .downSpeed: "Down speed"
        case .upSpeed: "Up speed"
        case .eta: "ETA"
        case .ratio: "Ratio"
        case .priority: "Priority"
        }
    }

    var defaultWidth: CGFloat {
        switch self {
        case .name: 460
        case .size: 70
        case .sizeLeft: 80
        case .status: 96
        case .seeds: 50
        case .peers: 50
        case .downSpeed: 84
        case .upSpeed: 78
        case .eta: 60
        case .ratio: 56
        case .priority: 90
        }
    }

    var minimumWidth: CGFloat {
        switch self {
        case .name: 160
        case .size, .sizeLeft, .downSpeed, .upSpeed, .priority: 64
        case .status: 72
        case .seeds, .peers, .eta, .ratio: 44
        }
    }

    static let defaultWidths: [TorrentTableColumn: CGFloat] = {
        Dictionary(uniqueKeysWithValues: allCases.map { ($0, $0.defaultWidth) })
    }()
}

private struct TorrentTableLayout {
    let tableWidth: CGFloat
    let rowWidth: CGFloat
    let visibleRowWidth: CGFloat
    let contentWidth: CGFloat
    let progressWidth: CGFloat
    let trailingGutter: CGFloat
    private let widths: [TorrentTableColumn: CGFloat]

    init(
        width: CGFloat,
        columnWidths: [TorrentTableColumn: CGFloat],
        scalesColumns: Bool
    ) {
        let leadingInset: CGFloat = 8
        let trailingInset: CGFloat = 16
        let baseTrailingGutter: CGFloat = 18
        let visibleRowWidth = max(0, width - leadingInset - trailingInset)
        let requested = Dictionary(
            uniqueKeysWithValues: TorrentTableColumn.allCases.map { column in
                (column, max(column.minimumWidth, columnWidths[column, default: column.defaultWidth]))
            }
        )
        let requestedTotal = TorrentTableColumn.allCases.reduce(0) { total, column in
            total + requested[column, default: column.defaultWidth]
        }
        let available = width - leadingInset - trailingInset - baseTrailingGutter
        let scale = scalesColumns && available > requestedTotal ? available / requestedTotal : 1
        let resolved = Dictionary(
            uniqueKeysWithValues: TorrentTableColumn.allCases.map { column in
                (column, requested[column, default: column.defaultWidth] * scale)
            }
        )
        let resolvedContentWidth = TorrentTableColumn.allCases.reduce(0) { total, column in
            total + resolved[column, default: column.defaultWidth]
        }
        let resolvedTrailingGutter = max(baseTrailingGutter, visibleRowWidth - resolvedContentWidth)
        let resolvedRowWidth = max(visibleRowWidth, resolvedContentWidth + resolvedTrailingGutter)

        self.widths = resolved
        self.visibleRowWidth = visibleRowWidth
        self.contentWidth = resolvedContentWidth
        self.progressWidth = max(0, visibleRowWidth - 16)
        self.trailingGutter = resolvedTrailingGutter
        self.rowWidth = resolvedRowWidth
        self.tableWidth = resolvedRowWidth + leadingInset + trailingInset
    }

    func width(for column: TorrentTableColumn) -> CGFloat {
        widths[column, default: column.defaultWidth]
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
