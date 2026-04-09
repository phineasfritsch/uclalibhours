import Foundation
import Combine

@MainActor
final class StudySpaceViewModel: ObservableObject {
    @Published var spaces: [StudySpace] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedTags: Set<SpaceTag> = []
    @Published var canSubmit = true
    @Published var remainingSubmissions = 3

    var verifiedSpaces: [StudySpace] { spaces.filter(\.isVerified) }
    var communitySpaces: [StudySpace] { spaces.filter { !$0.isVerified } }

    var filteredVerifiedSpaces: [StudySpace] { filter(verifiedSpaces) }
    var filteredCommunitySpaces: [StudySpace] { filter(communitySpaces) }

    var userID: String { StudySpaceService.shared.anonymousUserID }

    // MARK: - Load

    func loadSpaces() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                try await StudySpaceService.shared.ensureSignedIn()
                spaces = try await StudySpaceService.shared.loadSpaces()
                await refreshSubmissionStatus()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func refreshSubmissionStatus() async {
        canSubmit = await StudySpaceService.shared.canSubmitSpace()
        remainingSubmissions = await StudySpaceService.shared.remainingSubmissions()
    }

    // MARK: - Actions

    func addSpace(_ space: StudySpace) {
        Task {
            do {
                try await StudySpaceService.shared.addSpace(space)
                spaces.append(space)
                await refreshSubmissionStatus()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func submitReport(_ report: SpaceReport, to spaceID: String) {
        Task {
            do {
                try await StudySpaceService.shared.submitReport(report, to: spaceID)
                if let idx = spaces.firstIndex(where: { $0.id == spaceID }) {
                    spaces[idx].reports.append(report)
                }
                // Reload subcollection to get server-side ordering
                let updated = try await StudySpaceService.shared.loadReports(for: spaceID)
                if let idx = spaces.firstIndex(where: { $0.id == spaceID }) {
                    spaces[idx].reports = updated
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func submitReview(_ review: SpaceReview, to spaceID: String) {
        Task {
            do {
                try await StudySpaceService.shared.submitReview(review, to: spaceID)
                // Reload subcollection so the @DocumentID (userID as doc ID) is set correctly
                let updated = try await StudySpaceService.shared.loadReviews(for: spaceID)
                if let idx = spaces.firstIndex(where: { $0.id == spaceID }) {
                    spaces[idx].reviews = updated
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteSpace(id: String) {
        Task {
            do {
                try await StudySpaceService.shared.deleteSpace(id: id)
                spaces.removeAll { $0.id == id }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Private

    private func filter(_ source: [StudySpace]) -> [StudySpace] {
        var result = source
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.building.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        if !selectedTags.isEmpty {
            result = result.filter { selectedTags.isSubset(of: Set($0.tags)) }
        }
        return result
    }
}
