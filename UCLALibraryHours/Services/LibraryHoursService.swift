import Foundation

// MARK: - LibraryHoursService

final class LibraryHoursService {
    static let shared = LibraryHoursService()

    private let cacheKey = "cachedLibraryHours"
    private let apiURL = URL(string: "https://calendar.library.ucla.edu/api_hours_grid.php?iid=3244&format=json&weeks=2&systemTime=0")!

    private init() {}

    // MARK: - Fetch

    func fetchAndCacheHours() async throws -> [Library] {
        let (data, response) = try await URLSession.shared.data(from: apiURL)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw LibraryServiceError.badResponse
        }

        let apiResponse = try JSONDecoder().decode(HoursAPIResponse.self, from: data)
        cache(apiResponse)
        return apiResponse.locations.map { $0.toLibrary() }
    }

    // MARK: - Cache

    func loadCachedHours() -> [Library]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        guard let cached = try? JSONDecoder().decode(CachedLibraryData.self, from: data) else { return nil }
        return cached.response.locations.map { $0.toLibrary() }
    }

    func cachedDataIsStale() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode(CachedLibraryData.self, from: data) else {
            return true
        }
        return cached.isStale
    }

    private func cache(_ response: HoursAPIResponse) {
        let cached = CachedLibraryData(response: response, fetchedAt: Date())
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}

// MARK: - Errors

enum LibraryServiceError: LocalizedError {
    case badResponse
    case noData

    var errorDescription: String? {
        switch self {
        case .badResponse: return "Couldn't reach the UCLA Library server. Please try again."
        case .noData: return "No library hours data is available."
        }
    }
}
