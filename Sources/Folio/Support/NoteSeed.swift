import Foundation
import SwiftData

enum NoteSeed {
    static func insertIfNeeded(into context: ModelContext) {
        var descriptor = FetchDescriptor<Note>()
        descriptor.fetchLimit = 1
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        let samples: [(String, String, NoteAccent, Bool)] = [
            (
                "宣纸上的 Folio",
                """
                Folio opens like a sheet of Chinese practice paper — warm rice fiber, faint 米字格, vermilion guides.

                Closed on Duo’s outer display, capture a line. Opened, browse and write across the fold. With Apple Pencil, each stroke answers with a soft pencil-on-paper sound.

                写吧。The grid is waiting.
                """,
                .moss,
                true
            ),
            (
                "Tent-mode grocery list",
                """
                - Oat milk
                - Soft tortillas
                - Limes
                - Dark chocolate
                - Sparkling water

                Prop Duo like a laptop: list above the fold, editor below while you shop.
                """,
                .sea,
                false
            ),
            (
                "Walk notes",
                """
                The light on the water was the color of cold steel.

                Remember: shorter sentences land harder. Leave room between the grid lines — white space is a feature.
                """,
                .dusk,
                false
            )
        ]

        for (title, body, accent, pinned) in samples {
            let note = Note(title: title, body: body, isPinned: pinned, accent: accent)
            context.insert(note)
        }
        try? context.save()
    }
}
