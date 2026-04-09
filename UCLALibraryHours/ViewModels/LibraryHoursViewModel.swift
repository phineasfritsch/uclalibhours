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

    // MARK: - Display order for the 10 main branches

    private let mainLibraryOrder: [Int] = [
        4690,   // Arts Library
        2081,   // Biomedical Library
        4694,   // Law Library
        3280,   // Rosenfeld Management Library
        4696,   // Music Library
        2572,   // Powell Library
        1916,   // Young Research Library (YRL)
        4702,   // SEL/Boelter
        4703,   // SEL/Geology
        4707    // SRLF
    ]

    // MARK: - Hardcoded parent → children LID map
    //
    // The LibCal API returns ALL locations flat (no actual sub_locations nesting),
    // so we define the groupings manually here.
    //
    // East Asian Library (4693) is intentionally omitted — YRL IS the East Asian
    // Library and they display as a single entry.

    private let childrenOf: [Int: [Int]] = [
        4690: [20525],                    // Arts Library → Reference Desk
        2081: [2082, 24794, 3291],        // Biomedical → Grad Reading Room, Collab Hub, Equipment Lending
        4694: [4695],                     // Law → Reference Desk
        3280: [],                         // Rosenfeld → none
        4696: [22392],                    // Music → Research Help Desk
        2572: [4699, 20241, 2609, 2607],  // Powell → Night Powell, Help Desk, CLICC Lab, CLICC Classrooms
        1916: [2614, 2083, 20242],        // YRL → CLICC Equipment Lending, Special Collections, Help Desk
        4702: [4705],                     // SEL/Boelter → Equipment Lending (Boelter)
        4703: [4706],                     // SEL/Geology → Equipment Lending (Geo)
        4707: []                          // SRLF → none
    ]

    // MARK: - Restructured unfiltered list of the 10 branches
    //
    // Kept separate from groupedLibraries so openCount is always accurate
    // regardless of active search / open-only filters.

    private var restructuredLibraries: [Library] {
        // Flatten the API response into a single lid → Library lookup.
        // This handles both a fully-flat API and one that nests some subs already.
        var byLid: [Int: Library] = [:]
        for lib in libraries {
            byLid[lib.lid] = lib
            for sub in lib.subLocations {
                byLid[sub.lid] = sub
            }
        }

        // Drop East Asian Library — YRL represents both locations as one entry
        byLid.removeValue(forKey: 4693)

        // Re-parent each child into its main library, stripping redundant name parts.
        // Skips duplicates if the API already nested them.
        for (parentLid, childLids) in childrenOf {
            guard let parent = byLid[parentLid] else { continue }
            let existingSubs = Set(parent.subLocations.map { $0.lid })
            let newChildren = childLids
                .compactMap { byLid[$0] }
                .filter { !existingSubs.contains($0.lid) }
                .map { sub in
                    // Trim redundant parent references from the sub-location name
                    sub.withName(Self.simplifiedSubName(sub.name, parentName: parent.name))
                }
            guard !newChildren.isEmpty else { continue }
            byLid[parentLid] = parent.withSubLocations(parent.subLocations + newChildren)
        }

        // Rename YRL to something readable
        if let yrl = byLid[1916] {
            byLid[1916] = yrl.withName("Young Research Library (YRL)")
        }

        // Return exactly the 10 branches in the defined order
        return mainLibraryOrder.compactMap { byLid[$0] }
    }

    // MARK: - Filtered list used by the list view

    var groupedLibraries: [Library] {
        var list = restructuredLibraries

        // Open-only: keep if the branch itself or any sub-location is open
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

    // Always reflects the true open count across all 10 branches
    var openCount: Int { restructuredLibraries.filter { $0.openStatus.isAccessible }.count }
    var totalCount: Int { mainLibraryOrder.count }

    // MARK: - Sub-location name cleanup

    /// Removes redundant references to the parent library from a sub-location name.
    ///
    /// Examples:
    ///   "Arts Library Reference Desk"       (parent: "Arts Library")      → "Reference Desk"
    ///   "Equipment Lending (Biomedical Library)" (parent: "Biomedical Library") → "Equipment Lending"
    ///   "Equipment Lending (SEL/Geo)"       (parent: "SEL/Geology")       → "Equipment Lending"
    private static func simplifiedSubName(_ name: String, parentName: String) -> String {
        var result = name

        // 1. Strip leading parent-name prefix
        //    "Music Library Research Help Desk" → "Research Help Desk"
        let prefix = parentName + " "
        if result.lowercased().hasPrefix(prefix.lowercased()) {
            result = String(result.dropFirst(prefix.count))
        }

        // 2. Strip a trailing parenthetical that refers to the parent location
        //    "Equipment Lending (Biomedical Library)" → "Equipment Lending"
        //    "Equipment Lending (SEL/Geo)" → "Equipment Lending"
        //    Strategy: match if the parent name *contains* the paren content,
        //    covering both exact ("Biomedical Library") and abbreviated ("SEL/Geo") forms.
        if let openIdx = result.lastIndex(of: "("),
           let closeIdx = result.lastIndex(of: ")"),
           openIdx < closeIdx {
            let parenContent = result[result.index(after: openIdx)..<closeIdx]
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            if parentName.lowercased().contains(parenContent) {
                result = String(result[..<openIdx]).trimmingCharacters(in: .whitespaces)
            }
        }

        return result.trimmingCharacters(in: .whitespaces)
    }

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
