import Foundation

// MARK: - LibCal API Response

struct HoursAPIResponse: Codable {
    let locations: [LibraryLocationResponse]
}

struct LibraryLocationResponse: Codable {
    let lid: Int
    let name: String
    let desc: String?
    let url: String?
    let color: String?
    let weeks: [[String: DayHoursData]]
    let subLocations: [LibraryLocationResponse]?

    enum CodingKeys: String, CodingKey {
        case lid, name, desc, url, color, weeks
        case subLocations = "sub_locations"
    }
}

struct DayHoursData: Codable {
    let times: DayTimesData
    let rendered: String
}

struct DayTimesData: Codable {
    let status: String // "open", "closed", "24hours", "ByApp", "text"
    let hours: [HourRangeData]?
    let note: String?
}

struct HourRangeData: Codable {
    let from: String
    let to: String
}

// MARK: - App Models

struct Library: Identifiable, Hashable {
    let lid: Int
    let name: String
    let color: String
    let allWeekHours: [[String: DayHoursData]]
    let subLocations: [Library]

    var id: Int { lid }

    var currentWeekHours: [String: DayHoursData] {
        allWeekHours.first ?? [:]
    }

    var todayDayName: String {
        DateFormatter().apply {
            $0.dateFormat = "EEEE"
        }.string(from: Date())
    }

    var todayHours: DayHoursData? {
        currentWeekHours.first { $0.key.hasPrefix(todayDayName) }?.value
    }

    var isOpenNow: Bool {
        guard let today = todayHours else { return false }
        switch today.times.status {
        case "24hours": return true
        case "open":
            return today.times.hours?.contains { isNowInRange(from: $0.from, to: $0.to) } ?? false
        default: return false
        }
    }

    var statusText: String {
        guard let today = todayHours else { return "Hours unavailable" }
        switch today.times.status {
        case "24hours": return "Open 24 hours"
        case "closed": return "Closed today"
        case "open": return today.rendered.strippingHTML
        case "ByApp": return "By appointment"
        case "text": return (today.times.note ?? today.rendered).strippingHTML
        default: return today.rendered.strippingHTML
        }
    }

    var openStatus: OpenStatus {
        guard let today = todayHours else { return .unknown }
        switch today.times.status {
        case "24hours": return .open24
        case "closed": return .closed
        case "open": return isOpenNow ? .open : .closed
        case "ByApp": return .byAppointment
        default: return .unknown
        }
    }

    var sortedCurrentWeek: [(dayKey: String, hours: DayHoursData)] {
        let order = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return currentWeekHours
            .sorted { a, b in
                let ai = order.firstIndex { a.key.hasPrefix($0) } ?? 99
                let bi = order.firstIndex { b.key.hasPrefix($0) } ?? 99
                return ai < bi
            }
            .map { (dayKey: $0.key, hours: $0.value) }
    }

    var sortedNextWeek: [(dayKey: String, hours: DayHoursData)] {
        guard allWeekHours.count > 1 else { return [] }
        let order = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return allWeekHours[1]
            .sorted { a, b in
                let ai = order.firstIndex { a.key.hasPrefix($0) } ?? 99
                let bi = order.firstIndex { b.key.hasPrefix($0) } ?? 99
                return ai < bi
            }
            .map { (dayKey: $0.key, hours: $0.value) }
    }

    private func isNowInRange(from: String, to: String) -> Bool {
        guard let fromDate = parseLibCalTime(from),
              let toDate = parseLibCalTime(to) else { return false }
        return Date() >= fromDate && Date() <= toDate
    }

    private func parseLibCalTime(_ timeStr: String) -> Date? {
        let cleaned = timeStr.trimmingCharacters(in: .whitespaces)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let calendar = Calendar.current
        var base = calendar.dateComponents([.year, .month, .day], from: Date())

        for format in ["h:mma", "ha", "h:mm a", "h a"] {
            formatter.dateFormat = format
            if let parsed = formatter.date(from: cleaned) {
                let tc = calendar.dateComponents([.hour, .minute], from: parsed)
                base.hour = tc.hour
                base.minute = tc.minute
                base.second = 0
                return calendar.date(from: base)
            }
        }
        return nil
    }

    static func == (lhs: Library, rhs: Library) -> Bool { lhs.lid == rhs.lid }
    func hash(into hasher: inout Hasher) { hasher.combine(lid) }

    /// Returns a copy of this library with an additional sub-location appended.
    func withAdditionalSubLocation(_ sub: Library) -> Library {
        Library(lid: lid, name: name, color: color,
                allWeekHours: allWeekHours, subLocations: subLocations + [sub])
    }

    /// Returns a copy of this library with a completely replaced sub-location list.
    func withSubLocations(_ subs: [Library]) -> Library {
        Library(lid: lid, name: name, color: color,
                allWeekHours: allWeekHours, subLocations: subs)
    }

    /// Returns a copy of this library with a different display name.
    func withName(_ newName: String) -> Library {
        Library(lid: lid, name: newName, color: color,
                allWeekHours: allWeekHours, subLocations: subLocations)
    }
}

enum OpenStatus {
    case open, open24, closed, byAppointment, unknown

    var displayText: String {
        switch self {
        case .open: return "Open"
        case .open24: return "24 Hrs"
        case .closed: return "Closed"
        case .byAppointment: return "By Appt"
        case .unknown: return "—"
        }
    }

    var isAccessible: Bool {
        self == .open || self == .open24
    }
}

// MARK: - Mapping

extension LibraryLocationResponse {
    func toLibrary() -> Library {
        Library(
            lid: lid,
            name: name,
            color: color ?? "#3A87AD",
            allWeekHours: weeks,
            subLocations: subLocations?.map { $0.toLibrary() } ?? []
        )
    }
}

// MARK: - Cache

struct CachedLibraryData: Codable {
    let response: HoursAPIResponse
    let fetchedAt: Date

    var isStale: Bool {
        Date().timeIntervalSince(fetchedAt) > 3600
    }
}

// MARK: - Helpers

extension DateFormatter {
    func apply(_ configure: (DateFormatter) -> Void) -> DateFormatter {
        configure(self)
        return self
    }
}

extension String {
    /// Strips HTML tags (e.g. `<br>`, `</br>`, `<b>`) returned by the LibCal API.
    var strippingHTML: String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
