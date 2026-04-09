import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

// MARK: - StudySpaceService (Firebase-backed)

final class StudySpaceService {
    static let shared = StudySpaceService()

    private let db = Firestore.firestore()
    private let storage = Storage.storage().reference()
    private let maxSubmissionsPerDay = 3

    // MARK: - Auth

    var anonymousUserID: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    /// Call once on app launch / before any write. Safe to call repeatedly.
    func ensureSignedIn() async throws {
        if Auth.auth().currentUser == nil {
            try await Auth.auth().signInAnonymously()
        }
    }

    // MARK: - Load Spaces

    func loadSpaces() async throws -> [StudySpace] {
        let snapshot = try await db.collection("studySpaces")
            .whereField("submissionStatus", isEqualTo: SubmissionStatus.approved.rawValue)
            .getDocuments()

        var spaces = snapshot.documents.compactMap { doc -> StudySpace? in
            try? doc.data(as: StudySpace.self)
        }

        // Verified spaces are seeded from the server on first write.
        // Locally, ensure they appear even before the server round-trip.
        let verifiedIDs = Set(spaces.filter(\.isVerified).map(\.id))
        let missing = Self.verifiedSeedData().filter { !verifiedIDs.contains($0.id) }
        if !missing.isEmpty {
            for space in missing {
                try? await addSpace(space)
            }
            spaces.insert(contentsOf: missing, at: 0)
        }

        return spaces
    }

    // MARK: - Write Space

    func addSpace(_ space: StudySpace) async throws {
        try db.collection("studySpaces")
            .document(space.id)
            .setData(from: space)
        try await recordSubmission()
    }

    func deleteSpace(id: String) async throws {
        // Verified spaces are protected by Firestore rules too, but guard here for UX
        let doc = try await db.collection("studySpaces").document(id).getDocument()
        guard let isVerified = doc.data()?["isVerified"] as? Bool, !isVerified else { return }
        try await db.collection("studySpaces").document(id).delete()
    }

    // MARK: - Reports (subcollection, append-only)

    func submitReport(_ report: SpaceReport, to spaceID: String) async throws {
        try db.collection("studySpaces")
            .document(spaceID)
            .collection("reports")
            .document(report.id)
            .setData(from: report)
    }

