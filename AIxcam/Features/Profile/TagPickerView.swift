import SwiftUI

// MARK: — Wrapping layout

/// Lays subviews left-to-right, wrapping to a new row when the proposed width
/// runs out. SwiftUI ships no wrapping stack, and a LazyVGrid can't do it either
/// because chips are variable width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(maxWidth: maxWidth, subviews: subviews)

        let height = rows.reduce(into: CGFloat.zero) { total, row in
            total += row.height
        } + rowSpacing * CGFloat(max(0, rows.count - 1))

        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let additionalWidth = current.indices.isEmpty ? size.width : size.width + spacing

            if !current.indices.isEmpty && current.width + additionalWidth > maxWidth {
                rows.append(current)
                current = Row()
                current.indices = [index]
                current.width = size.width
                current.height = size.height
            } else {
                current.indices.append(index)
                current.width += additionalWidth
                current.height = max(current.height, size.height)
            }
        }

        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: — Chip

struct TagChip: View {
    let title: String
    var isSelected: Bool = false
    var showsRemoveIcon: Bool = false
    var tint: Color = .pink

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.subheadline)
            if showsRemoveIcon {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
            }
        }
        .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.85))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule().fill(isSelected ? tint.opacity(0.9) : Color.white.opacity(0.08))
        )
        .overlay(
            Capsule().stroke(
                isSelected ? tint.opacity(0.9) : Color.white.opacity(0.16),
                lineWidth: 1
            )
        )
    }
}

// MARK: — Picker sheet

/// Multi-select tag picker with a searchable preset catalog and free-text entry.
/// The catalog is a convenience; anything typed is accepted.
struct TagPickerView: View {
    let title: String
    let subtitle: String
    let catalog: [String]
    let tint: Color
    @Binding var selection: [String]

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var limit: Int { ViewerProfile.maxTags }

    private var filteredCatalog: [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return catalog }
        return catalog.filter { $0.localizedCaseInsensitiveContains(trimmed) }
    }

    /// True when the query is a real tag that isn't already in the catalog results
    /// or the current selection — i.e. worth offering as a custom add.
    private var customCandidate: String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let alreadyListed = catalog.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        let alreadyPicked = selection.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        return (alreadyListed || alreadyPicked) ? nil : trimmed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.5))

                        if !selection.isEmpty {
                            selectedSection
                        }

                        if let customCandidate {
                            addCustomButton(customCandidate)
                        }

                        catalogSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $query, prompt: "Search or type your own")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(tint)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var selectedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Selected")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.45))
                    .textCase(.uppercase)
                Spacer()
                Text("\(selection.count)/\(limit)")
                    .font(.caption)
                    .foregroundStyle(selection.count >= limit ? tint : .white.opacity(0.4))
            }

            FlowLayout {
                ForEach(selection, id: \.self) { tag in
                    Button {
                        remove(tag)
                    } label: {
                        TagChip(title: tag, isSelected: true, showsRemoveIcon: true, tint: tint)
                    }
                    .accessibilityLabel("Remove \(tag)")
                }
            }
        }
    }

    private func addCustomButton(_ candidate: String) -> some View {
        Button {
            add(candidate)
            query = ""
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("Add \u{201C}\(candidate)\u{201D}")
                    .font(.subheadline.weight(.medium))
                Spacer()
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
        }
        .disabled(selection.count >= limit)
        .opacity(selection.count >= limit ? 0.4 : 1)
    }

    private var catalogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggestions")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.45))
                .textCase(.uppercase)

            if filteredCatalog.isEmpty {
                Text("No suggestions match \u{201C}\(query)\u{201D} — you can add it as your own above.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.vertical, 8)
            } else {
                FlowLayout {
                    ForEach(filteredCatalog, id: \.self) { tag in
                        let selected = isSelected(tag)
                        Button {
                            selected ? remove(tag) : add(tag)
                        } label: {
                            TagChip(title: tag, isSelected: selected, tint: tint)
                        }
                        .disabled(!selected && selection.count >= limit)
                        .opacity(!selected && selection.count >= limit ? 0.35 : 1)
                        .accessibilityLabel(tag)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
        }
    }

    // MARK: — Mutation

    private func isSelected(_ tag: String) -> Bool {
        selection.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }

    private func add(_ tag: String) {
        guard selection.count < limit, !isSelected(tag) else { return }
        selection.append(tag)
    }

    private func remove(_ tag: String) {
        selection.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }
}

#Preview {
    @Previewable @State var selection: [String] = ["Gaming", "Music"]
    return TagPickerView(
        title: "Interests",
        subtitle: "Pick what you're into. You can add your own.",
        catalog: InterestCatalog.interests,
        tint: .pink,
        selection: $selection
    )
}
