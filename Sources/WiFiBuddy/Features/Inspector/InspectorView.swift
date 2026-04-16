import SwiftUI

struct InspectorView: View {
    @Environment(AppNavigationModel.self) private var navigation
    @Environment(WiFiScanService.self) private var wifiScanService
    @Environment(FavoritesService.self) private var favoritesService

    var body: some View {
        Group {
            if let selectedObservation {
                ScrollView {
                    VStack(alignment: .leading, spacing: WiFiBuddyTokens.Spacing.regular) {
                        summaryView(for: selectedObservation)
                        snapshotSection(for: selectedObservation)
                        identitySection(for: selectedObservation)
                        observationSection(for: selectedObservation)

                        if isCurrentConnection(selectedObservation) {
                            currentConnectionSection
                        }
                    }
                    .padding(.trailing, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.automatic)
                .wifiBuddyScrollFade()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .frame(minHeight: 0)
            } else {
                emptyStateView
            }
        }
        .wifiBuddyPanel(padding: 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(minHeight: 0)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        let snapshot = wifiScanService.snapshot
        if case .idle = snapshot.status {
            CenteredModuleStateView(
                title: "Preparing Network Detail",
                message: "Waiting for the first scan to finish — details will appear as soon as a network is picked up.",
                systemImage: "wifi",
                showsProgress: true
            )
        } else if case .scanning = snapshot.status, snapshot.observations.isEmpty {
            CenteredModuleStateView(
                title: "Preparing Network Detail",
                message: "Waiting for the first scan to finish — details will appear as soon as a network is picked up.",
                systemImage: "wifi",
                showsProgress: true
            )
        } else if case .ready = snapshot.status, snapshot.observations.isEmpty {
            CenteredModuleStateView(
                title: "No Visible Networks",
                message: "Run another scan or move to a location with nearby Wi-Fi activity.",
                systemImage: "wifi.exclamationmark"
            )
        } else {
            CenteredModuleStateView(
                title: "Select a Wi-Fi Network",
                message: "Choose a network from the sidebar or click a signal curve to inspect its details.",
                systemImage: "cursorarrow.click.2"
            )
        }
    }

    private var selectedObservation: NetworkObservation? {
        wifiScanService.snapshot.observations.first { $0.id == navigation.selectedNetworkID }
    }

    @ViewBuilder
    private func summaryView(for observation: NetworkObservation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(observation.displayName)
                            .font(.title2.weight(.semibold))
                            .lineLimit(1)

                        if favoritesService.containsPersistedFavorite(observation) {
                            FavoriteHighlightTag()
                        }

                        if isCurrentConnection(observation) {
                            OwnerHighlightTag()
                        }
                    }

                    MutedMetadataLine(items: [
                        observation.hasVisibleName ? "SSID available" : "SSID hidden",
                        observation.countryCode ?? wifiScanService.snapshot.interfaceSummary?.countryCode ?? ""
                    ])
                }

                Spacer(minLength: 0)

                BandBadge(band: observation.band)
            }
        }
    }

    private func snapshotSection(for observation: NetworkObservation) -> some View {
        SectionContainer(title: "Live Snapshot") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 10)], spacing: 10) {
                MetricBadge(title: "RSSI", value: WiFiBuddyFormatters.dbm(observation.rssi), systemImage: "waveform", tint: .mint)
                MetricBadge(title: "Noise", value: formatOptionalDbm(observation.noise), systemImage: "speaker.slash", tint: .orange)
                MetricBadge(title: "SNR", value: formatOptionalInteger(observation.snr), systemImage: "plus.forwardslash.minus", tint: .green)
                MetricBadge(title: "Channel", value: "\(observation.channelNumber)", systemImage: "dot.radiowaves.left.and.right", tint: WiFiBuddyTokens.bandColor(observation.band))
                MetricBadge(title: "Center", value: observation.centerFrequencyLabel, systemImage: "point.3.connected.trianglepath.dotted", tint: .blue)
                MetricBadge(title: "Width", value: observation.channelWidth.label, systemImage: "arrow.left.and.right", tint: .indigo)
                MetricBadge(title: "Security", value: observation.security.shortLabel, systemImage: "lock", tint: .orange)
                MetricBadge(title: "PHY", value: observation.primaryPHYLabel, systemImage: "antenna.radiowaves.left.and.right", tint: .teal)
            }
        }
    }

    private func identitySection(for observation: NetworkObservation) -> some View {
        SectionContainer(title: "Network Details") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(identityRows(for: observation).enumerated()), id: \.offset) { index, row in
                    KeyValueLine(title: row.title, value: row.value)

                    if index < identityRows(for: observation).count - 1 {
                        Divider()
                    }
                }
            }
            .wifiBuddyInsetPanel(padding: 12)
        }
    }

    @ViewBuilder
    private func observationSection(for observation: NetworkObservation) -> some View {
        let rows = observationRows(for: observation)
        if !rows.isEmpty {
            SectionContainer(title: "Observation") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        KeyValueLine(title: row.title, value: row.value)

                        if index < rows.count - 1 {
                            Divider()
                        }
                    }
                }
                .wifiBuddyInsetPanel(padding: 12)
            }
        }
    }

    @ViewBuilder
    private var currentConnectionSection: some View {
        if let currentConnection = wifiScanService.snapshot.currentConnection {
            SectionContainer(title: "Current Link") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(currentConnectionRows(currentConnection).enumerated()), id: \.offset) { index, row in
                        KeyValueLine(title: row.title, value: row.value)

                        if index < currentConnectionRows(currentConnection).count - 1 {
                            Divider()
                        }
                    }
                }
                .wifiBuddyInsetPanel(padding: 12)
            }
        }
    }

    private func identityRows(for observation: NetworkObservation) -> [(title: String, value: String)] {
        [
            ("SSID", observation.displayName),
            ("MAC / BSSID", observation.bssid ?? "Unavailable"),
            ("Band", observation.band.title),
            ("Channel", "\(observation.channelNumber)"),
            ("Center Frequency", observation.centerFrequencyLabel),
            ("Channel Width", observation.channelWidth.label),
            ("Security", observation.security.shortLabel),
            ("PHY Modes", observation.phyModes.map(\.rawValue).joined(separator: ", ").nilIfEmpty ?? "Unknown"),
            ("Country Code", observation.countryCode ?? wifiScanService.snapshot.interfaceSummary?.countryCode ?? "Unavailable"),
            ("IBSS", observation.isIBSS ? "Yes" : "No")
        ]
    }

    private func observationRows(for observation: NetworkObservation) -> [(title: String, value: String)] {
        var rows: [(title: String, value: String)] = []
        if let beacon = observation.beaconInterval {
            rows.append(("Beacon Interval", WiFiBuddyFormatters.integer(beacon)))
        }
        if let ie = observation.informationElementSummary {
            rows.append(("Information Elements", ie))
        }
        return rows
    }

    private func currentConnectionRows(_ connection: CurrentConnection) -> [(title: String, value: String)] {
        [
            ("Interface", connection.interfaceName),
            ("SSID", connection.ssid?.nilIfEmpty ?? "Unavailable"),
            ("MAC / BSSID", connection.bssid ?? "Unavailable"),
            ("Channel", connection.channelNumber.map(String.init) ?? "Unavailable"),
            ("Width", connection.channelWidth.label),
            ("RSSI", formatOptionalDbm(connection.rssi)),
            ("Noise", formatOptionalDbm(connection.noise)),
            ("SNR", formatOptionalInteger(connection.snr)),
            ("Transmit Rate", WiFiBuddyFormatters.mbps(connection.transmitRateMbps))
        ]
    }

    private func formatOptionalDbm(_ value: Int?) -> String {
        guard let value else { return "Unavailable" }
        return WiFiBuddyFormatters.dbm(value)
    }

    private func formatOptionalInteger(_ value: Int?) -> String {
        guard let value else { return "Unavailable" }
        return WiFiBuddyFormatters.integer(value)
    }

    private func isFavorite(_ observation: NetworkObservation?) -> Bool {
        favoritesService.isFavorite(observation, currentConnection: wifiScanService.snapshot.currentConnection)
    }

    private func isCurrentConnection(_ observation: NetworkObservation) -> Bool {
        guard let currentConnection = wifiScanService.snapshot.currentConnection else { return false }

        if let bssid = observation.bssid?.uppercased(),
           let currentBSSID = currentConnection.bssid?.uppercased(),
           bssid == currentBSSID {
            return true
        }

        if let ssid = observation.preferredSSID?.uppercased(),
           let currentSSID = currentConnection.ssid?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
           ssid == currentSSID {
            return true
        }

        return false
    }
}
