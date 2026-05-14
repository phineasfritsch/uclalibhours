import SwiftUI

struct FitnessView: View {
    @EnvironmentObject var vm: FitnessViewModel

    var body: some View {
        NavigationStack {
            Group {
                if vm.counts.isEmpty && vm.isLoading {
                    loadingView
                } else if vm.counts.isEmpty && vm.errorMessage != nil {
                    errorView
                } else {
                    facilityList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { titleView }
            }
            .searchable(text: $vm.searchText, prompt: "Search facilities or zones")
            .refreshable { await vm.refresh() }
        }
        .task { await vm.loadCounts() }
    }

    // MARK: - Title

    private var titleView: some View {
        VStack(spacing: 2) {
            Text("UCLA Gym Capacity")
                .font(.headline)
                .foregroundStyle(.primary)
            Text(subtitleText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var subtitleText: String {
        if let updated = vm.lastUpdated {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Live • Updated \(formatter.localizedString(for: updated, relativeTo: Date()))"
        }
        return "Live counts"
    }

    // MARK: - List

    private var facilityList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {

                if !vm.counts.isEmpty {
                    statusBanner
                        .padding(.horizontal)
                        .padding(.top, 4)
                }

                ForEach(vm.groupedFacilities) { group in
                    FacilityCard(group: group)
                        .padding(.horizontal)
                }

                Text("Live counts via Connect2Concepts")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 24)
                    .padding(.top, 4)
            }
            .padding(.top, 8)
        }
        .overlay {
            if vm.isLoading && !vm.counts.isEmpty {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8)
                        Text("Refreshing…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Status banner

    private var statusBanner: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(vm.totalOpenZones > 0 ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
            Text("\(vm.totalOpenZones) of \(vm.totalZones) zones open now")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Loading / Error

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.3)
            Text("Loading live counts…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Couldn't Load Counts")
                .font(.title3.bold())
            if let error = vm.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Button("Try Again") {
                Task { await vm.refresh() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.uclaBlue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Facility Card

struct FacilityCard: View {
    let group: FitnessViewModel.FacilityGroup
    @Environment(\.colorScheme) var colorScheme
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ──────────────────────────────────────────────────
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.facilityName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Text(summaryText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .frame(width: 28, height: 28)
                        .background(Color(.systemGray5), in: Circle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            // ── Zones ──────────────────────────────────────────────────
            if isExpanded && !group.locations.isEmpty {
                Divider().padding(.horizontal, 16)

                ForEach(Array(group.locations.enumerated()), id: \.element.id) { idx, location in
                    LocationRow(location: location)
                    if idx < group.locations.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }

                Spacer(minLength: 6)
            }
        }
        .background(colorScheme == .dark ? Color(.systemGray6) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 2)
    }

    private var summaryText: String {
        let openCount = group.locations.filter { !$0.isClosed }.count
        let total = group.locations.count
        return "\(openCount) of \(total) zones open"
    }
}

// MARK: - Location Row

struct LocationRow: View {
    let location: FacilityCount

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(location.locationName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("\(location.lastCount) / \(location.totalCapacity) people")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(location.fillPercentDisplay)%")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(location.capacityLevel.tintColor)
                    Text(location.capacityLevel.displayText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(location.capacityLevel.tintColor, in: Capsule())
                }
            }

            CapacityBar(percent: location.fillPercent, color: location.capacityLevel.tintColor)

            if let updated = location.lastUpdatedDate {
                Text("Updated \(updated, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Capacity Bar

struct CapacityBar: View {
    let percent: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: max(0, min(1, percent / 100)) * proxy.size.width)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - CapacityLevel → Color bridge (kept out of the Model layer)

extension CapacityLevel {
    var tintColor: Color {
        switch self {
        case .open:   return .green
        case .busy:   return .orange
        case .full:   return Color(red: 0.929, green: 0.110, blue: 0.141)  // #ed1c24
        case .closed: return Color(.systemGray3)
        }
    }
}
