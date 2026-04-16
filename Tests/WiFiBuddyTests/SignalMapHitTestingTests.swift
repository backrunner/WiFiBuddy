import CoreGraphics
import Foundation
import Testing
@testable import WiFiBuddy

struct SignalMapHitTestingTests {
    @MainActor
    @Test("Signal map prefers the closest overlapping curve")
    func overlappingCurvesUseClickHeight() {
        let stronger = makeObservation(id: "stronger", channel: 40, width: .mhz80, rssi: -46)
        let weaker = makeObservation(id: "weaker", channel: 40, width: .mhz80, rssi: -70)
        let plot = makePlot(observations: [stronger, weaker])
        let height: CGFloat = 180

        let strongerGeometry = plot.curveGeometry(for: stronger, height: height)!
        let weakerGeometry = plot.curveGeometry(for: weaker, height: height)!

        let upperHit = CGPoint(x: strongerGeometry.centerX, y: strongerGeometry.peakY + 4)
        let lowerHit = CGPoint(x: weakerGeometry.centerX, y: weakerGeometry.peakY + 4)

        #expect(
            plot.hitTestNetworkID(to: upperHit, observations: [stronger, weaker], height: height) == stronger.id
        )
        #expect(
            plot.hitTestNetworkID(to: lowerHit, observations: [stronger, weaker], height: height) == weaker.id
        )
    }

    @MainActor
    @Test("Signal map ignores clicks outside the curve footprint")
    func missesOutsideCurveFootprint() {
        let observation = makeObservation(id: "outside", channel: 44, width: .mhz40, rssi: -55)
        let plot = makePlot(observations: [observation])
        let height: CGFloat = 180
        let geometry = plot.curveGeometry(for: observation, height: height)!

        let missPoint = CGPoint(x: geometry.rightX + 42, y: geometry.peakY + 6)

        #expect(
            plot.hitTestNetworkID(to: missPoint, observations: [observation], height: height) == nil
        )
    }

    @MainActor
    private func makePlot(observations: [NetworkObservation]) -> AnalyzerPlotDescriptor {
        AnalyzerPlotDescriptor(
            filter: .all,
            snapshot: WiFiEnvironmentSnapshot(
                status: .ready,
                interfaceSummary: nil,
                observations: observations,
                currentConnection: nil,
                lastScanDate: Date()
            ),
            regionPolicyService: RegionPolicyService(),
            availableWidth: 640
        )
    }

    private func makeObservation(
        id: String,
        channel: Int,
        width: WiFiChannelWidth,
        rssi: Int
    ) -> NetworkObservation {
        NetworkObservation(
            id: id,
            ssid: id,
            bssid: id,
            band: .band5GHz,
            channelNumber: channel,
            channelWidth: width,
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
