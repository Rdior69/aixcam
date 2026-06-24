import PhotosUI
import SwiftUI

struct ImagePickerButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let systemImage: String
    let imageData: Data?
    var aspectRatio: CGFloat = 1
    var onImageSelected: (Data) -> Void

    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            ZStack {
                if let imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: systemImage)
                            .font(.title)
                            .foregroundStyle(DesignTokens.Colors.accent)

                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .background(DesignTokens.Colors.cardFill(for: colorScheme), in: RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: imageData == nil ? [8] : []))
                    .foregroundStyle(DesignTokens.Colors.glassStroke(for: colorScheme))
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium, style: .continuous))
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        onImageSelected(data)
                    }
                }
            }
        }
        .accessibilityLabel(title)
        .accessibilityHint("Double tap to select an image")
    }
}

struct MediaPickerButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let mediaType: MediaType
    var onMediaSelected: (Data, MediaType) -> Void

    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: mediaType == .video ? .videos : .images
        ) {
            Label("Add \(mediaType.rawValue)", systemImage: mediaType.icon)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
        .tint(DesignTokens.Colors.accent)
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        onMediaSelected(data, mediaType)
                    }
                }
            }
        }
    }
}

struct ColorPickerGrid: View {
    @Environment(\.colorScheme) private var colorScheme
    let colors: [String]
    @Binding var selectedHex: String

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
            ForEach(colors, id: \.self) { hex in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedHex = hex
                    }
                } label: {
                    Circle()
                        .fill(Color(hex: hex) ?? .teal)
                        .frame(width: 40, height: 40)
                        .overlay {
                            if selectedHex == hex {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay {
                            Circle()
                                .stroke(DesignTokens.Colors.glassStroke(for: colorScheme), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Color \(hex)\(selectedHex == hex ? ", selected" : "")")
            }
        }
    }
}
