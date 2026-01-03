import SwiftUI

struct AlbumArtworkView: View {
    let url: URL?
    let title: String
    let size: CGFloat
    let cornerRadius: CGFloat

    init(
        url: URL?,
        title: String,
        size: CGFloat = 300,
        cornerRadius: CGFloat = 12
    ) {
        self.url = url
        self.title = title
        self.size = size
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityLabel("Album artwork for \(title)")
    }

    @ViewBuilder
    private var content: some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholder
                        .overlay(ProgressView())
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.3))
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.2))
                    .foregroundStyle(.secondary)
            }
    }
}

#Preview {
    VStack(spacing: 24) {
        AlbumArtworkView(
            url: URL(string: "https://picsum.photos/300"),
            title: "Preview Song",
            size: 180,
            cornerRadius: 16
        )

        AlbumArtworkView(
            url: nil,
            title: "Placeholder Song",
            size: 180,
            cornerRadius: 16
        )
    }
    .padding()
}
