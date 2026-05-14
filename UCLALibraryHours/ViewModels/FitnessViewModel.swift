import Foundation
import Combine

@MainActor
final class FitnessViewModel: ObservableObject {
    @Published var counts: [FacilityCount] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    @Published var searchText = ""

    private var autoRefreshTimer: AnyCancellable?
    private var relativeTimerTick: AnyCancellable?

    // Display order for the three UCLA Recreation facilities returned by the account.
    private let facilityOrder: [Int] = [
        802,  // John Wooden Center - FITWELL
        803,  // Bruin Fitness Center - FITWELL
        804   // Kinross Rec Center - FITWELL
    ]

    struct FacilityGroup: Identifiable, Hashable {
        let facilityId: Int
        let facilityName: String
        let locations: [FacilityCount]
        var id: Int { facilityId }
    }

    init() {
        // Pull fresh counts every 2 minutes while the view is alive.
        autoRefreshTimer = Timer.publish(every: 120, tolerance: 15, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }

        // Tick once a minute so "Updated N min ago" stays current without a refetch.
        relativeTimerTick = Timer.publish(every: 60, tolerance: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

    // MARK: - Grouping & filtering

    var groupedFacilities: [FacilityGroup] {
        let groups = Dictionary(grouping: counts, by: { $0.facilityId })
        return facilityOrder.compactMap { fid -> FacilityGroup? in
            guard let locs = groups[fid], let first = locs.first else { return nil }

            let sorted = locs.sorted { $0.locationName < $1.locationName }
            let facilityName = first.displayFacilityName

            let visible: [FacilityCount]
            if searchText.isEmpty {
                visible = sorted
            } else {
                let nameMatches = facilityName.localizedCaseInsensitiveContains(searchText)
                let matching = sorted.filter {
                    $0.locationName.localizedCaseInsensitiveContains(searchText)
                }
                if nameMatches { visible = sorted }
                else if !matching.isEmpty { visible = matching }
                else { return nil }
            }

            return FacilityGroup(
                facilityId: fid,
                facilityName: facilityName,
                locations: visible
            )
        }
    }

    var totalOpenZones: Int { counts.filter { !$0.isClosed }.count }
    var totalZones: Int { counts.count }

    // MARK: - Load

    func loadCounts() async {
        if counts.isEmpty {
            await refresh()
        }
    }

    func refresh() async {
        if isLoading { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            counts = try await FitnessService.shared.fetchCounts()
            lastUpdated = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
