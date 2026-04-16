import Testing
@testable import WiFiBuddy

struct RegionPolicyServiceTests {
    @Test("Unknown regions fall back to the conservative global policy")
    func fallsBackToGlobalPolicyForUnknownCountry() {
        let policy = RegionPolicyDocument.fallback.policy(for: "XX")

        #expect(policy.countryCode == "ZZ")
        #expect(policy.displayName == "Global Conservative Default")
    }

    @Test("Region override takes precedence and intersects with supported channels")
    @MainActor
    func regionOverrideWinsAndIntersectsSupportedChannels() {
        let service = RegionPolicyService()
        service.setRegionOverride("cn")

        let channels = service.channels(
            for: .band2GHz,
            interfaceCountry: "US",
            networkCountry: nil,
            supportedChannels: [1, 6, 11, 13]
        )

        #expect(service.effectiveCountryCode(interfaceCountry: "US", networkCountry: nil) == "CN")
        #expect(channels == [1, 6, 11, 13])
    }
}
