import SwiftUI
import SwiftData
import UIKit

struct NoteEditorView: View {
    @Bindable var note: Note
    var isCompact: Bool
    var onDelete: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            accentStrip
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("题 · Title", text: $note.title, axis: .vertical)
                        .font(FolioFont.brushDisplay(isCompact ? 30 : 38, relativeTo: isCompact ? .title2 : .largeTitle))
                        .foregroundStyle(FolioTheme.ink)
                        .textFieldStyle(.plain)
                        .onChange(of: note.title) { _, _ in touch() }

                    PaperInkEditor(
                        text: $note.body,
                        font: UIFont(name: FolioFont.hand, size: isCompact ? 26 : 30)
                            ?? .systemFont(ofSize: isCompact ? 26 : 30),
                        textColor: UIColor(FolioTheme.ink),
                        minHeight: isCompact ? 280 : 420
                    )
                    .frame(minHeight: isCompact ? 280 : 420)
                    .onChange(of: note.body) { _, _ in touch() }

                    Text("Write with Apple Pencil — the sheet answers with paper sound.")
                        .font(FolioFont.handwriting(16, relativeTo: .caption))
                        .foregroundStyle(FolioTheme.inkSoft.opacity(0.85))

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
            PencilPaperSound.shared.prepare()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                appeared = true
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
        .font(FolioFont.handwriting(14, relativeTo: .caption))
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
            Text("Open a note, or start a fresh page on the grid.")
                .font(FolioFont.handwriting(22, relativeTo: .body))
                .foregroundStyle(FolioTheme.inkSoft)
                .multilineTextAlignment(.center)
            Button(action: onCreate) {
                Label("New Note", systemImage: "square.and.pencil")
                    .font(FolioFont.handwriting(22, relativeTo: .headline))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(FolioTheme.sealRed, in: Capsule(style: .continuous))
                    .foregroundStyle(FolioTheme.paper)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
