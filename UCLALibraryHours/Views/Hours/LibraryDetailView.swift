import SwiftUI

struct LibraryDetailView: View {
    let library: Library
    @Environment(\.colorScheme) var colorScheme

    private let dayOrder = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Status hero card
                statusCard
                    .padding(.horizontal)

                // Current week hours
                hoursSection(
                    title: "This Week",
                    days: library.sortedCurrentWeek
                )

                // Next week hours (if available)
                if !library.sortedNextWeek.isEmpty {
                    hoursSection(
                        title: "Next Week",
                        days: library.sortedNextWeek
                    )
                }

                // Sub-locations
                if !library.subLocations.isEmpty {
                    subLocationsSection
                }

                Spacer(minLength: 32)
            }
            .padding(.top, 16)
        }
        .navigationTitle(library.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if let urlStr = library.allWeekHours.first.flatMap({ _ in
                "https://calendar.library.ucla.edu/hours"
            }), let url = URL(string: urlStr) {
                ToolbarItem(placement: .topBarTrailing) {
                    Link(destination: url) {
                        Image(systemName: "safari")
                    }
                }
            }
        }
    }

    // MARK: - Status Hero

    private var statusCard: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    StatusBadge(status: library.openStatus, size: .large)
                }

                Text(library.statusText)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                Text("Today, \(Date().formatted(.dateTime.weekday(.wide).month().day()))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status indicator circle
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundStyle(statusColor)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 3)
        }
    }

    private var statusColor: Color {
        switch library.openStatus {
        case .open: return .green
        case .open24: return .uclaBlue
        case .closed: return .red
        case .byAppointment: return .orange
        case .unknown: return .secondary
        }
    }

    private var statusIcon: String {
        switch library.openStatus {
        case .open: return "checkmark.circle.fill"
        case .open24: return "clock.fill"
        case .closed: return "xmark.circle.fill"
        case .byAppointment: return "calendar.badge.clock"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    // MARK: - Hours Section

    private func hoursSection(title: String, days: [(dayKey: String, hours: DayHoursData)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.bold())
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.element.dayKey) { idx, pair in
                    DayHoursRow(
                        dayKey: pair.dayKey,
                        hours: pair.hours,
                        isToday: isToday(dayKey: pair.dayKey)
                    )

                    if idx < days.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
            }
            .padding(.horizontal)
        }
    }

    private func isToday(dayKey: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let todayName = formatter.string(from: Date())
        return dayKey.hasPrefix(todayName)
    }

    // MARK: - Sub-Locations

    private var subLocationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Areas & Services")
                .font(.title3.bold())
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(Array(library.subLocations.enumerated()), id: \.element.id) { idx, sub in
                    SubLocationRow(library: sub)

                    if idx < library.subLocations.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Day Hours Row

struct DayHoursRow: View {
    let dayKey: String
    let hours: DayHoursData
    let isToday: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(shortDayName)
                    .font(isToday ? .subheadline.bold() : .subheadline)
                    .foregroundStyle(isToday ? .uclaBlue : .primary)

                if isToday {
                    Text("Today")
                        .font(.caption2)
                        .foregroundStyle(.uclaBlue)
                }
            }
            .frame(width: 72, alignment: .leading)

            Spacer()

            hoursLabel
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isToday ? Color.uclaBlue.opacity(0.05) : Color.clear)
    }

    private var shortDayName: String {
        // "Monday Apr 7" -> "Monday"
        dayKey.components(separatedBy: " ").first ?? dayKey
    }

    private var hoursLabel: some View {
        Group {
            switch hours.times.status {
            case "24hours":
                Text("24 Hours")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            case "closed":
                Text("Closed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case "open":
                Text(hours.rendered.strippingHTML)
                    .font(.subheadline)
                    .foregroundStyle(isToday ? .primary : .secondary)
            case "ByApp":
                Text("By Appointment")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            default:
                Text(hours.rendered.strippingHTML)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Sub-location Row

struct SubLocationRow: View {
    let library: Library

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(library.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Text(library.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusBadge(status: library.openStatus, size: .small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
