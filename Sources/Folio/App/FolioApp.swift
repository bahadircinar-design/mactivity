import SwiftUI
import SwiftData

@main
struct FolioApp: App {
    init() {
        PencilPaperSound.shared.prepare()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Note.self)
    }
}
