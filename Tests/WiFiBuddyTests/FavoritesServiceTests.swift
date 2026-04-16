import Testing
@testable import WiFiBuddy

@MainActor
struct FavoritesServiceTests {
    @Test("Current connection auto-star ignores hidden networks with missing identifiers")
    func hiddenNetworksDoNotMatchEmptyCurrentConnectionFields() {
        let service = FavoritesService()
        let hiddenNetwork = makeObservation(id: "hidden", ssid: nil, bssid: nil)
        let currentConnection = CurrentConnection(
            interfaceName: "en0",
            ssid: nil,
            bssid: "AA:BB:CC:DD:EE:FF",
            countryCode: "CN",
            channelNumber: 36,
            band: .band5GHz,
            channelWidth: .mhz80,
            rssi: -48,
            noise: -92,
            security: .wpa3,
            phyMode: .ax,
            transmitRateMbps: 1200
        )

        #expect(service.isFavorite(hiddenNetwork, currentConnection: currentConnection) == false)
    }

    @Test("Current connection auto-star still matches a visible SSID")
    func visibleCurrentConnectionStillMatches() {
        let service = FavoritesService()
        let network = makeObservation(id: "home", ssid: "Home Wi-Fi", bssid: "11:22:33:44:55:66")
        let currentConnection = CurrentConnection(
            interfaceName: "en0",
            ssid: "Home Wi-Fi",
            bssid: "11:22:33:44:55:66",
            countryCode: "CN",
            channelNumber: 149,
            band: .band5GHz,
            channelWidth: .mhz80,
            rssi: -41,
            noise: -92,
            security: .wpa3,
            phyMode: .ax,
            transmitRateMbps: 1200
        )

        #expect(service.isFavorite(network, currentConnection: currentConnection))
    }

    private func makeObservation(id: String, ssid: String?, bssid: String?) -> NetworkObservation {
        NetworkObservation(
            id: id,
            ssid: ssid,
            bssid: bssid,
            band: .band5GHz,
            channelNumber: 149,
            channelWidth: .mhz80,
            rssi: -42,
            noise: -92,
            security: .wpa3,
            phyModes: [.ax],
            countryCode: "CN",
            beaconInterval: 100,
            isIBSS: false,
            informationElementSummary: nil,
            firstSeenAt: .now,
            lastSeenAt: .now,
            seenCount: 1
        )
    }
}
