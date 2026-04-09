import Foundation

// MARK: - StudySpaceService
// Local-first storage using UserDefaults. Replace with a network backend for multi-user sharing.

final class StudySpaceService {
    static let shared = StudySpaceService()

    private let spacesKey = "studySpaces_v1"
    private let userIDKey = "anonymousUserID"

    private(set) var anonymousUserID: String

    private init() {
        if let existing = UserDefaults.standard.string(forKey: "anonymousUserID") {
            anonymousUserID = existing
        } else {
            let newID = UUID().uuidString
            UserDefaults.standard.set(newID, forKey: "anonymousUserID")
            anonymousUserID = newID
        }
    }

    // MARK: - Read

    func loadSpaces() -> [StudySpace] {
        guard let data = UserDefaults.standard.data(forKey: spacesKey),
              let spaces = try? JSONDecoder().decode([StudySpace].self, from: data) else {
            return Self.seedData()
        }
        return spaces
    }

    // MARK: - Write

    func saveSpaces(_ spaces: [StudySpace]) {
        if let data = try? JSONEncoder().encode(spaces) {
            UserDefaults.standard.set(data, forKey: spacesKey)
        }
    }

    func addSpace(_ space: StudySpace) {
        var spaces = loadSpaces()
        spaces.append(space)
        saveSpaces(spaces)
    }

    func submitReport(_ report: SpaceReport, to spaceID: String) {
        var spaces = loadSpaces()
        guard let idx = spaces.firstIndex(where: { $0.id == spaceID }) else { return }
        spaces[idx].reports.append(report)
        // Keep only last 50 reports per space
        if spaces[idx].reports.count > 50 {
            spaces[idx].reports = Array(spaces[idx].reports.sorted { $0.timestamp > $1.timestamp }.prefix(50))
        }
        saveSpaces(spaces)
    }

    func submitReview(_ review: SpaceReview, to spaceID: String) {
        var spaces = loadSpaces()
        guard let idx = spaces.firstIndex(where: { $0.id == spaceID }) else { return }
        // One review per user per space
        spaces[idx].reviews.removeAll { $0.userID == review.userID }
        spaces[idx].reviews.append(review)
        saveSpaces(spaces)
    }

    func deleteSpace(id: String) {
        var spaces = loadSpaces()
        spaces.removeAll { $0.id == id }
        saveSpaces(spaces)
    }

    // MARK: - Seed Data

    static func seedData() -> [StudySpace] {
        [
            StudySpace(
                id: UUID().uuidString,
                name: "Powell 2nd Floor Reading Room",
                building: "Powell Library",
                floor: "2nd Floor",
                description: "Beautiful Romanesque reading room with high ceilings and natural light. Great for focused individual work. Gets busier around midterms.",
                tags: [.quiet, .naturalLight, .outlets, .accessible],
                reports: [],
                reviews: [],
                createdAt: Date(),
                createdByUserID: "seed"
            ),
            StudySpace(
                id: UUID().uuidString,
                name: "YRL 4th Floor Graduate Reading Room",
                building: "Young Research Library",
                floor: "4th Floor",
                description: "Restricted to graduate students. Very quiet, ample seating, plenty of outlets. Rarely crowded.",
                tags: [.quiet, .outlets, .naturalLight],
                reports: [],
                reviews: [],
                createdAt: Date(),
                createdByUserID: "seed"
            ),
            StudySpace(
                id: UUID().uuidString,
                name: "Biomedical Library Collaborative Area",
                building: "Biomedical Library",
                floor: "1st Floor",
                description: "Open collaborative space near the entrance. Good for group work, whiteboards available. Can be noisy during peak hours.",
                tags: [.groupFriendly, .whiteboards, .outlets, .computers],
                reports: [],
                reviews: [],
                createdAt: Date(),
                createdByUserID: "seed"
            ),
            StudySpace(
                id: UUID().uuidString,
                name: "Arts Library Study Lounge",
                building: "Arts Library",
                floor: "1st Floor",
                description: "Cozy lounge with art books and natural light from large windows. A hidden gem for humanities students.",
                tags: [.quiet, .naturalLight, .outlets],
                reports: [],
                reviews: [],
                createdAt: Date(),
                createdByUserID: "seed"
            ),
            StudySpace(
                id: UUID().uuidString,
                name: "Music Library Listening Carrels",
                building: "Music Library",
                floor: "Ground Floor",
                description: "Private carrels with listening stations. Perfect for music students or anyone wanting complete isolation.",
                tags: [.quiet, .reservable],
                reports: [],
                reviews: [],
                createdAt: Date(),
                createdByUserID: "seed"
            ),
        ]
    }
}
