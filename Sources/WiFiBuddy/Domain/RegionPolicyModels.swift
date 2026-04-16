import Foundation

enum RecommendationMode: String, Codable, Hashable, Sendable {
    case normal
    case conservative
    case unsupported
}

struct BandCapability: Codable, Hashable, Sendable {
    let band: WiFiBand
    let channels: [Int]
    let dfsChannels: [Int]
    let preferredWidths: [WiFiChannelWidth]
    let recommendationMode: RecommendationMode
}

struct RegionPolicy: Codable, Hashable, Sendable, Identifiable {
    let countryCode: String
    let displayName: String
    let notes: [String]
    let bands: [BandCapability]

    var id: String { countryCode }

    func capability(for band: WiFiBand) -> BandCapability? {
        bands.first { $0.band == band }
    }
}

struct RegionPolicyDocument: Codable, Hashable, Sendable {
    let generatedAt: String
    let policies: [RegionPolicy]

    func policy(for countryCode: String?) -> RegionPolicy {
        if let countryCode,
           let exact = policies.first(where: { $0.countryCode == countryCode.uppercased() }) {
            return exact
        }
        return policies.first(where: { $0.countryCode == "ZZ" }) ?? Self.fallback.policies[0]
    }

    static let fallback = RegionPolicyDocument(
        generatedAt: "2026-04-16",
        policies: [
            RegionPolicy(
                countryCode: "ZZ",
                displayName: "Global Conservative Default",
                notes: [
                    "This policy is used when WiFiBuddy can't determine the local regulatory domain.",
                    "6 GHz recommendations are disabled until a known region policy is available."
                ],
                bands: [
                    BandCapability(
                        band: .band2GHz,
                        channels: Array(1...11),
                        dfsChannels: [],
                        preferredWidths: [.mhz20],
                        recommendationMode: .conservative
                    ),
                    BandCapability(
                        band: .band5GHz,
                        channels: [36, 40, 44, 48, 149, 153, 157, 161, 165],
                        dfsChannels: [],
                        preferredWidths: [.mhz80, .mhz40, .mhz20],
                        recommendationMode: .conservative
                    ),
                    BandCapability(
                        band: .band6GHz,
                        channels: [],
                        dfsChannels: [],
                        preferredWidths: [],
                        recommendationMode: .unsupported
                    )
                ]
            ),
            RegionPolicy(
                countryCode: "US",
                displayName: "United States",
                notes: [
                    "6 GHz recommendations assume Wi-Fi 6E/7 capable hardware and current regional allowances.",
                    "DFS channels can offer cleaner airspace, but some routers may prefer non-DFS for stability."
                ],
                bands: [
                    BandCapability(
                        band: .band2GHz,
                        channels: Array(1...11),
                        dfsChannels: [],
                        preferredWidths: [.mhz20],
                        recommendationMode: .normal
                    ),
                    BandCapability(
                        band: .band5GHz,
                        channels: [36, 40, 44, 48, 52, 56, 60, 64, 100, 104, 108, 112, 116, 120, 124, 128, 132, 136, 140, 149, 153, 157, 161, 165],
                        dfsChannels: [52, 56, 60, 64, 100, 104, 108, 112, 116, 120, 124, 128, 132, 136, 140],
                        preferredWidths: [.mhz80, .mhz40, .mhz20],
                        recommendationMode: .normal
                    ),
                    BandCapability(
                        band: .band6GHz,
                        channels: stride(from: 1, through: 233, by: 4).map { $0 },
                        dfsChannels: [],
                        preferredWidths: [.mhz160, .mhz80, .mhz40],
                        recommendationMode: .normal
                    )
                ]
            ),
            RegionPolicy(
                countryCode: "CN",
                displayName: "China Mainland",
                notes: [
                    "China currently allocates 6 GHz spectrum differently from Wi-Fi 6E/7 regions.",
                    "WiFiBuddy disables 6 GHz channel recommendations by default for China."
                ],
                bands: [
                    BandCapability(
                        band: .band2GHz,
                        channels: Array(1...13),
                        dfsChannels: [],
                        preferredWidths: [.mhz20],
                        recommendationMode: .normal
                    ),
                    BandCapability(
                        band: .band5GHz,
                        channels: [36, 40, 44, 48, 52, 56, 60, 64, 149, 153, 157, 161, 165],
                        dfsChannels: [52, 56, 60, 64],
                        preferredWidths: [.mhz80, .mhz40, .mhz20],
                        recommendationMode: .normal
                    ),
                    BandCapability(
                        band: .band6GHz,
                        channels: [],
                        dfsChannels: [],
                        preferredWidths: [],
                        recommendationMode: .unsupported
                    )
                ]
            )
        ]
    )
}
