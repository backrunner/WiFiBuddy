import Testing
@testable import WiFiBuddy

@Suite("Wi-Fi environment snapshot state")
struct WiFiEnvironmentSnapshotTests {
    @Test("Hard empty states do not flash back to scanning")
    func hardEmptyStatesDoNotShowTransientScanningState() {
        #expect(makeSnapshot(status: .noInterface).shouldShowTransientScanningState == false)
        #expect(makeSnapshot(status: .wifiDisabled).shouldShowTransientScanningState == false)
        #expect(makeSnapshot(status: .failed("No scan")).shouldShowTransientScanningState == false)
    }

    @Test("Existing data can keep showing scanning during refresh")
    func populatedHardStatesCanShowTransientScanningState() {
        let snapshot = WiFiEnvironmentSnapshot(
            status: .failed("Retrying"),
            interfaceSummary: WiFiInterfaceSummary(
                interfaceName: "en1",
                powerOn: true,
                serviceActive: true,
                countryCode: "US",
                currentBand: .band5GHz,
                currentChannel: 40,
                supportedChannelsByBand: [.band5GHz: [36, 40, 44, 48]]
            ),
            observations: [],
            currentConnection: nil,
            lastScanDate: nil
        )

        #expect(snapshot.shouldShowTransientScanningState == true)
    }

    private func makeSnapshot(status: WiFiEnvironmentStatus) -> WiFiEnvironmentSnapshot {
        WiFiEnvironmentSnapshot(
            status: status,
            interfaceSummary: nil,
            observations: [],
            currentConnection: nil,
            lastScanDate: nil
        )
    }
}
