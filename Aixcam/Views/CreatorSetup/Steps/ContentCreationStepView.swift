import SwiftUI
import UniformTypeIdentifiers

struct ContentCreationStepView: View {
    @ObservedObject var viewModel: CreatorSetupViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var newAlbumName = ""
    @State private var showAlbumSheet = false

    var body: some View {
        VStack(spacing: 20) {
            GlassCard(
                title: "Content Creation",
                subtitle: "Upload photos, videos, and organize into albums"
            ) {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        MediaPickerButton(mediaType: .photo) { data, type in
                            Task { await viewModel.addMedia(data: data, type: type) }
                        }
                        MediaPickerButton(mediaType: .video) { data, type in
                            Task { await viewModel.addMedia(data: data, type: type) }
                        }
                    }

                    albumsSection
                    categoryFilter
                    mediaGrid
                }
            }
        }
        .sheet(isPresented: $showAlbumSheet) {
            NavigationStack {
                Form {
                    TextField("Album name", text: $newAlbumName)
                }
                .navigationTitle("New Album")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAlbumSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") {
                            if !newAlbumName.isEmpty {
                                viewModel.createAlbum(name: newAlbumName)
                                newAlbumName = ""
                                showAlbumSheet = false
                            }
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private var albumsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Albums")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    showAlbumSheet = true
                } label: {
                    Label("New Album", systemImage: "folder.badge.plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if viewModel.albums.isEmpty {
                Text("Create albums to organize your content")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.albums) { album in
                            let count = viewModel.mediaItems.filter { $0.albumId == album.id }.count
                            VStack(alignment: .leading, spacing: 4) {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(DesignTokens.Colors.accent)
                                Text(album.name)
                                    .font(.caption.weight(.semibold))
                                Text("\(count) items")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(DesignTokens.Colors.cardFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ContentCategory.allCases) { category in
                    let count = viewModel.mediaItems.filter { $0.category == category }.count
                    HStack(spacing: 4) {
                        Image(systemName: category.icon)
                        Text(category.rawValue)
                        if count > 0 {
                            Text("(\(count))")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DesignTokens.Colors.cardFill(for: colorScheme), in: Capsule())
                }
            }
        }
    }

    @ViewBuilder
    private var mediaGrid: some View {
        if viewModel.mediaItems.isEmpty {
            EmptyStateView(
                icon: "photo.on.rectangle.angled",
                title: "No content yet",
                message: "Upload photos and videos to build your creator portfolio"
            )
        } else {
            Text("Drag to reorder")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ForEach(viewModel.mediaItems) { item in
                    MediaItemCard(
                        item: item,
                        albums: viewModel.albums,
                        onDelete: { viewModel.deleteMedia(item) },
                        onCategoryChange: { viewModel.assignToCategory(item, category: $0) },
                        onAlbumChange: { viewModel.assignToAlbum(item, albumId: $0) }
                    )
                    .onDrag {
                        viewModel.draggedMediaId = item.id
                        return NSItemProvider(object: item.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: MediaDropDelegate(
                        item: item,
                        items: $viewModel.mediaItems,
                        draggedId: $viewModel.draggedMediaId,
                        onReorder: { viewModel.debouncedSave() }
                    ))
                }
            }
        }
    }
}

private struct MediaItemCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: CreatorMediaItem
    let albums: [ContentAlbum]
    let onDelete: () -> Void
    let onCategoryChange: (ContentCategory) -> Void
    let onAlbumChange: (UUID?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignTokens.Colors.cardFill(for: colorScheme))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        VStack(spacing: 6) {
                            Image(systemName: item.mediaType.icon)
                                .font(.title)
                                .foregroundStyle(DesignTokens.Colors.accent)
                            Text(item.title)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }

                Image(systemName: item.mediaType == .video ? "play.circle.fill" : "photo.fill")
                    .font(.caption)
                    .padding(6)
                    .background(.ultraThinMaterial, in: Circle())
                    .padding(6)
            }

            Menu {
                Menu("Category") {
                    ForEach(ContentCategory.allCases) { cat in
                        Button(cat.rawValue) { onCategoryChange(cat) }
                    }
                }
                Menu("Album") {
                    Button("None") { onAlbumChange(nil) }
                    ForEach(albums) { album in
                        Button(album.name) { onAlbumChange(album.id) }
                    }
                }
                Button("Delete", role: .destructive, action: onDelete)
            } label: {
                HStack {
                    Image(systemName: item.category.icon)
                    Text(item.category.rawValue)
                        .font(.caption2)
                    Spacer()
                    Image(systemName: "ellipsis")
                        .font(.caption2)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

private struct MediaDropDelegate: DropDelegate {
    let item: CreatorMediaItem
    @Binding var items: [CreatorMediaItem]
    @Binding var draggedId: UUID?
    let onReorder: () -> Void

    func performDrop(info: DropInfo) -> Bool {
        draggedId = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedId, draggedId != item.id,
              let from = items.firstIndex(where: { $0.id == draggedId }),
              let to = items.firstIndex(where: { $0.id == item.id }) else { return }

        withAnimation(.spring(response: 0.3)) {
            items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
        onReorder()
    }
}
