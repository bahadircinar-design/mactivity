import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var accentRaw: String

    init(
        title: String = "",
        body: String = "",
        isPinned: Bool = false,
        accent: NoteAccent = .ink
    ) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.createdAt = .now
        self.updatedAt = .now
        self.isPinned = isPinned
        self.accentRaw = accent.rawValue
    }

    var accent: NoteAccent {
        get { NoteAccent(rawValue: accentRaw) ?? .ink }
        set { accentRaw = newValue.rawValue }
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let firstLine = body
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return firstLine.isEmpty ? "Untitled" : firstLine
    }

    var preview: String {
        let lines = body
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let first = lines.first else { return "Empty note" }
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return lines.dropFirst().first ?? "Empty note"
        }
        return first
    }
}

enum NoteAccent: String, CaseIterable, Identifiable {
    case ink
    case moss
    case dusk
    case copper
    case sea

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ink: "Ink"
        case .moss: "Moss"
        case .dusk: "Dusk"
        case .copper: "Copper"
        case .sea: "Sea"
        }
    }
}
