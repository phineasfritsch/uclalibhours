import Foundation
import Combine

@MainActor
final class StudySpaceViewModel: ObservableObject {
    @Published var spaces: [StudySpace] = []          // all spaces (verified + community)
    @Published var searchText = ""
    @Published var selectedTags: Set<SpaceTag> = []

    var verifiedSpaces: [StudySpace] { spaces.filter(\.isVerified) }
    var communitySpaces: [StudySpace] { spaces.filter { !$0.isVerified } }

    var filteredVerifiedSpaces: [StudySpace] {
        filter(verifiedSpaces)
    }

    var filteredCommunitySpaces: [StudySpace] {
        filter(communitySpaces)
    }

    /// Legacy accessor — returns all filtered spaces (used by shared SpaceCard/NavigationDestination)
    var filteredSpaces: [StudySpace] {
        filter(spaces)
    }

    var userID: String { StudySpaceService.shared.anonymousUserID }

    var canSubmitSpace: Bool { StudySpaceService.shared.canSubmitSpace() }
    var remainingSubmissions: Int { StudySpaceService.shared.remainingSubmissions() }

    // MARK: - Load

    func loadSpaces() {
        spaces = StudySpaceService.shared.loadSpaces()
    }

    // MARK: - Actions

    func addSpace(_ space: StudySpace) {
        StudySpaceService.shared.addSpace(space)
        spaces.append(space)
    }

    func submitReport(_ report: SpaceReport, to spaceID: String) {
        StudySpaceService.shared.submitReport(report, to: spaceID)
        if let idx = spaces.firstIndex(where: { $0.id == spaceID }) {
            spaces[idx].reports.append(report)
        }
    }

    func submitReview(_ review: SpaceReview, to spaceID: String) {
        StudySpaceService.shared.submitReview(review, to: spaceID)
        if let idx = spaces.firstIndex(where: { $0.id == spaceID }) {
            spaces[idx].reviews.removeAll { $0.userID == review.userID }
            spaces[idx].reviews.append(review)
        }
    }

    func deleteSpace(id: String) {
        StudySpaceService.shared.deleteSpace(id: id)
        spaces.removeAll { $0.id == id }
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
