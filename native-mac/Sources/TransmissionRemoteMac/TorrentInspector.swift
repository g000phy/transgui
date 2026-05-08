import SwiftUI
import TransmissionRPC

struct TorrentInspector: View {
    let torrent: Torrent?

    var body: some View {
        Group {
            if let torrent {
                Form {
                    Section("Overview") {
                        LabeledContent("Name", value: torrent.name)
                        LabeledContent("Progress", value: torrent.percentDone.formatted(.percent.precision(.fractionLength(0))))
                        LabeledContent("Size", value: ByteFormat.fileSize(torrent.totalSize))
                    }

                    Section("Transfer") {
                        LabeledContent("Download", value: ByteFormat.transferRate(torrent.rateDownload))
                        LabeledContent("Upload", value: ByteFormat.transferRate(torrent.rateUpload))
                    }
                }
                .formStyle(.grouped)
                .padding()
                .navigationTitle("Details")
            } else {
                ContentUnavailableView("No Torrent Selected", systemImage: "tray")
            }
        }
    }
}
