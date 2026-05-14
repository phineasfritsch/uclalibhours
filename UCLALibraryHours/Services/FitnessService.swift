import Foundation

// MARK: - FitnessService

final class FitnessService {
    static let shared = FitnessService()

    // Public Connect2Concepts account key used by the UCLA Recreation live counts page.
    // Same key is shipped in the public web app's JavaScript.
    private let accountAPIKey = "73829a91-48cb-4b7b-bd0b-8cf4134c04cd"

    private var apiURL: URL {
        URL(string: "https://goboardapi.azurewebsites.net/api/FacilityCount/GetCountsByAccount?AccountAPIKey=\(accountAPIKey)")!
    }

    private init() {}

    func fetchCounts() async throws -> [FacilityCount] {
        var request = URLRequest(url: apiURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw FitnessServiceError.badResponse
        }
        return try JSONDecoder().decode([FacilityCount].self, from: data)
    }
}

// MARK: - Errors

enum FitnessServiceError: LocalizedError {
    case badResponse

    var errorDescription: String? {
        switch self {
        case .badResponse: return "Couldn't reach the gym counts server. Please try again."
        }
    }
}
