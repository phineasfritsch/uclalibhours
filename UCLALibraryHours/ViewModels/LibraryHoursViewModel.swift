import Foundation
import Combine

@MainActor
final class LibraryHoursViewModel: ObservableObject {
    @Published var libraries: [Library] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    @Published var searchText = ""
    @Published var showOpenOnly = false

    /// Libraries organised into the 10 main branches, with East Asian Library
    /// moved under YRL (Research Library, Charles E. Young, lid 1916).
    var groupedLibraries: [Library] {
        var list = libraries

        // East Asian Library (lid 4693) is top-level in the API but belongs under YRL
        if let easIdx = list.firstIndex(where: { $0.lid == 4693 }) {
            let eas = list.remove(at: easIdx)
            if let yrlIdx = list.firstIndex(where: { $0.lid == 1916 }) {
                list[yrlIdx] = list[yrlIdx].withAdditionalSubLocation(eas)
            }
        }

        // Open-only filter: keep if the branch itself OR any sub-location is open
        if showOpenOnly {
            list = list.filter {
                $0.openStatus.isAccessible ||
                $0.subLocations.contains { $0.openStatus.isAccessible }
            }
        }

        // Search: match branch name OR any sub-location name
        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.subLocations.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
        }

        return list
    }

    var openCount: Int { libraries.filter { $0.openStatus.isAccessible }.count }
    var totalCount: Int { libraries.count }

    // MARK: - Load

    func loadHours() async {
        // Show cached data immediately
        if let cached = LibraryHoursService.shared.loadCachedHours(), !cached.isEmpty {
            libraries = cached
        }

        // Fetch fresh if stale or empty
        if libraries.isEmpty || LibraryHoursService.shared.cachedDataIsStale() {
            await refresh()
        }
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            libraries = try await LibraryHoursService.shared.fetchAndCacheHours()
            lastUpdated = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
