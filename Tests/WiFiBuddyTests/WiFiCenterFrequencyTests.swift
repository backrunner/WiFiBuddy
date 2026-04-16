import Testing
@testable import WiFiBuddy

struct WiFiCenterFrequencyTests {
    @Test("Center frequencies map correctly across Wi-Fi bands")
    func centerFrequenciesByBand() {
        #expect(WiFiBand.band2GHz.centerFrequencyMHz(for: 1) == 2412)
        #expect(WiFiBand.band2GHz.centerFrequencyMHz(for: 6) == 2437)
        #expect(WiFiBand.band2GHz.centerFrequencyMHz(for: 14) == 2484)
        #expect(WiFiBand.band5GHz.centerFrequencyMHz(for: 36) == 5180)
        #expect(WiFiBand.band5GHz.centerFrequencyMHz(for: 149) == 5745)
        #expect(WiFiBand.band6GHz.centerFrequencyMHz(for: 37) == 6135)
    }
}
