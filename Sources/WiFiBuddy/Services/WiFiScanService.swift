import CoreWLAN
import Observation
import Foundation

@MainActor
@Observable
final class WiFiScanService {
    var snapshot: WiFiEnvironmentSnapshot = .idle
    var scanInterval: Double = 15
    var includeHiddenNetworks = false

    @ObservationIgnored
    private var monitoringTask: Task<Void, Never>?

    func updatePreferences(scanInterval: Double, includeHidden: Bool) async {
        self.scanInterval = max(5, scanInterval)
        self.includeHiddenNetworks = includeHidden

        if monitoringTask != nil {
            await startMonitoring()
        }
    }

    func startMonitoring() async {
        stopMonitoring()
        monitoringTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refresh()
                let duration = UInt64(max(self.scanInterval, 5) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: duration)
            }
        }
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    func refresh() async {
        let previous = snapshot
        snapshot = snapshot.updatingStatus(.scanning)

        do {
            let result = try await Self.performScan(includeHidden: includeHiddenNetworks)
            let mergedObservations = Self.merge(previous: previous.observations, fresh: result.observations)
            snapshot = WiFiEnvironmentSnapshot(
                status: result.status,
                interfaceSummary: result.interfaceSummary,
                observations: mergedObservations,
                currentConnection: result.currentConnection,
                lastScanDate: result.lastScanDate
            )
        } catch {
            snapshot = WiFiEnvironmentSnapshot(
                status: .failed(Self.userFacingMessage(for: error)),
                interfaceSummary: previous.interfaceSummary,
                observations: previous.observations,
                currentConnection: previous.currentConnection,
                lastScanDate: previous.lastScanDate
            )
        }
    }

    func applyPreviewSnapshot(_ previewSnapshot: WiFiEnvironmentSnapshot) {
        snapshot = previewSnapshot
    }

    nonisolated private static func performScan(includeHidden: Bool) async throws -> WiFiEnvironmentSnapshot {
        try await Task.detached(priority: .utility) {
            let client = CWWiFiClient.shared()
            guard let interface = client.interface() else {
                return WiFiEnvironmentSnapshot(
                    status: .noInterface,
                    interfaceSummary: nil,
                    observations: [],
                    currentConnection: nil,
                    lastScanDate: nil
                )
            }

            let interfaceSummary = mapInterfaceSummary(interface)
            let currentConnection = mapCurrentConnection(interface)
            guard interfaceSummary.powerOn else {
                return WiFiEnvironmentSnapshot(
                    status: .wifiDisabled,
                    interfaceSummary: interfaceSummary,
                    observations: [],
                    currentConnection: currentConnection,
                    lastScanDate: nil
                )
            }

            let scanResults: Set<CWNetwork>
            do {
                scanResults = try interface.scanForNetworks(withName: nil, includeHidden: includeHidden)
            } catch {
                let cached = interface.cachedScanResults() ?? []
                if cached.isEmpty {
                    throw error
                }
                scanResults = cached
            }

            let now = Date()
            let observations = scanResults
                .map { mapNetwork($0, observedAt: now) }
                .reduce(into: [NetworkObservation]()) { partialResult, observation in
                    partialResult.append(observation)
                }
            let deduplicatedObservations = collapseDuplicateIdentifiers(in: observations)
                .sorted(by: sortObservations)

            return WiFiEnvironmentSnapshot(
                status: .ready,
                interfaceSummary: interfaceSummary,
                observations: deduplicatedObservations,
                currentConnection: currentConnection,
                lastScanDate: now
            )
        }
        .value
    }

    nonisolated private static func mapInterfaceSummary(_ interface: CWInterface) -> WiFiInterfaceSummary {
        var channelsByBand: [WiFiBand: [Int]] = [:]
        for channel in interface.supportedWLANChannels() ?? [] {
            let band = mapBand(channel.channelBand) ?? inferBand(from: channel.channelNumber)
            channelsByBand[band, default: []].append(channel.channelNumber)
        }

        for band in WiFiBand.allCases {
            channelsByBand[band] = (channelsByBand[band] ?? []).sorted()
        }

        let currentChannel = interface.wlanChannel()
        return WiFiInterfaceSummary(
            interfaceName: interface.interfaceName ?? "en0",
            powerOn: interface.powerOn(),
            serviceActive: interface.serviceActive(),
            countryCode: interface.countryCode()?.normalizedRegionCode,
            currentBand: currentChannel.flatMap { mapBand($0.channelBand) ?? inferBand(from: $0.channelNumber) },
            currentChannel: currentChannel?.channelNumber,
            supportedChannelsByBand: channelsByBand
        )
    }

    nonisolated private static func mapCurrentConnection(_ interface: CWInterface) -> CurrentConnection? {
        guard let interfaceName = interface.interfaceName else { return nil }
        let currentChannel = interface.wlanChannel()
        let resolvedSSID = decodeSSID(interface.ssid()) ?? decodeSSIDData(interface.ssidData())
        return CurrentConnection(
            interfaceName: interfaceName,
            ssid: resolvedSSID,
            bssid: interface.bssid()?.uppercased(),
            countryCode: interface.countryCode()?.normalizedRegionCode,
            channelNumber: currentChannel?.channelNumber,
            band: currentChannel.flatMap { mapBand($0.channelBand) ?? inferBand(from: $0.channelNumber) },
            channelWidth: mapChannelWidth(currentChannel?.channelWidth),
            rssi: interface.rssiValue() == 0 ? nil : interface.rssiValue(),
            noise: interface.noiseMeasurement() == 0 ? nil : interface.noiseMeasurement(),
            security: mapSecurity(interface.security()),
            phyMode: mapPHYMode(interface.activePHYMode()),
            transmitRateMbps: interface.transmitRate()
        )
    }

    nonisolated private static func mapNetwork(_ network: CWNetwork, observedAt: Date) -> NetworkObservation {
        let channel = network.wlanChannel
        let band = channel.flatMap { mapBand($0.channelBand) ?? inferBand(from: $0.channelNumber) } ?? .band2GHz
        let resolvedSSID = decodeSSID(network.ssid) ?? decodeSSIDData(network.ssidData)
        let infoSummary: String?
        if let info = network.informationElementData {
            let prefix = info.prefix(8).map { String(format: "%02X", $0) }.joined()
            infoSummary = "\(info.count) bytes • \(prefix)"
        } else {
            infoSummary = nil
        }

        let fallbackIdentifierComponents = [
            resolvedSSID ?? "hidden",
            String(channel?.channelNumber ?? -1),
            band.rawValue,
            mapChannelWidth(channel?.channelWidth).label,
            mapSecurity(network).rawValue,
            network.countryCode?.normalizedRegionCode ?? "ZZ",
            network.ibss ? "ibss" : "infra",
            String(network.beaconInterval),
            infoSummary ?? "no-ie"
        ]

        return NetworkObservation(
            id: network.bssid?.uppercased() ?? fallbackIdentifierComponents.joined(separator: "|"),
            ssid: resolvedSSID,
            bssid: network.bssid?.uppercased(),
            band: band,
            channelNumber: channel?.channelNumber ?? 0,
            channelWidth: mapChannelWidth(channel?.channelWidth),
            rssi: network.rssiValue,
            noise: network.noiseMeasurement == 0 ? nil : network.noiseMeasurement,
            security: mapSecurity(network),
            phyModes: mapPHYModes(network),
            countryCode: network.countryCode?.normalizedRegionCode,
            beaconInterval: network.beaconInterval == 0 ? nil : network.beaconInterval,
            isIBSS: network.ibss,
            informationElementSummary: infoSummary,
            firstSeenAt: observedAt,
            lastSeenAt: observedAt,
            seenCount: 1
        )
    }

    nonisolated private static func sortObservations(_ lhs: NetworkObservation, _ rhs: NetworkObservation) -> Bool {
        if lhs.band.sortOrder != rhs.band.sortOrder {
            return lhs.band.sortOrder < rhs.band.sortOrder
        }
        if lhs.channelNumber != rhs.channelNumber {
            return lhs.channelNumber < rhs.channelNumber
        }
        if lhs.rssi != rhs.rssi {
            return lhs.rssi > rhs.rssi
        }
        return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
    }

    nonisolated private static func merge(previous: [NetworkObservation], fresh: [NetworkObservation]) -> [NetworkObservation] {
        let previousLookup = Dictionary(grouping: previous, by: \.id)

        return collapseDuplicateIdentifiers(in: fresh).map { observation in
            guard let earlier = previousLookup[observation.id]?.max(by: { lhs, rhs in
                if lhs.lastSeenAt != rhs.lastSeenAt {
                    return lhs.lastSeenAt < rhs.lastSeenAt
                }
                return lhs.rssi < rhs.rssi
            }) else {
                return observation
            }
            return NetworkObservation(
                id: observation.id,
                ssid: observation.ssid ?? earlier.ssid,
                bssid: observation.bssid ?? earlier.bssid,
                band: observation.band,
                channelNumber: observation.channelNumber,
                channelWidth: observation.channelWidth,
                rssi: observation.rssi,
                noise: observation.noise,
                security: observation.security,
                phyModes: observation.phyModes,
                countryCode: observation.countryCode ?? earlier.countryCode,
                beaconInterval: observation.beaconInterval,
                isIBSS: observation.isIBSS,
                informationElementSummary: observation.informationElementSummary ?? earlier.informationElementSummary,
                firstSeenAt: earlier.firstSeenAt,
                lastSeenAt: observation.lastSeenAt,
                seenCount: earlier.seenCount + 1
            )
        }
    }

    nonisolated private static func collapseDuplicateIdentifiers(in observations: [NetworkObservation]) -> [NetworkObservation] {
        Dictionary(grouping: observations, by: \.id)
            .values
            .map { duplicates in
                guard duplicates.count > 1 else { return duplicates[0] }

                let representative = duplicates.max { lhs, rhs in
                    if lhs.rssi != rhs.rssi {
                        return lhs.rssi < rhs.rssi
                    }
                    return lhs.lastSeenAt < rhs.lastSeenAt
                } ?? duplicates[0]

                return NetworkObservation(
                    id: representative.id,
                    ssid: representative.ssid,
                    bssid: representative.bssid,
                    band: representative.band,
                    channelNumber: representative.channelNumber,
                    channelWidth: representative.channelWidth,
                    rssi: representative.rssi,
                    noise: representative.noise,
                    security: representative.security,
                    phyModes: representative.phyModes,
                    countryCode: representative.countryCode,
                    beaconInterval: representative.beaconInterval,
                    isIBSS: representative.isIBSS,
                    informationElementSummary: representative.informationElementSummary,
                    firstSeenAt: duplicates.map(\.firstSeenAt).min() ?? representative.firstSeenAt,
                    lastSeenAt: duplicates.map(\.lastSeenAt).max() ?? representative.lastSeenAt,
                    seenCount: duplicates.reduce(0) { $0 + $1.seenCount }
                )
            }
    }

    nonisolated private static func mapBand(_ band: CWChannelBand?) -> WiFiBand? {
        switch band {
        case .band2GHz:
            .band2GHz
        case .band5GHz:
            .band5GHz
        case .band6GHz:
            .band6GHz
        default:
            nil
        }
    }

    nonisolated private static func inferBand(from channel: Int) -> WiFiBand {
        if channel <= 14 {
            return .band2GHz
        }
        if channel >= 1 && channel <= 233 {
            return channel >= 200 ? .band6GHz : .band5GHz
        }
        return .band5GHz
    }

    nonisolated private static func mapChannelWidth(_ width: CWChannelWidth?) -> WiFiChannelWidth {
        switch width?.rawValue {
        case 1:
            .mhz20
        case 2:
            .mhz40
        case 3:
            .mhz80
        case 4:
            .mhz160
        default:
            .unknown
        }
    }

    nonisolated private static func mapPHYMode(_ mode: CWPHYMode) -> WiFiPHYMode {
        switch mode.rawValue {
        case 1:
            .a
        case 2:
            .b
        case 3:
            .g
        case 4:
            .n
        case 5:
            .ac
        case 6:
            .ax
        default:
            .unknown
        }
    }

    nonisolated private static func mapPHYModes(_ network: CWNetwork) -> [WiFiPHYMode] {
        let modes: [(Int, WiFiPHYMode)] = [
            (6, .ax),
            (5, .ac),
            (4, .n),
            (3, .g),
            (2, .b),
            (1, .a)
        ]

        let supported = modes.compactMap { supportsPHYMode(network, rawValue: $0.0) ? $0.1 : nil }
        return supported.isEmpty ? [.unknown] : supported
    }

    nonisolated private static func mapSecurity(_ security: CWSecurity) -> WiFiSecurity {
        switch security.rawValue {
        case 0:
            .none
        case 1, 6:
            .wep
        case 2, 7:
            .wpa
        case 3, 8, 13:
            .mixed
        case 4, 9:
            .wpa2
        case 5, 10:
            .enterprise
        case 11, 12:
            .wpa3
        case 14, 15:
            .owe
        default:
            .unknown
        }
    }

    nonisolated private static func mapSecurity(_ network: CWNetwork) -> WiFiSecurity {
        if supportsSecurity(network, rawValue: 11) || supportsSecurity(network, rawValue: 12) {
            return .wpa3
        }
        if supportsSecurity(network, rawValue: 14) || supportsSecurity(network, rawValue: 15) {
            return .owe
        }
        if supportsSecurity(network, rawValue: 4) || supportsSecurity(network, rawValue: 9) {
            return .wpa2
        }
        if supportsSecurity(network, rawValue: 3) || supportsSecurity(network, rawValue: 8) || supportsSecurity(network, rawValue: 13) {
            return .mixed
        }
        if supportsSecurity(network, rawValue: 2) || supportsSecurity(network, rawValue: 7) {
            return .wpa
        }
        if supportsSecurity(network, rawValue: 1) || supportsSecurity(network, rawValue: 6) {
            return .wep
        }
        if supportsSecurity(network, rawValue: 0) {
            return .none
        }
        return .unknown
    }

    nonisolated private static func supportsPHYMode(_ network: CWNetwork, rawValue: Int) -> Bool {
        guard let mode = CWPHYMode(rawValue: rawValue) else { return false }
        return network.supportsPHYMode(mode)
    }

    nonisolated private static func supportsSecurity(_ network: CWNetwork, rawValue: Int) -> Bool {
        guard let security = CWSecurity(rawValue: rawValue) else { return false }
        return network.supportsSecurity(security)
    }

    nonisolated private static func userFacingMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            return "The Wi-Fi scan couldn't complete. Try again in a moment."
        }
        return nsError.localizedDescription
    }

    nonisolated private static func decodeSSID(_ string: String?) -> String? {
        string?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    nonisolated private static func decodeSSIDData(_ data: Data?) -> String? {
        guard let data, data.isEmpty == false else { return nil }

        for encoding in [String.Encoding.utf8, .ascii, .isoLatin1] {
            if let decoded = String(data: data, encoding: encoding)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty {
                return decoded
            }
        }

        return nil
    }
}
