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
            Text(searchText.isEmpty ? "No notes yet" : "Nothing matches")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(FolioTheme.ink)
            Text(searchText.isEmpty
                 ? "New thoughts land here. Create one and Folio will keep it beside you when you unfold."
                 : "Try another word, or clear the search.")
                .font(.system(.subheadline, design: .default))
                .foregroundStyle(FolioTheme.inkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            if searchText.isEmpty {
                Button(action: onCreate) {
                    Text("New Note")
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(FolioTheme.ink, in: Capsule(style: .continuous))
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
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(FolioTheme.accentColor(note.accent))
                    .frame(width: 3, height: 42)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if note.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(FolioTheme.inkSoft)
                        }
                        Text(note.displayTitle)
                            .font(.system(.body, design: .serif).weight(.semibold))
                            .foregroundStyle(FolioTheme.ink)
                            .lineLimit(1)
                    }
                    Text(note.preview)
                        .font(.subheadline)
                        .foregroundStyle(FolioTheme.inkSoft)
                        .lineLimit(2)
                    Text(note.updatedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(FolioTheme.inkSoft.opacity(0.85))
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(FolioTheme.paperDeep.opacity(0.95))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(FolioTheme.hairline, lineWidth: 1)
                        }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isSelected)

            if showsDivider && !isSelected {
                Rectangle()
                    .fill(FolioTheme.hairline)
                    .frame(height: 1)
                    .padding(.leading, 25)
            }
        }
    }
}
