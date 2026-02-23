import SwiftUI

struct ProgressOverlay: View {
    let title: String
    let progress: Double
    var downloadedBytes: Int64 = 0
    var totalBytes: Int64 = 0
    var speed: Double = 0 // bytes per second

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline)

            ProgressView(value: progress)
                .progressViewStyle(.linear)

            HStack {
                if totalBytes > 0 {
                    Text("\(formattedSize(downloadedBytes)) / \(formattedSize(totalBytes))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if speed > 0 {
                HStack {
                    Text("\(formattedSize(Int64(speed)))/s")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Spacer()

                    if speed > 0 && totalBytes > downloadedBytes {
                        let remaining = Double(totalBytes - downloadedBytes) / speed
                        Text("\(formattedTime(remaining)) remaining")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(24)
        .frame(minWidth: 260)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formattedTime(_ seconds: Double) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            let m = Int(seconds) / 60
            let s = Int(seconds) % 60
            return "\(m)m \(s)s"
        } else {
            let h = Int(seconds) / 3600
            let m = (Int(seconds) % 3600) / 60
            return "\(h)h \(m)m"
        }
    }
}
