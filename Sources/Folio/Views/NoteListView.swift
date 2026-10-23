import SwiftUI
import SwiftData

struct NoteListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: [
        SortDescriptor(\Note.isPinned, order: .reverse),
        SortDescriptor(\Note.updatedAt, order: .reverse)
    ]) private var notes: [Note]

    @Binding var selectedNoteID: UUID?
    var searchText: String
    var onCreate: () -> Void

    private var filtered: [Note] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return notes }
        return notes.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.body.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        Group {
            if filtered.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Color.clear)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { index, note in
                    NoteRow(
                        note: note,
                        isSelected: selectedNoteID == note.id,
                        showsDivider: index < filtered.count - 1
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                            selectedNoteID = note.id
                        }
                    }
                    .contextMenu {
                        Button(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin") {
                            note.isPinned.toggle()
                            note.updatedAt = .now
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            delete(note)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
                }
            }
            .padding(.horizontal, horizontalSizeClass == .compact ? 16 : 12)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            FoldGlyph()
                .frame(width: 44, height: 44)
                .opacity(0.85)
            Text(searchText.isEmpty ? "Blank sheet" : "Nothing matches")
                .font(FolioFont.brushDisplay(28, relativeTo: .title3))
                .foregroundStyle(FolioTheme.ink)
            Text(searchText.isEmpty
                 ? "A fresh 米字格 page waits. Write with your finger or Apple Pencil — the paper listens."
                 : "Try another word, or clear the search.")
                .font(FolioFont.handwriting(20, relativeTo: .subheadline))
                .foregroundStyle(FolioTheme.inkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            if searchText.isEmpty {
                Button(action: onCreate) {
                    Text("New Note")
                        .font(FolioFont.handwriting(22, relativeTo: .headline))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(FolioTheme.sealRed, in: Capsule(style: .continuous))
                        .foregroundStyle(FolioTheme.paper)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func delete(_ note: Note) {
        if selectedNoteID == note.id {
            selectedNoteID = nil
        }
        modelContext.delete(note)
        try? modelContext.save()
    }
}

struct NoteRow: View {
    let note: Note
    var isSelected: Bool
    var showsDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(FolioTheme.accentColor(note.accent))
                    .frame(width: 3, height: 48)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if note.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(FolioTheme.sealRed)
                        }
                        Text(note.displayTitle)
                            .font(FolioFont.brushDisplay(22, relativeTo: .body))
                            .foregroundStyle(FolioTheme.ink)
                            .lineLimit(1)
                    }
                    Text(note.preview)
                        .font(FolioFont.handwriting(20, relativeTo: .subheadline))
                        .foregroundStyle(FolioTheme.inkSoft)
                        .lineLimit(2)
                    Text(note.updatedAt, style: .relative)
                        .font(FolioFont.handwriting(14, relativeTo: .caption))
                        .foregroundStyle(FolioTheme.inkSoft.opacity(0.85))
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(FolioTheme.paperDeep.opacity(0.72))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(FolioTheme.sealRed.opacity(0.28), lineWidth: 1)
                        }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isSelected)

            if showsDivider && !isSelected {
                Rectangle()
                    .fill(FolioTheme.gridRed)
                    .frame(height: 1)
                    .padding(.leading, 25)
            }
        }
    }
}
