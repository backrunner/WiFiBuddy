import Testing
@testable import WiFiBuddy

struct WiFiChannelWidthTests {
    @Test("2.4 GHz widths expand in 5 MHz channel steps")
    func widthSpansFor24GHz() {
        #expect(WiFiChannelWidth.mhz20.displaySpanInChannelSteps(for: .band2GHz) == 4)
        #expect(WiFiChannelWidth.mhz40.displaySpanInChannelSteps(for: .band2GHz) == 8)
    }

    @Test("5 GHz and 6 GHz widths expand in 20 MHz channel steps")
    func widthSpansFor5And6GHz() {
        #expect(WiFiChannelWidth.mhz20.displaySpanInChannelSteps(for: .band5GHz) == 1)
        #expect(WiFiChannelWidth.mhz80.displaySpanInChannelSteps(for: .band5GHz) == 4)
        #expect(WiFiChannelWidth.mhz160.displaySpanInChannelSteps(for: .band6GHz) == 8)
    }
}
