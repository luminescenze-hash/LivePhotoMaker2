import SwiftUI

struct FolderCardView: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let folder: FolderRef?
    let selectTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 38, height: 38)
                    .background(
                        Color.accentColor.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 10)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                if let folder {
                    Label(folder.name, systemImage: "folder.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("尚未选择")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 8)

                Button(folder == nil ? selectTitle : "更换") {
                    action()
                }
                .font(.footnote.weight(.medium))
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