    func loadReports(for spaceID: String) async throws -> [SpaceReport] {
        let snapshot = try await db.collection("studySpaces")
            .document(spaceID)
            .collection("reports")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: SpaceReport.self) }
    }

    // MARK: - Reviews (userID is the document ID → one per user enforced by rules)

    func submitReview(_ review: SpaceReview, to spaceID: String) async throws {
        let uid = anonymousUserID
        guard !uid.isEmpty else { throw ServiceError.notSignedIn }
        try db.collection("studySpaces")
            .document(spaceID)
            .collection("reviews")
            .document(uid)          // UID as doc ID = one review per user at DB level
            .setData(from: review)
    }

    func loadReviews(for spaceID: String) async throws -> [SpaceReview] {
        let snapshot = try await db.collection("studySpaces")
            .document(spaceID)
            .collection("reviews")
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: SpaceReview.self) }
    }

    // MARK: - Photo Upload

    /// Compresses, uploads to Storage, returns the download URL string.
    func uploadPhoto(imageData: Data, userID: String) async throws -> String {
        guard let image = UIImage(data: imageData),
              let compressed = image.jpegData(compressionQuality: 0.65) else {
            throw ServiceError.invalidImage
        }
        let ref = storage.child("spacePhotos/\(userID)/\(UUID().uuidString).jpg")
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(compressed, metadata: meta)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    // MARK: - Rate Limiting (server-side via Firestore)

    func canSubmitSpace() async -> Bool {
        guard !anonymousUserID.isEmpty else { return false }
        do {
            let doc = try await db.collection("submissionLogs")
                .document(anonymousUserID)
                .getDocument()
            guard let data = doc.data(),
                  let timestamps = data["dates"] as? [Timestamp] else { return true }
            let todayCount = timestamps.filter {
                Calendar.current.isDateInToday($0.dateValue())
            }.count
            return todayCount < maxSubmissionsPerDay
        } catch {
            return true // Fail open — rules will block abusive writes server-side
        }
    }

    func remainingSubmissions() async -> Int {
        guard !anonymousUserID.isEmpty else { return 0 }
        do {
            let doc = try await db.collection("submissionLogs")
                .document(anonymousUserID)
                .getDocument()
            guard let data = doc.data(),
                  let timestamps = data["dates"] as? [Timestamp] else {
                return maxSubmissionsPerDay
            }
            let todayCount = timestamps.filter {
                Calendar.current.isDateInToday($0.dateValue())
            }.count
            return max(0, maxSubmissionsPerDay - todayCount)
        } catch {
            return maxSubmissionsPerDay
        }
    }

    private func recordSubmission() async throws {
        let ref = db.collection("submissionLogs").document(anonymousUserID)
        try await ref.setData([
            "dates": FieldValue.arrayUnion([Timestamp(date: Date())])
        ], merge: true)
    }

    // MARK: - Errors

    enum ServiceError: LocalizedError {
        case notSignedIn
        case invalidImage

        var errorDescription: String? {
            switch self {
            case .notSignedIn: return "Not signed in. Please restart the app."
            case .invalidImage: return "Could not process the selected image."
            }
        }
    }

    // MARK: - Verified Seed Data
    // These are written to Firestore once (their fixed IDs prevent duplication).
    // The Firestore security rules allow only the seeder UID to write isVerified: true.

    static func verifiedSeedData() -> [StudySpace] {
        [
            StudySpace(
                id: "verified-powell-2nd-reading",
                name: "Powell 2nd Floor Reading Room",
                building: "Powell Library",
                floor: "2nd Floor",
                description: "Stunning Romanesque reading room with soaring ceilings and warm lighting. Perfect for deep focus sessions. Gets busy around midterms — arrive early for a prime seat near the windows.",
                tags: [.quiet, .naturalLight, .outlets, .accessible],
                reports: [], reviews: [],
                createdAt: Date(), createdByUserID: "verified",
                isVerified: true, photoURLs: [], submissionStatus: .approved
            ),
            StudySpace(
                id: "verified-yrl-4th-grad",
                name: "YRL 4th Floor Graduate Reading Room",
                building: "Young Research Library",
                floor: "4th Floor",
                description: "Graduate students only. Exceptionally quiet with panoramic views of campus. Ample outlets and sprawling desks make this the best spot for marathon study sessions.",
                tags: [.quiet, .outlets, .naturalLight, .accessible],
                reports: [], reviews: [],
                createdAt: Date(), createdByUserID: "verified",
                isVerified: true, photoURLs: [], submissionStatus: .approved
            ),
            StudySpace(
                id: "verified-yrl-2nd-quiet",
                name: "YRL 2nd Floor Quiet Zones",
                building: "Young Research Library",
                floor: "2nd Floor",
                description: "Designated silent study areas along the perimeter. Individual carrels with power strips. Open to all students — no grad card needed.",
                tags: [.quiet, .outlets, .computers],
                reports: [], reviews: [],
                createdAt: Date(), createdByUserID: "verified",
                isVerified: true, photoURLs: [], submissionStatus: .approved
            ),
            StudySpace(
                id: "verified-biomedical-collab",
                name: "Biomedical Library Collaborative Hub",
                building: "Biomedical Library",
                floor: "1st Floor",
                description: "Open collaborative area near the entrance with large whiteboards and movable furniture. Ideal for group work and project planning. Expect moderate noise during peak hours.",
                tags: [.groupFriendly, .whiteboards, .outlets, .computers, .accessible],
                reports: [], reviews: [],
                createdAt: Date(), createdByUserID: "verified",
                isVerified: true, photoURLs: [], submissionStatus: .approved
            ),
            StudySpace(
                id: "verified-arts-reading",
                name: "Arts Library Reading Room",
                building: "Arts Library",
                floor: "1st Floor",
                description: "Cozy reading room surrounded by art books and large west-facing windows. A genuine hidden gem — rarely crowded even during finals. Great natural light in the afternoons.",
                tags: [.quiet, .naturalLight, .outlets],
                reports: [], reviews: [],
                createdAt: Date(), createdByUserID: "verified",
                isVerified: true, photoURLs: [], submissionStatus: .approved
            ),
            StudySpace(
                id: "verified-rosenfeld-main",
                name: "Rosenfeld Management Library",
                building: "Rosenfeld Management Library",
                floor: "Ground Floor",
                description: "Clean, modern space with good lighting and a calm atmosphere. Primarily used by Anderson students but open to all.",
                tags: [.quiet, .outlets, .computers, .accessible],
                reports: [], reviews: [],
                createdAt: Date(), createdByUserID: "verified",
                isVerified: true, photoURLs: [], submissionStatus: .approved
            ),
        ]
    }
}
