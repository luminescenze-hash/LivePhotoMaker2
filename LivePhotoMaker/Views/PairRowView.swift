import SwiftUI
import UIKit

struct PairRowView: View {
    let pair: MediaPair
    let wasImportedBefore: Bool

    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            thumbnailView

            VStack(alignment: .leading, spacing: 4) {
                Text(pair.stem)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text("MOV \(format(pair.movie.size)) · JPG \(format(pair.photo.size))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                statusView
            }

            Spacer(minLength: 0)
        }
        .task(id: pair.id) {
            if thumbnail == nil {
                thumbnail = await ThumbnailLoader.thumbnail(for: pair.photo.url)
            }
        }
    }

    private var thumbnailView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemFill))

            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.body)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var statusView: some View {
        switch pair.status {
        case .pending:
            if wasImportedBefore {
                badge("已合成过", color: .blue)
            } else {
                badge("待合成", color: .gray)
            }
        case .importing:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.mini)
                Text("正在写入相册…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .imported:
            badge("已导入相册", color: .green)
        case .failed(let message):
            Text(message)
                .font(.caption2)
                .foregroundStyle(.red)
                .lineLimit(2)
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
