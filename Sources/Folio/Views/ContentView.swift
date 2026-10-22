import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: [
        SortDescriptor(\Note.isPinned, order: .reverse),
        SortDescriptor(\Note.updatedAt, order: .reverse)
    ]) private var notes: [Note]

    @State private var selectedNoteID: UUID?
    @State private var navigationPath: [UUID] = []
    @State private var searchText = ""
    @State private var showPoseHint = true

    private var selectedNote: Note? {
        notes.first { $0.id == selectedNoteID }
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactShell
            } else {
                duoShell
            }
        }
        .background { PaperBackground() }
        .tint(FolioTheme.moss)
        .onAppear {
            NoteSeed.insertIfNeeded(into: modelContext)
            if selectedNoteID == nil {
                selectedNoteID = notes.first?.id
            }
        }
    }

    // MARK: - Outer display / compact width

    private var compactShell: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                header(compact: true)
                NoteListView(
                    selectedNoteID: Binding(
                        get: { selectedNoteID },
                        set: { newValue in
                            selectedNoteID = newValue
                            guard let newValue else { return }
                            if navigationPath.last != newValue {
                                navigationPath.append(newValue)
                            }
                        }
                    ),
                    searchText: searchText,
                    onCreate: createNote
                )
            }
            .navigationDestination(for: UUID.self) { id in
                if let note = notes.first(where: { $0.id == id }) {
                    NoteEditorView(note: note, isCompact: true) {
                        delete(note)
                        navigationPath.removeLast()
                    }
                    .navigationTitle(note.displayTitle)
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .searchable(text: $searchText, prompt: "Search notes")
            .toolbar {
                ToolbarItem(placement: .topBarPinnedTrailing) {
                    Button("New Note", systemImage: "square.and.pencil", action: createNote)
                }
                .visibilityPriority(.high)
            }
        }
    }

    // MARK: - Inner display / regular width (ArrangementView)

    private var duoShell: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ArrangementView {
                    VStack(spacing: 0) {
                        header(compact: false)
                        NoteListView(
                            selectedNoteID: $selectedNoteID,
                            searchText: searchText,
                            onCreate: createNote
                        )
                    }
                } secondary: {
                    Group {
                        if let note = selectedNote {
                            NoteEditorView(note: note, isCompact: false) {
                                delete(note)
                            }
                        } else {
                            EmptyEditorPlaceholder(onCreate: createNote)
                        }
                    }
                }
                .arrangementViewStyle(.split)

                if showPoseHint {
                    DuoPoseBadge()
                        .transition(.opacity)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                                withAnimation(.easeOut(duration: 0.35)) {
                                    showPoseHint = false
                                }
                            }
                        }
                }
            }
            .searchable(text: $searchText, prompt: "Search notes")
            .toolbar {
                ToolbarItem {
                    Button(
                        selectedNote?.isPinned == true ? "Unpin" : "Pin",
                        systemImage: selectedNote?.isPinned == true ? "pin.slash" : "pin"
                    ) {
                        selectedNote?.isPinned.toggle()
                        selectedNote?.updatedAt = .now
                    }
                    .disabled(selectedNote == nil)
                }
                .visibilityPriority(.low)

                ToolbarItem(placement: .topBarPinnedTrailing) {
                    Button("New Note", systemImage: "square.and.pencil", action: createNote)
                }
                .visibilityPriority(.high)
            }
            .toolbarOverflowMenu {
                Button("Delete Note", systemImage: "trash", role: .destructive) {
                    if let note = selectedNote { delete(note) }
                }
                .disabled(selectedNote == nil)
            }
        }
    }

    private func header(compact: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            FolioBrandMark(compact: compact)
            Spacer()
            Text("\(notes.count) notes")
                .font(.caption.weight(.medium))
                .foregroundStyle(FolioTheme.inkSoft)
        }
        .padding(.horizontal, compact ? 20 : 16)
        .padding(.top, compact ? 8 : 12)
        .padding(.bottom, 6)
    }

    private func createNote() {
        let note = Note(accent: .moss)
        modelContext.insert(note)
        try? modelContext.save()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            selectedNoteID = note.id
            if horizontalSizeClass == .compact {
                navigationPath.append(note.id)
            }
        }
    }

    private func delete(_ note: Note) {
        if selectedNoteID == note.id {
            selectedNoteID = notes.first { $0.id != note.id }?.id
        }
        modelContext.delete(note)
        try? modelContext.save()
    }
}
