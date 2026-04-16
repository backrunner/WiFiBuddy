import Foundation
import Observation

@MainActor
@Observable
final class FavoritesService {
    var favorites: [String: FavoriteNetwork] = [:]
    var isLoaded = false

    func load() async {
        defer { isLoaded = true }
        let url = storageURL()
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: FavoriteNetwork].self, from: data) else {
            return
        }
        favorites = decoded
    }

    func isFavorite(_ observation: NetworkObservation?, currentConnection: CurrentConnection? = nil) -> Bool {
        guard let observation else { return false }
        if containsPersistedFavorite(observation) {
            return true
        }

        guard let currentConnection else { return false }
        return matchesCurrentConnection(observation, currentConnection: currentConnection)
    }

    func containsPersistedFavorite(_ observation: NetworkObservation?) -> Bool {
        guard let observation else { return false }
        return favorites[observation.id] != nil
    }

    func toggleFavorite(_ observation: NetworkObservation) {
        if favorites[observation.id] != nil {
            favorites.removeValue(forKey: observation.id)
        } else {
            favorites[observation.id] = FavoriteNetwork(
                id: observation.id,
                ssid: observation.ssid,
                bssid: observation.bssid,
                alias: nil,
                starredAt: .now
            )
        }
        persist()
    }

    func seed(_ previewFavorites: [FavoriteNetwork]) {
        favorites = Dictionary(uniqueKeysWithValues: previewFavorites.map { ($0.id, $0) })
        isLoaded = true
    }

    private func persist() {
        let url = storageURL()
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func matchesCurrentConnection(
        _ observation: NetworkObservation,
        currentConnection: CurrentConnection
    ) -> Bool {
        if identifiersMatch(observation.bssid, currentConnection.bssid) {
            return true
        }

        return identifiersMatch(observation.ssid, currentConnection.ssid)
    }

    private func identifiersMatch(_ lhs: String?, _ rhs: String?) -> Bool {
        guard let lhs = normalizedIdentifier(lhs), let rhs = normalizedIdentifier(rhs) else {
            return false
        }
        return lhs == rhs
    }

    private func normalizedIdentifier(_ value: String?) -> String? {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .nilIfEmpty
    }

    private func storageURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base
            .appendingPathComponent("WiFiBuddy", isDirectory: true)
            .appendingPathComponent("favorites.json")
    }
}
