import Foundation

// MARK: - Study Space

struct StudySpace: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var building: String
    var floor: String
    var description: String
    var tags: [SpaceTag]
    var reports: [SpaceReport]
    var reviews: [SpaceReview]
    let createdAt: Date
    let createdByUserID: String

    var latestReport: SpaceReport? {
        reports.sorted { $0.timestamp > $1.timestamp }.first
    }

    var averageRating: Double? {
        guard !reviews.isEmpty else { return nil }
        return Double(reviews.map(\.rating).reduce(0, +)) / Double(reviews.count)
    }

    var reviewCount: Int { reviews.count }

    static func == (lhs: StudySpace, rhs: StudySpace) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Tags

enum SpaceTag: String, Codable, CaseIterable, Identifiable {
    case quiet
    case groupFriendly = "group_friendly"
    case outlets
    case naturalLight = "natural_light"
    case whiteboards
    case computers
    case accessible
    case openLate = "open_late"
    case twentyFourHours = "24_hours"
    case reservable
    case foodOK = "food_ok"
    case standingDesks = "standing_desks"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .quiet: return "Quiet"
        case .groupFriendly: return "Group Friendly"
        case .outlets: return "Outlets"
        case .naturalLight: return "Natural Light"
        case .whiteboards: return "Whiteboards"
        case .computers: return "Computers"
        case .accessible: return "Accessible"
        case .openLate: return "Open Late"
        case .twentyFourHours: return "24 Hours"
        case .reservable: return "Reservable"
        case .foodOK: return "Food OK"
        case .standingDesks: return "Standing Desks"
        }
    }

    var systemImage: String {
        switch self {
        case .quiet: return "speaker.slash.fill"
        case .groupFriendly: return "person.3.fill"
        case .outlets: return "bolt.fill"
        case .naturalLight: return "sun.max.fill"
        case .whiteboards: return "pencil.and.ruler.fill"
        case .computers: return "desktopcomputer"
        case .accessible: return "figure.roll"
        case .openLate: return "moon.fill"
        case .twentyFourHours: return "clock.fill"
        case .reservable: return "calendar.badge.plus"
        case .foodOK: return "fork.knife"
        case .standingDesks: return "figure.stand"
        }
    }
}

// MARK: - Space Report

struct SpaceReport: Identifiable, Codable {
    let id: String
    let userID: String
    let crowdLevel: CrowdLevel
    let noiseLevel: NoiseLevel
    let outletAvailability: OutletAvailability
    let seatingAvailability: SeatingAvailability
    let timestamp: Date

    var isRecent: Bool {
        Date().timeIntervalSince(timestamp) < 3600
    }

    var timeAgo: String {
        let s = Date().timeIntervalSince(timestamp)
        if s < 60 { return "Just now" }
        if s < 3600 { return "\(Int(s / 60))m ago" }
        if s < 86400 { return "\(Int(s / 3600))h ago" }
        return "\(Int(s / 86400))d ago"
    }
}

enum CrowdLevel: String, Codable, CaseIterable, Identifiable {
    case empty, light, moderate, busy, full
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .empty: return "Empty"
        case .light: return "Light"
        case .moderate: return "Moderate"
        case .busy: return "Busy"
        case .full: return "Full"
        }
    }

    var systemImage: String {
        switch self {
        case .empty: return "person"
        case .light: return "person.fill"
        case .moderate: return "person.2.fill"
        case .busy: return "person.3.fill"
        case .full: return "person.3.sequence.fill"
        }
    }

    var colorName: String {
        switch self {
        case .empty, .light: return "green"
        case .moderate: return "yellow"
        case .busy: return "orange"
        case .full: return "red"
        }
    }
}

enum NoiseLevel: String, Codable, CaseIterable, Identifiable {
    case silent, quiet, moderate, loud
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .silent: return "Silent"
        case .quiet: return "Quiet"
        case .moderate: return "Moderate"
        case .loud: return "Loud"
        }
    }

    var systemImage: String {
        switch self {
        case .silent: return "speaker.slash"
        case .quiet: return "speaker.wave.1"
        case .moderate: return "speaker.wave.2"
        case .loud: return "speaker.wave.3"
        }
    }
}

enum OutletAvailability: String, Codable, CaseIterable, Identifiable {
    case plenty, some, few, none
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .plenty: return "Plenty"
        case .some: return "Some"
        case .few: return "Few"
        case .none: return "None"
        }
    }
}

enum SeatingAvailability: String, Codable, CaseIterable, Identifiable {
    case plenty, some, limited, full
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .plenty: return "Plenty"
        case .some: return "Some"
        case .limited: return "Limited"
        case .full: return "Full"
        }
    }
}

// MARK: - Space Review

struct SpaceReview: Identifiable, Codable {
    let id: String
    let userID: String
    let rating: Int // 1–5
    let body: String
    let timestamp: Date

    var timeAgo: String {
        let s = Date().timeIntervalSince(timestamp)
        if s < 60 { return "Just now" }
        if s < 3600 { return "\(Int(s / 60))m ago" }
        if s < 86400 { return "\(Int(s / 3600))h ago" }
        if s < 2_592_000 { return "\(Int(s / 86400))d ago" }
        return "\(Int(s / 2_592_000))mo ago"
    }
}
