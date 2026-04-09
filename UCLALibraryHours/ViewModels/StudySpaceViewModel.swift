import Foundation
import Combine

@MainActor
final class StudySpaceViewModel: ObservableObject {
    @Published var spaces: [StudySpace] = []
    @Published var searchText = ""
    @Published var selectedTags: Set<SpaceTag> = []

    var filteredSpaces: [StudySpace] {
        var result = spaces
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.building.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        if !selectedTags.isEmpty {
            result = result.filter { space in
                selectedTags.isSubset(of: Set(space.tags))
            }
        }
        return result
    }

    var userID: String { StudySpaceService.shared.anonymousUserID }

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
}
