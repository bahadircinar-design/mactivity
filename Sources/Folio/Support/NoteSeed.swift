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
                "Welcome to Folio",
                """
                Folio is built for iPhone Duo.

                Closed, capture a thought on the outer display. Opened, browse and write side by side. Partially folded, the list and editor share the fold evenly — nothing stretches across the crease.

                Tap New Note (it stays visible longest when the bar gets tight) and start writing.
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

                Prop Duo like a laptop: list above the fold, editor below for quick checks while you shop.
                """,
                .sea,
                false
            ),
            (
                "Walk notes",
                """
                The light on the water was the color of cold steel.

                Remember: shorter sentences land harder. Leave room for the fold — white space is a feature.
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
