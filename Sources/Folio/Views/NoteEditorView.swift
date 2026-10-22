import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Bindable var note: Note
    var isCompact: Bool
    var onDelete: () -> Void

    @FocusState private var bodyFocused: Bool
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            accentStrip
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Title", text: $note.title, axis: .vertical)
                        .font(.system(isCompact ? .title2 : .largeTitle, design: .serif).weight(.semibold))
                        .foregroundStyle(FolioTheme.ink)
                        .textFieldStyle(.plain)
                        .onChange(of: note.title) { _, _ in touch() }

                    TextEditor(text: $note.body)
                        .font(.system(.body, design: .default))
                        .foregroundStyle(FolioTheme.ink)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: isCompact ? 280 : 420)
                        .focused($bodyFocused)
                        .onChange(of: note.body) { _, _ in touch() }

                    metadata
                }
                .padding(.horizontal, isCompact ? 20 : 28)
                .padding(.top, 18)
                .padding(.bottom, 40)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.clear)
        .toolbar {
            ToolbarItem {
                Button(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin") {
                    note.isPinned.toggle()
                    touch()
                }
            }
            .visibilityPriority(.low)

            ToolbarItem {
                Menu("Accent", systemImage: "paintpalette") {
                    ForEach(NoteAccent.allCases) { accent in
                        Button {
                            note.accent = accent
                            touch()
                        } label: {
                            Label(accent.label, systemImage: note.accent == accent ? "checkmark.circle.fill" : "circle")
                        }
                    }
                }
            }
            .visibilityPriority(.low)

            ToolbarItem {
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            }
            .visibilityPriority(.low)
        }
        .toolbarOverflowMenu {
            ShareLink(item: shareText) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                appeared = true
            }
            if note.body.isEmpty && note.title.isEmpty {
                bodyFocused = true
            }
        }
    }

    private var accentStrip: some View {
        HStack(spacing: 0) {
            FolioTheme.accentColor(note.accent)
                .frame(height: 3)
                .frame(maxWidth: .infinity)
                .opacity(0.95)
        }
        .animation(.easeInOut(duration: 0.25), value: note.accent)
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Updated \(note.updatedAt.formatted(date: .abbreviated, time: .shortened))")
            Text("Created \(note.createdAt.formatted(date: .abbreviated, time: .omitted))")
        }
        .font(.caption)
        .foregroundStyle(FolioTheme.inkSoft.opacity(0.8))
        .padding(.top, 8)
    }

    private var shareText: String {
        let title = note.displayTitle
        if note.body.isEmpty { return title }
        return "\(title)\n\n\(note.body)"
    }

    private func touch() {
        note.updatedAt = .now
    }
}

struct EmptyEditorPlaceholder: View {
    var onCreate: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            FolioBrandMark()
            Text("Open a note, or start a fresh page.")
                .font(.body)
                .foregroundStyle(FolioTheme.inkSoft)
                .multilineTextAlignment(.center)
            Button(action: onCreate) {
                Label("New Note", systemImage: "square.and.pencil")
                    .font(.headline)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(FolioTheme.moss, in: Capsule(style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
