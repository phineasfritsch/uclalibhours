import Foundation
import UIKit

// MARK: - StudySpaceService
// Local-first storage using UserDefaults + Documents directory for photos.
// Replace with a network backend for multi-user sharing.

final class StudySpaceService {
    static let shared = StudySpaceService()

    private let spacesKey = "studySpaces_v2"
    private let userIDKey = "anonymousUserID"
    private let submissionDatesKey = "submissionDates_v1"
    private let maxSubmissionsPerDay = 3

    private(set) var anonymousUserID: String

    private var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

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
        var spaces: [StudySpace]
        if let data = UserDefaults.standard.data(forKey: spacesKey),
           let decoded = try? JSONDecoder().decode([StudySpace].self, from: data) {
            spaces = decoded
        } else {
            spaces = []
        }

        // Ensure verified spaces are always present (insert any that are missing)
        let verifiedIDs = Set(spaces.filter(\.isVerified).map(\.id))
        let missing = Self.verifiedSeedData().filter { !verifiedIDs.contains($0.id) }
        if !missing.isEmpty {
            spaces.insert(contentsOf: missing, at: 0)
            saveSpaces(spaces)
        }

        // Seed community spaces on first launch (no community spaces yet)
        let communitySpaces = spaces.filter { !$0.isVerified }
        if communitySpaces.isEmpty && spaces.allSatisfy(\.isVerified) {
            let community = Self.communitySeedData()
            spaces.append(contentsOf: community)
            saveSpaces(spaces)
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
        recordSubmission()
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
        // Verified spaces cannot be deleted
        guard let space = spaces.first(where: { $0.id == id }), !space.isVerified else { return }
        // Delete associated photo files
        if let target = spaces.first(where: { $0.id == id }) {
            target.photoFileNames.forEach { deletePhoto(filename: $0) }
        }
        spaces.removeAll { $0.id == id }
        saveSpaces(spaces)
    }

    // MARK: - Photo Storage

    func savePhoto(imageData: Data) -> String? {
        guard let image = UIImage(data: imageData),
              let compressed = image.jpegData(compressionQuality: 0.65) else { return nil }
        let filename = UUID().uuidString + ".jpg"
        let url = documentsDir.appendingPathComponent(filename)
        do {
            try compressed.write(to: url)
            return filename
        } catch {
            return nil
        }
    }

    func loadPhoto(filename: String) -> UIImage? {
        let url = documentsDir.appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }

    func deletePhoto(filename: String) {
        let url = documentsDir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Rate Limiting

    /// Whether the current user can still submit a new space today.
    func canSubmitSpace() -> Bool {
        todaySubmissionCount() < maxSubmissionsPerDay
    }

    /// How many more spaces the user can submit today.
    func remainingSubmissions() -> Int {
        max(0, maxSubmissionsPerDay - todaySubmissionCount())
    }

    private func todaySubmissionCount() -> Int {
        loadSubmissionDates().filter { Calendar.current.isDateInToday($0) }.count
    }

    private func recordSubmission() {
        var dates = loadSubmissionDates()
        dates.append(Date())
        // Trim to last 7 days to keep storage small
        let cutoff = Date().addingTimeInterval(-7 * 86_400)
        dates = dates.filter { $0 > cutoff }
        if let data = try? JSONEncoder().encode(dates) {
            UserDefaults.standard.set(data, forKey: submissionDatesKey)
        }
    }

    private func loadSubmissionDates() -> [Date] {
        guard let data = UserDefaults.standard.data(forKey: submissionDatesKey),
              let dates = try? JSONDecoder().decode([Date].self, from: data) else { return [] }
        return dates
    }

    // MARK: - Verified Seed Data
    // Fixed IDs so verified spaces survive app re-installs when UserDefaults persists.

    static func verifiedSeedData() -> [StudySpace] {
        [
            StudySpace(
                id: "verified-powell-2nd-reading",
                name: "Powell 2nd Floor Reading Room",
                building: "Powell Library",
                floor: "2nd Floor",
                description: "Stunning Romanesque reading room with soaring ceilings and warm lighting. Perfect for deep focus sessions. Gets busy around midterms — arrive early for a prime seat near the windows.",
                tags: [.quiet, .naturalLight, .outlets, .accessible],
                reports: [],
                reviews: [],
                createdAt: Date(),
                createdByUserID: "verified",
                isVerified: true
            ),
            StudySpace(
                id: "verified-yrl-4th-grad",
                name: "YRL 4th Floor Graduate Reading Room",
                building: "Young Research Library",
                floor: "4th Floor",
                description: "Graduate students only. Exceptionally quiet with panoramic views of campus. Ample outlets and sprawling desks make this the best spot for marathon study sessions.",
                tags: [.quiet, .outlets, .naturalLight, .accessible],
                reports: [],
                reviews: [],
                createdAt: Date(),
                createdByUserID: "verified",
                isVerified: true
            ),
            StudySpace(
                id: "verified-yrl-2nd-quiet",
                name: "YRL 2nd Floor Quiet Zones",
                building: "Young Research Library",
                floor: "2nd Floor",
                description: "Designated silent study areas along the perimeter. Individual carrels with power strips. Open to all students — no grad card needed.",
                tags: [.quiet, .outlets, .computers],
                reports: [],
                reviews: [],
                createdAt: Date(),
                createdByUserID: "verified",
                isVerified: true
            ),
            StudySpace(
                id: "verified-biomedical-collab",
                name: "Biomedical Library Collaborative Hub",
                building: "Biomedical Library",
                floor: "1st Floor",
                description: "Open collaborative area near the entrance with large whiteboards and movable furniture. Ideal for group work and project planning. Expect moderate noise during peak hours.",
                tags: [.groupFriendly, .whiteboards, .outlets, .computers, .accessible],
                reports: [],
                reviews: [],
                createdAt: Date(),
                createdByUserID: "verified",
                isVerified: true
            ),
            StudySpace(
                id: "verified-arts-reading",
                name: "Arts Library Reading Room",
                building: "Arts Library",
                floor: "1st Floor",
                description: "Cozy reading room surrounded by art books and large west-facing windows. A genuine hidden gem — rarely crowded even during finals. Great natural light in the afternoons.",
                tags: [.quiet, .naturalLight, .outlets],
                reports: [],
                reviews: [],
                createdAt: Date(),
                createdByUserID: "verified",
                isVerified: true
            ),
            StudySpace(
                id: "verified-rosenfeld-main",
                name: "Rosenfeld Management Library",
                building: "Rosenfeld Management Library",
                floor: "Ground Floor",
                description: "Clean, modern space with good lighting and a calm atmosphere. Primarily used by Anderson students but open to all. Quiet relative to other libraries.",
                tags: [.quiet, .outlets, .computers, .accessible],
                reports: [],
                reviews: [],
                createdAt: Date(),
                createdByUserID: "verified",
                isVerified: true
            ),
        ]
    }

    // MARK: - Community Seed Data

    static func communitySeedData() -> [StudySpace] {
        [
            StudySpace(
                id: UUID().uuidString,
                name: "Music Library Listening Carrels",
                building: "Music Library",
                floor: "Ground Floor",
                description: "Private carrels with listening stations. Perfect for music students or anyone wanting complete isolation from the rest of campus.",
                tags: [.quiet, .reservable],
                reports: [],
                reviews: [],
                createdAt: Date(),
                createdByUserID: "seed"
            ),
        ]
    }
}
