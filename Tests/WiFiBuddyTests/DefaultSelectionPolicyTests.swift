import Foundation
import Testing
@testable import WiFiBuddy

struct DefaultSelectionPolicyTests {
    @Test("Hidden-only scans default to the strongest signal")
    func hiddenOnlySelectsStrongestSignal() {
        let observations = [
            makeObservation(id: "weak", ssid: nil, channel: 1, rssi: -82),
            makeObservation(id: "strong", ssid: nil, channel: 11, rssi: -47),
            makeObservation(id: "mid", ssid: nil, channel: 6, rssi: -63)
        ]

        #expect(DefaultSelectionPolicy.preferredNetworkID(in: observations) == "strong")
    }

    @Test("Named scans keep the existing list ordering")
    func namedScansKeepExistingOrder() {
        let observations = [
            makeObservation(id: "first", ssid: "Cafe", channel: 36, rssi: -71),
            makeObservation(id: "second", ssid: nil, channel: 40, rssi: -42)
        ]

        #expect(DefaultSelectionPolicy.preferredNetworkID(in: observations) == "first")
    }

    private func makeObservation(
        id: String,
        ssid: String?,
        channel: Int,
        rssi: Int
    ) -> NetworkObservation {
        NetworkObservation(
            id: id,
            ssid: ssid,
            bssid: id,
            band: channel <= 14 ? .band2GHz : .band5GHz,
            channelNumber: channel,
            channelWidth: .mhz20,
            rssi: rssi,
            noise: -92,
            security: .wpa2,
            phyModes: [.ax],
            countryCode: "CN",
            beaconInterval: 100,
            isIBSS: false,
            informationElementSummary: nil,
            firstSeenAt: Date(),
            lastSeenAt: Date(),
            seenCount: 1
        )
    }
}
