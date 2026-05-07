import Foundation

// Mirrors D.activities in design-import/data.js.

struct Activity: Identifiable, Hashable {
    enum Kind: String, Codable { case cards, quiz, map, journal, districts }

    let id: String
    let title: String
    let subtitle: String
    let kind: Kind
    let count: Int?
}

struct DateCard: Identifiable, Hashable {
    enum Tint: String { case rose, sage, amber }

    let id: Int
    let title: String
    let detail: String
    let mood: String
    let kaomoji: String
    let tint: Tint
    let cost: String
}

struct QuizQuestion: Identifiable, Hashable {
    let id: Int
    let question: String
    let kitAnswer: String
    let michelAnswer: String

    var matched: Bool { kitAnswer == michelAnswer }
}
