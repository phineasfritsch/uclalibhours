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

    var filteredLibraries: [Library] {
        var result = libraries
        if showOpenOnly {
            result = result.filter { $0.openStatus.isAccessible }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
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
