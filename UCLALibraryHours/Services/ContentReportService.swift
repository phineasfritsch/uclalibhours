import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Report Models

enum ReportedContentType: String, Codable {
    case space
    case review
    case user
}

enum ReportReason: String, Codable, CaseIterable, Identifiable {
    case spam
    case harassment
    case hateSpeech = "hate_speech"
    case sexualContent = "sexual_content"
    case violence
    case selfHarm = "self_harm"
    case personalInfo = "personal_info"
    case misinformation
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spam: return "Spam or scam"
        case .harassment: return "Harassment or bullying"
        case .hateSpeech: return "Hate speech or symbols"
        case .sexualContent: return "Sexual or inappropriate content"
        case .violence: return "Violence or threats"
        case .selfHarm: return "Self-harm or suicide"
        case .personalInfo: return "Personal info or doxxing"
        case .misinformation: return "False or misleading"
        case .other: return "Something else"
        }
    }
}

struct ContentReport: Codable, Identifiable {
    @DocumentID var id: String?
    let reporterUserID: String
    let contentType: ReportedContentType
    let contentID: String           // space ID, review doc ID, or reported user UID
    let parentSpaceID: String?      // set when reporting a review under a space
    let reportedUserID: String?     // author of the reported content, if known
    let reason: ReportReason
    let note: String                // optional free-text note from reporter (moderated)
    let timestamp: Date
    var status: String              // "pending" | "actioned" | "dismissed"
}

// MARK: - ContentReportService

final class ContentReportService {
    static let shared = ContentReportService()
    private let db = Firestore.firestore()
    private let maxReportsPerDay = 20    // generous, prevents spam-reporting abuse

    // MARK: - Submission

    func submitReport(
        contentType: ReportedContentType,
        contentID: String,
        parentSpaceID: String? = nil,
        reportedUserID: String? = nil,
        reason: ReportReason,
        note: String
    ) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw StudySpaceService.ServiceError.notSignedIn
        }

        // Moderate the user-typed note too.
        let noteResult = ContentModerator.moderate(note, config: .reviewBody)
        guard noteResult.allowed else {
            throw StudySpaceService.ServiceError.contentRejected(noteResult.userFacingMessage)
        }

        guard await canSubmitReport(uid: uid) else {
            throw StudySpaceService.ServiceError.contentRejected("You've sent many reports today. Please try again tomorrow.")
        }

        let report = ContentReport(
            id: nil,
            reporterUserID: uid,
            contentType: contentType,
            contentID: contentID,
            parentSpaceID: parentSpaceID,
            reportedUserID: reportedUserID,
            reason: reason,
            note: noteResult.sanitizedText,
            timestamp: Date(),
            status: "pending"
        )

        let docRef = db.collection("contentReports").document()
        try docRef.setData(from: report)
        try await recordReport(uid: uid)
    }

    // MARK: - Rate limiting

    private func canSubmitReport(uid: String) async -> Bool {
        do {
            let doc = try await db.collection("submissionLogs").document(uid).getDocument()
            guard let stamps = doc.data()?["reportDates"] as? [Timestamp] else { return true }
            let today = stamps.filter { Calendar.current.isDateInToday($0.dateValue()) }.count
            return today < maxReportsPerDay
        } catch {
            return true // fail open — better that the report goes through than is silently dropped
        }
    }

    private func recordReport(uid: String) async throws {
        let ref = db.collection("submissionLogs").document(uid)
        try await ref.setData(
            ["reportDates": FieldValue.arrayUnion([Timestamp(date: Date())])],
            merge: true
        )
    }
}
