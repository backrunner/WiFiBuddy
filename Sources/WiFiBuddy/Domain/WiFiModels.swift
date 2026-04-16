import Foundation

enum WiFiBand: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case band2GHz = "2.4GHz"
    case band5GHz = "5GHz"
    case band6GHz = "6GHz"

    var id: String { rawValue }

    var title: String { rawValue }

    var shortTitle: String {
        switch self {
        case .band2GHz:
            "2.4"
        case .band5GHz:
            "5"
        case .band6GHz:
            "6"
        }
    }

    var sortOrder: Int {
        switch self {
        case .band2GHz:
            0
        case .band5GHz:
            1
        case .band6GHz:
            2
        }
    }

    func centerFrequencyMHz(for channelNumber: Int) -> Int? {
        switch self {
        case .band2GHz:
            if channelNumber == 14 {
                return 2484
            }
            guard (1...13).contains(channelNumber) else { return nil }
            return 2407 + (channelNumber * 5)
        case .band5GHz:
            guard channelNumber > 0 else { return nil }
            return 5000 + (channelNumber * 5)
        case .band6GHz:
            guard channelNumber > 0 else { return nil }
            return 5950 + (channelNumber * 5)
        }
    }
}

enum WiFiChannelWidth: Int, CaseIterable, Codable, Hashable, Sendable {
    case unknown = 0
    case mhz20 = 20
    case mhz40 = 40
    case mhz80 = 80
    case mhz160 = 160

    var label: String {
        switch self {
        case .unknown:
            "Unknown"
        case .mhz20:
            "20 MHz"
        case .mhz40:
            "40 MHz"
        case .mhz80:
            "80 MHz"
        case .mhz160:
            "160 MHz"
        }
    }

    var bandwidthMHz: Double {
        switch self {
        case .unknown:
            20
        case .mhz20:
            20
        case .mhz40:
            40
        case .mhz80:
            80
        case .mhz160:
            160
        }
    }

    func displaySpanInChannelSteps(for band: WiFiBand) -> Double {
        let channelStepMHz: Double = switch band {
        case .band2GHz:
            5
        case .band5GHz, .band6GHz:
            20
        }

        return bandwidthMHz / channelStepMHz
    }
}

enum WiFiSecurity: String, CaseIterable, Codable, Hashable, Sendable {
    case none
    case wep
    case wpa
    case wpa2
    case wpa3
    case mixed
    case owe
    case enterprise
    case unknown

    var shortLabel: String {
        switch self {
        case .none:
            "Open"
        case .wep:
            "WEP"
        case .wpa:
            "WPA"
        case .wpa2:
            "WPA2"
        case .wpa3:
            "WPA3"
        case .mixed:
            "Mixed"
        case .owe:
            "OWE"
        case .enterprise:
            "Enterprise"
        case .unknown:
            "Unknown"
        }
    }
}

enum WiFiPHYMode: String, CaseIterable, Codable, Hashable, Sendable {
    case unknown
    case a = "802.11a"
    case b = "802.11b"
    case g = "802.11g"
    case n = "802.11n"
    case ac = "802.11ac"
    case ax = "802.11ax"
}

struct NetworkObservation: Identifiable, Hashable, Codable, Sendable {
    typealias ID = String

    let id: ID
    let ssid: String?
    let bssid: String?
    let band: WiFiBand
    let channelNumber: Int
    let channelWidth: WiFiChannelWidth
    let rssi: Int
    let noise: Int?
    let security: WiFiSecurity
    let phyModes: [WiFiPHYMode]
    let countryCode: String?
    let beaconInterval: Int?
    let isIBSS: Bool
    let informationElementSummary: String?
    let firstSeenAt: Date
    let lastSeenAt: Date
    let seenCount: Int

    var preferredSSID: String? {
        ssid?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    var hasVisibleName: Bool {
        preferredSSID != nil
    }

    var displayName: String {
        preferredSSID ?? bssid?.uppercased() ?? "Hidden Network"
    }

    var snr: Int? {
        guard let noise else { return nil }
        return rssi - noise
    }

    var primaryPHYLabel: String {
        phyModes.first?.rawValue ?? WiFiPHYMode.unknown.rawValue
    }

    var centerFrequencyMHz: Int? {
        band.centerFrequencyMHz(for: channelNumber)
    }

    var centerFrequencyLabel: String {
        guard let centerFrequencyMHz else { return "Unknown" }
        return "\(centerFrequencyMHz) MHz"
    }
}

struct FavoriteNetwork: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let ssid: String?
    let bssid: String?
    let alias: String?
    let starredAt: Date
}

struct CurrentConnection: Hashable, Codable, Sendable {
    let interfaceName: String
    let ssid: String?
    let bssid: String?
    let countryCode: String?
    let channelNumber: Int?
    let band: WiFiBand?
    let channelWidth: WiFiChannelWidth
    let rssi: Int?
    let noise: Int?
    let security: WiFiSecurity
    let phyMode: WiFiPHYMode
    let transmitRateMbps: Double

    var snr: Int? {
        guard let rssi, let noise else { return nil }
        return rssi - noise
    }
}

struct WiFiInterfaceSummary: Hashable, Codable, Sendable {
    let interfaceName: String
    let powerOn: Bool
    let serviceActive: Bool
    let countryCode: String?
    let currentBand: WiFiBand?
    let currentChannel: Int?
    let supportedChannelsByBand: [WiFiBand: [Int]]

    func supportedChannels(for band: WiFiBand) -> [Int] {
        supportedChannelsByBand[band] ?? []
    }
}

enum WiFiEnvironmentStatus: Hashable, Sendable {
    case idle
    case scanning
    case ready
    case noInterface
    case wifiDisabled
    case failed(String)
}

struct WiFiEnvironmentSnapshot: Hashable, Sendable {
    var status: WiFiEnvironmentStatus
    var interfaceSummary: WiFiInterfaceSummary?
    var observations: [NetworkObservation]
    var currentConnection: CurrentConnection?
    var lastScanDate: Date?

    static let idle = WiFiEnvironmentSnapshot(
        status: .idle,
        interfaceSummary: nil,
        observations: [],
        currentConnection: nil,
        lastScanDate: nil
    )

    func updatingStatus(_ status: WiFiEnvironmentStatus) -> WiFiEnvironmentSnapshot {
        var copy = self
        copy.status = status
        return copy
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    var normalizedRegionCode: String? {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .nilIfEmpty
    }
}
