import Foundation

// MARK: - GoBoard / Connect2Concepts API Response

struct FacilityCount: Codable, Identifiable, Hashable {
    let locationId: Int
    let totalCapacity: Int
    let locationName: String
    let countOfParticipants: Int
    let percentageCapacity: Double
    let lastUpdatedDateAndTime: String
    let lastCount: Int
    let minColor: String?
    let midColor: String?
    let maxColor: String?
    let minCapacityRange: Int
    let maxCapacityRange: Int
    let countCapacityColorEnabled: Bool
    let facilityId: Int
    let facilityName: String
    let isClosed: Bool

    var id: Int { locationId }

    enum CodingKeys: String, CodingKey {
        case locationId = "LocationId"
        case totalCapacity = "TotalCapacity"
        case locationName = "LocationName"
        case countOfParticipants = "CountOfParticipants"
        // The API ships this key with a typo ("Percetage"). Preserve it verbatim.
        case percentageCapacity = "PercetageCapacity"
        case lastUpdatedDateAndTime = "LastUpdatedDateAndTime"
        case lastCount = "LastCount"
        case minColor = "MinColor"
        case midColor = "MidColor"
        case maxColor = "MaxColor"
        case minCapacityRange = "MinCapacityRange"
        case maxCapacityRange = "MaxCapacityRange"
        case countCapacityColorEnabled = "CountCapacityColorEnabled"
        case facilityId = "FacilityId"
        case facilityName = "FacilityName"
        case isClosed = "IsClosed"
    }

    // MARK: - Derived values

    var fillPercent: Double {
        guard totalCapacity > 0 else { return 0 }
        return min(100, Double(lastCount) / Double(totalCapacity) * 100)
    }

    var fillPercentDisplay: Int { Int(fillPercent.rounded()) }

    var capacityLevel: CapacityLevel {
        if isClosed { return .closed }
        let pct = fillPercent
        if pct >= Double(maxCapacityRange) { return .full }
        if pct >= Double(minCapacityRange) { return .busy }
        return .open
    }

    /// "John Wooden Center - FITWELL" → "John Wooden Center"
    var displayFacilityName: String {
        facilityName
            .replacingOccurrences(of: " - FITWELL", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// API returns Pacific local time without a timezone suffix.
    var lastUpdatedDate: Date? {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "America/Los_Angeles")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss"] {
            df.dateFormat = fmt
            if let d = df.date(from: lastUpdatedDateAndTime) { return d }
        }
        return nil
    }
}

enum CapacityLevel {
    case open, busy, full, closed

    var displayText: String {
        switch self {
        case .open:   return "Open"
        case .busy:   return "Busy"
        case .full:   return "Full"
        case .closed: return "Closed"
        }
    }
}
