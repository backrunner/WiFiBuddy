import Foundation
import Observation

@MainActor
@Observable
final class RegionPolicyService {
    var document = RegionPolicyDocument.fallback
    var regionOverride: String?

    init() {
        loadFromBundle()
    }

    func setRegionOverride(_ code: String?) {
        regionOverride = code?.normalizedRegionCode
    }

    func effectiveCountryCode(interfaceCountry: String?, networkCountry: String?) -> String? {
        regionOverride ?? interfaceCountry?.normalizedRegionCode ?? networkCountry?.normalizedRegionCode
    }

    func effectivePolicy(interfaceCountry: String?, networkCountry: String?) -> RegionPolicy {
        document.policy(for: effectiveCountryCode(interfaceCountry: interfaceCountry, networkCountry: networkCountry))
    }

    func channels(
        for band: WiFiBand,
        interfaceCountry: String?,
        networkCountry: String?,
        supportedChannels: [Int]
    ) -> [Int] {
        let policy = effectivePolicy(interfaceCountry: interfaceCountry, networkCountry: networkCountry)
        guard let capability = policy.capability(for: band) else { return [] }
        if supportedChannels.isEmpty {
            return capability.channels
        }
        let filtered = capability.channels.filter { supportedChannels.contains($0) }
        return filtered.isEmpty ? capability.channels : filtered
    }

    func allPolicies() -> [RegionPolicy] {
        document.policies.sorted { $0.displayName < $1.displayName }
    }

    private func loadFromBundle() {
        guard let url = Bundle.module.url(forResource: "region_policies", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(RegionPolicyDocument.self, from: data) else {
            return
        }
        document = decoded
    }
}
