import SwiftUI
import SwiftData

#Preview("Compact list") {
    ContentView()
        .modelContainer(previewContainer)
}

#Preview("Editor") {
    NavigationStack {
        NoteEditorView(
            note: Note(
                title: "Fold light",
                body: "Keep each pane on one side of the crease.",
                isPinned: true,
                accent: .sea
            ),
            isCompact: false,
            onDelete: {}
        )
    }
    .modelContainer(previewContainer)
}

@MainActor
private let previewContainer: ModelContainer = {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Note.self, configurations: configuration)
    NoteSeed.insertIfNeeded(into: container.mainContext)
    return container
}()
