import CoreGraphics
import Foundation
import SwiftUI

enum TorrentTableColumn: String, CaseIterable, Codable, Identifiable {
    case name
    case progress
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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: "Name"
        case .progress: "Progress"
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

    var width: (min: CGFloat, ideal: CGFloat, max: CGFloat?) {
        switch self {
        case .name:
            (160, 260, nil)
        case .progress:
            (80, 120, nil)
        case .size:
            (60, 64, 120)
        case .sizeLeft:
            (68, 72, 130)
        case .status:
            (80, 90, nil)
        case .seeds, .peers:
            (45, 50, 90)
        case .downSpeed:
            (72, 78, nil)
        case .upSpeed:
            (70, 74, nil)
        case .eta:
            (56, 60, 120)
        case .ratio:
            (52, 56, 100)
        case .priority:
            (80, 84, 150)
        }
    }
}

struct TorrentTableColumnPreferences: Codable, Equatable {
    static let storageKey = "torrentTableColumnPreferences"
    static let defaultValue = TorrentTableColumnPreferences(
        order: TorrentTableColumn.allCases,
        hidden: []
    )

    var order: [TorrentTableColumn]
    var hidden: Set<TorrentTableColumn>

    init(order: [TorrentTableColumn], hidden: Set<TorrentTableColumn>) {
        self.order = order
        self.hidden = hidden
        normalize()
    }

    init(encoded: String) {
        guard
            let data = encoded.data(using: .utf8),
            let decoded = try? JSONDecoder().decode(Self.self, from: data)
        else {
            self = Self.defaultValue
            return
        }

        self = decoded
        normalize()
    }

    var encoded: String {
        guard
            let data = try? JSONEncoder().encode(self),
            let string = String(data: data, encoding: .utf8)
        else {
            return Self.defaultValue.encoded
        }

        return string
    }

    var visibleColumns: [TorrentTableColumn] {
        order.filter { !hidden.contains($0) }
    }

    mutating func setVisible(_ isVisible: Bool, for column: TorrentTableColumn) {
        if isVisible {
            hidden.remove(column)
        } else {
            hidden.insert(column)
        }
        normalize()
    }

    mutating func move(from source: IndexSet, to destination: Int) {
        order.move(fromOffsets: source, toOffset: destination)
        normalize()
    }

    mutating func moveUp(_ column: TorrentTableColumn) {
        guard let index = order.firstIndex(of: column), index > order.startIndex else {
            return
        }

        order.swapAt(index, order.index(before: index))
    }

    mutating func moveDown(_ column: TorrentTableColumn) {
        guard let index = order.firstIndex(of: column), order.index(after: index) < order.endIndex else {
            return
        }

        order.swapAt(index, order.index(after: index))
    }

    mutating func reset() {
        self = Self.defaultValue
    }

    private mutating func normalize() {
        let allColumns = TorrentTableColumn.allCases
        let knownColumns = Set(allColumns)

        order = order.filter { knownColumns.contains($0) }

        for column in allColumns where !order.contains(column) {
            order.append(column)
        }

        hidden = hidden.intersection(knownColumns)

        if hidden.count == allColumns.count {
            hidden.remove(.name)
        }
    }
}
