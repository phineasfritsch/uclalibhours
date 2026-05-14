import Foundation

// MARK: - BlockService
// Stores the set of user IDs the current user has blocked locally in UserDefaults.
// Client-side filtering only — content from blocked users is hidden in this app.
// Pair with Cloud Functions / Firestore rules for a fuller block on the server side.

final class BlockService: ObservableObject {
    static let shared = BlockService()

    @Published private(set) var blockedUserIDs: Set<String>

    private let defaults: UserDefaults
    private let storageKey = "blockedUserIDs.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = (defaults.array(forKey: storageKey) as? [String]) ?? []
        self.blockedUserIDs = Set(stored)
    }

    // MARK: - Mutations

    func block(userID: String) {
        guard !userID.isEmpty else { return }
        blockedUserIDs.insert(userID)
        persist()
    }

    func unblock(userID: String) {
        blockedUserIDs.remove(userID)
        persist()
    }

    func isBlocked(_ userID: String) -> Bool {
        blockedUserIDs.contains(userID)
    }

    // MARK: - Persistence

    private func persist() {
        defaults.set(Array(blockedUserIDs), forKey: storageKey)
    }
}
