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

    // MARK: - Ordered main-library LIDs (user-defined display order)
    //
    //  4690  Arts Library
    //  2081  Biomedical Library
    //  4694  Law Library
    //  3280  Rosenfeld Management Library
    //  4696  Music Library
    //  2572  Powell Library
    //  1916  YRL / Research Library (Charles E. Young)  ← EAS merged in
    //  4702  SEL/Boelter
    //  4703  SEL/Geology                                ← promoted to top-level
    //  4707  SRLF
    private let mainLibraryOrder: [Int] = [
        4690, 2081, 4694, 3280, 4696, 2572, 1916, 4702, 4703, 4707
    ]

    // MARK: - Restructured, unfiltered list of the 10 branches
    //
    // Separated from `groupedLibraries` so that openCount/totalCount are
    // always accurate regardless of active search or open-only filters.

    private var restructuredLibraries: [Library] {
        var byLid: [Int: Library] = Dictionary(
            uniqueKeysWithValues: libraries.map { ($0.lid, $0) }
        )

        // 1. Move East Asian Library (4693) under YRL (1916)
        if let eas = byLid[4693], let yrl = byLid[1916] {
            byLid[1916] = yrl.withAdditionalSubLocation(eas)
            byLid.removeValue(forKey: 4693)
        }

        // 2. Promote SEL/Geology (4703) out of SEL/Boelter's sub-locations
        //    and give it Equipment Lending SEL/Geo (4706) as its own sub.
        if let boelter = byLid[4702] {
            var boelterSubs = boelter.subLocations

            if let geoIdx = boelterSubs.firstIndex(where: { $0.lid == 4703 }) {
                var geology = boelterSubs.remove(at: geoIdx)

                if let equipIdx = boelterSubs.firstIndex(where: { $0.lid == 4706 }) {
                    geology = geology.withAdditionalSubLocation(boelterSubs.remove(at: equipIdx))
                }

                byLid[4702] = boelter.withSubLocations(boelterSubs)
                byLid[4703] = geology
            }
        }

        // 3. Return exactly the 10 branches in order, ignoring everything else
        return mainLibraryOrder.compactMap { byLid[$0] }
    }

    // MARK: - Filtered list used by the list view

    var groupedLibraries: [Library] {
        var list = restructuredLibraries

        // Open-only: keep branch if it or any sub-location is open
        if showOpenOnly {
            list = list.filter {
                $0.openStatus.isAccessible ||
                $0.subLocations.contains { $0.openStatus.isAccessible }
            }
        }

        // Search: match branch name or any sub-location name
        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.subLocations.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
        }

        return list
    }

    // Always reflects the true count across all 10 branches, filter-independent
    var openCount: Int { restructuredLibraries.filter { $0.openStatus.isAccessible }.count }
    var totalCount: Int { mainLibraryOrder.count }

    // MARK: - Load

    func loadHours() async {
        if let cached = LibraryHoursService.shared.loadCachedHours(), !cached.isEmpty {
            libraries = cached
        }
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
