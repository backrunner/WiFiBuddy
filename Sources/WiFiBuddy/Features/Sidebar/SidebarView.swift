import AppKit
import SwiftUI

struct SidebarView: View {
    @Environment(AppNavigationModel.self) private var navigation
    @Environment(WiFiScanService.self) private var wifiScanService
    @Environment(WiFiPermissionService.self) private var permissionService
    @Environment(FavoritesService.self) private var favoritesService
    @State private var isAwaitingPermissionRefresh = false

    var body: some View {
        @Bindable var navigation = navigation

        VStack(spacing: WiFiBuddyTokens.Spacing.regular) {
            headerPanel

            if shouldShowPermissionCard {
                locationAccessCard
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 0)
        }
        .padding(.horizontal, WiFiBuddyTokens.Spacing.regular)
        .padding(.bottom, WiFiBuddyTokens.Spacing.regular)
        .frame(maxHeight: .infinity, alignment: .top)
        .onChange(of: permissionService.authorizationStatus) { oldValue, newValue in
            let wasAuthorized = oldValue == .authorizedAlways
            let isAuthorized = newValue == .authorizedAlways
            if wasAuthorized != isAuthorized, isAuthorized {
                beginPermissionDrivenRefresh()
            } else if newValue == .denied || newValue == .restricted {
                isAwaitingPermissionRefresh = false
            }
        }
        .onChange(of: permissionService.locationServicesEnabled) { _, isEnabled in
            guard isEnabled, permissionService.authorizationStatus == .authorizedAlways else { return }
            beginPermissionDrivenRefresh()
        }
        .onChange(of: wifiScanService.snapshot.status) { _, newValue in
            guard isAwaitingPermissionRefresh else { return }
            if case .scanning = newValue {
                return
            }
            isAwaitingPermissionRefresh = false
        }
    }

    @ViewBuilder
    private var content: some View {
        // The detail column already owns the prominent loading / empty state
        // treatments; the sidebar just surfaces the list (empty or not) so we
        // never render two spinners at once.
        listContent
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(sectionModels) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 2)

                        VStack(spacing: 6) {
                            ForEach(section.observations) { observation in
                                NetworkRowView(
                                    observation: observation,
                                    isStarred: favoritesService.containsPersistedFavorite(observation),
                                    isCurrentConnection: isCurrentConnection(observation),
                                    isSelected: navigation.selectedNetworkID == observation.id
                                )
                                .contentShape(RoundedRectangle(cornerRadius: WiFiBuddyTokens.CornerRadius.row, style: .continuous))
                                .onTapGesture {
                                    navigation.selectedNetworkID = observation.id
                                }
                                .contextMenu {
                                    Button(favoritesService.containsPersistedFavorite(observation) ? "Remove Star" : "Star Network") {
                                        favoritesService.toggleFavorite(observation)
                                    }

                                    if let ssid = observation.preferredSSID {
                                        Button("Copy SSID") {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(ssid, forType: .string)
                                        }
                                    }

                                    if let bssid = observation.bssid {
                                        Button("Copy BSSID") {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(bssid, forType: .string)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.trailing, 8) // reserve a lane for the scroll bar
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.automatic)
        .wifiBuddyScrollFade()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 0)
        .wifiBuddyPanel(padding: 14)
        .overlay {
            // While the list itself has nothing yet, show a quiet macOS-style
            // spinner so the panel doesn't read as a blank rectangle.
            if filteredObservations.isEmpty {
                SidebarIdlePlaceholder(status: wifiScanService.snapshot.status)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if case .scanning = wifiScanService.snapshot.status, filteredObservations.isEmpty == false {
                ProgressView("Scanning…")
                    .controlSize(.small)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .padding()
            }
        }
    }

    private var locationAccessCard: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                permissionCopy
                Spacer(minLength: 0)
                permissionPrimaryAction
            }

            VStack(alignment: .leading, spacing: 12) {
                permissionCopy
                HStack {
                    Spacer(minLength: 0)
                    permissionPrimaryAction
                }
            }
        }
        .wifiBuddyPanel(padding: 14)
    }

    private var bindingToSelectedID: Binding<NetworkObservation.ID?> {
        Binding(
            get: { navigation.selectedNetworkID },
            set: { navigation.selectedNetworkID = $0 }
        )
    }

    private var filteredObservations: [NetworkObservation] {
        let observations = wifiScanService.snapshot.observations
        guard let band = navigation.selectedBandFilter.band else { return observations }
        return observations.filter { $0.band == band }
    }

    private var namedNetworkCount: Int {
        filteredObservations.filter(\.hasVisibleName).count
    }

    private var favoriteCount: Int {
        filteredObservations.filter(isFavorite(_:)).count
    }

    private var shouldShowPermissionCard: Bool {
        // If SSIDs are resolving (we have at least one named network) the
        // user already has what the permission unlocks — hide the prompt
        // regardless of why it was originally triggered.
        if namedNetworkCount > 0 { return false }
        return isAwaitingPermissionRefresh || permissionService.needsAttention
    }

    private var headerSubtitle: String {
        if filteredObservations.isEmpty {
            return "Listening for networks…"
        }
        let counts = "\(filteredObservations.count) visible"
        if favoriteCount > 0 {
            return "\(counts) • \(favoriteCount) starred"
        }
        return counts
    }

    private var permissionCardTitle: String {
        if isAwaitingPermissionRefresh {
            return "Refreshing Network Names"
        }
        if filteredObservations.isEmpty == false && namedNetworkCount == 0 {
            return "Reveal Network Names"
        }

        switch permissionService.authorizationStatus {
        case .notDetermined:
            return "Allow Access"
        case .denied, .restricted:
            return "Location Access Needed"
        default:
            return "Location Services Off"
        }
    }

    private var permissionCardBody: String {
        if isAwaitingPermissionRefresh {
            return "Applying the new permission to the current scan."
        }
        if filteredObservations.isEmpty == false && namedNetworkCount == 0 {
            return "Location access reveals SSID and BSSID."
        }

        return "WiFiBuddy rescans automatically after access changes."
    }

    private var permissionCardIcon: String {
        switch permissionService.authorizationStatus {
        case .notDetermined:
            "location.fill"
        case .denied, .restricted:
            "location.slash.fill"
        default:
            "wifi.exclamationmark"
        }
    }

    private var permissionCardTint: Color {
        switch permissionService.authorizationStatus {
        case .notDetermined:
            .blue
        case .denied, .restricted:
            .orange
        default:
            .mint
        }
    }

    private var summaryLabelText: String {
        if isAwaitingPermissionRefresh {
            return "Nearby metadata is updating now."
        }
        if permissionService.needsAttention {
            return "Signal levels still work before names are available."
        }
        if filteredObservations.isEmpty {
            return "Nearby networks will appear here after the next scan."
        }
        return "This scan still exposes signal levels even when names stay hidden."
    }

    private func openLocationSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_LocationServices"
        ]

        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private var sectionModels: [SidebarSectionModel] {
        let grouped = Dictionary(grouping: filteredObservations, by: \.band)
        let sortMode = navigation.sidebarSortMode

        return grouped
            .map { band, value in
                return SidebarSectionModel(
                    id: band.rawValue,
                    title: band.title,
                    observations: value.sorted { lhs, rhs in
                        compare(lhs, rhs, mode: sortMode)
                    }
                )
            }
            .sorted { lhs, rhs in
                let lhsObservation = lhs.observations[0]
                let rhsObservation = rhs.observations[0]
                return lhsObservation.band.sortOrder < rhsObservation.band.sortOrder
            }
    }

    private func compare(
        _ lhs: NetworkObservation,
        _ rhs: NetworkObservation,
        mode: WiFiSortMode
    ) -> Bool {
        switch mode {
        case .smart:
            let lhsIsCurrent = isCurrentConnection(lhs)
            let rhsIsCurrent = isCurrentConnection(rhs)
            if lhsIsCurrent != rhsIsCurrent {
                return lhsIsCurrent && !rhsIsCurrent
            }
            let lhsStarred = favoritesService.containsPersistedFavorite(lhs)
            let rhsStarred = favoritesService.containsPersistedFavorite(rhs)
            if lhsStarred != rhsStarred {
                return lhsStarred && !rhsStarred
            }
            if lhs.rssi != rhs.rssi {
                return lhs.rssi > rhs.rssi
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending

        case .signal:
            if lhs.rssi != rhs.rssi {
                return lhs.rssi > rhs.rssi
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending

        case .name:
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending

        case .channel:
            if lhs.channelNumber != rhs.channelNumber {
                return lhs.channelNumber < rhs.channelNumber
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    private var sortMenu: some View {
        @Bindable var navigation = navigation

        return Menu {
            Picker("Sort By", selection: $navigation.sidebarSortMode) {
                ForEach(WiFiSortMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage).tag(mode)
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
                .labelStyle(.iconOnly)
                .font(.caption.weight(.semibold))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Change list sorting")
    }

    private var headerPanel: some View {
        VStack(alignment: .leading, spacing: WiFiBuddyTokens.Spacing.roomy) {
            // Title + sort control
            HStack(alignment: .firstTextBaseline, spacing: WiFiBuddyTokens.Spacing.regular) {
                titleBlock
                Spacer(minLength: 0)
                sortMenu
            }

            // Band selector — sized to content so it sits left-aligned
            // instead of being stretched across the panel.
            bandFilterPicker
                .fixedSize()

            // Headline metrics — visually balanced with a trailing interface
            // summary chip cluster on wider sidebars, wrapping underneath
            // when the column can't hold both on one line.
            overviewSection
        }
        .wifiBuddyPanel()
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 18) {
                SidebarOverviewValue(
                    title: "Visible",
                    value: "\(filteredObservations.count)",
                    tint: .blue
                )
                VerticalMetricDivider(height: 22)
                SidebarOverviewValue(
                    title: "Named",
                    value: "\(namedNetworkCount)",
                    tint: namedNetworkCount == 0 ? .orange : .green
                )
                VerticalMetricDivider(height: 22)
                SidebarOverviewValue(
                    title: "Starred",
                    value: "\(favoriteCount)",
                    tint: .yellow
                )
                Spacer(minLength: 0)
            }

            if let interfaceSummary = wifiScanService.snapshot.interfaceSummary {
                HStack(spacing: 6) {
                    Spacer(minLength: 0)
                    RowChip(text: interfaceSummary.interfaceName)
                    if let code = interfaceSummary.countryCode {
                        RowChip(text: "Region \(code)", tint: .teal)
                    }
                }
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nearby Wi-Fi")
                .font(.title2.weight(.semibold))
            Text(headerSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var isStreaming: Bool {
        switch wifiScanService.snapshot.status {
        case .scanning, .ready:
            return true
        default:
            return false
        }
    }

    private var bandFilterPicker: some View {
        Picker("Band", selection: bindingToSelectedBand) {
            ForEach(WiFiBandFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .frame(maxWidth: 260)
    }

    private var bindingToSelectedBand: Binding<WiFiBandFilter> {
        Binding(
            get: { navigation.selectedBandFilter },
            set: { navigation.selectedBandFilter = $0 }
        )
    }

    private func isFavorite(_ observation: NetworkObservation) -> Bool {
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

    private var permissionCopy: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: permissionCardIcon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(permissionCardTint)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(permissionCardTint.opacity(0.16))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(permissionCardTint.opacity(0.24), lineWidth: 0.5)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(permissionCardTitle)
                    .font(.headline.weight(.semibold))
                Text(permissionCardBody)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var permissionPrimaryAction: some View {
        if isAwaitingPermissionRefresh {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Refreshing…")
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        } else if permissionService.authorizationStatus == .notDetermined {
            Button("Allow Access") {
                permissionService.requestAuthorization()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        } else {
            // Once macOS has recorded a decision for this bundle, re-calling
            // requestAuthorization() is a no-op — so route the user to
            // System Settings where they can flip the toggle.
            Button("Open Settings") {
                openLocationSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private func beginPermissionDrivenRefresh() {
        guard isAwaitingPermissionRefresh == false else { return }
        isAwaitingPermissionRefresh = true
        Task { await wifiScanService.refresh() }
    }
}

private struct SidebarSectionModel: Identifiable {
    let id: String
    let title: String
    let observations: [NetworkObservation]
}

private struct NetworkRowView: View {
    let observation: NetworkObservation
    let isStarred: Bool
    let isCurrentConnection: Bool
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: WiFiBuddyTokens.Spacing.compact) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 6) {
                    Text(observation.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(observation.hasVisibleName ? .primary : .secondary)
                        .lineLimit(1)

                    if isStarred {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("Starred network")
                    }

                    if isCurrentConnection {
                        Image(systemName: "house.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.green)
                            .accessibilityLabel("Currently connected network")
                    }

                    Spacer(minLength: 0)
                }

                // Compact chip row — easier to scan than a `•` separated line
                // and never truncated because chips simply wrap to the next
                // line when the sidebar is narrow.
                ChipFlowLayout(horizontalSpacing: 4, verticalSpacing: 4) {
                    RowChip(text: "Ch \(observation.channelNumber)")
                    RowChip(text: observation.channelWidth.label)
                    RowChip(text: observation.security.shortLabel)
                    if observation.hasVisibleName == false {
                        RowChip(text: "Hidden", tint: .orange)
                    }
                }
            }

            Spacer(minLength: 8)

            TrailingSignalSummary(rssi: observation.rssi, centerFrequencyLabel: observation.centerFrequencyLabel)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: WiFiBuddyTokens.CornerRadius.row, style: .continuous)
                .fill(rowFill)
                .overlay(
                    RoundedRectangle(cornerRadius: WiFiBuddyTokens.CornerRadius.row, style: .continuous)
                        .stroke(rowStroke, lineWidth: 1)
                )
        )
    }

    private var rowFill: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.accentColor.opacity(0.14))
        }
        if isCurrentConnection {
            return AnyShapeStyle(Color.green.opacity(0.07))
        }
        if isStarred {
            return AnyShapeStyle(Color.yellow.opacity(0.07))
        }
        return AnyShapeStyle(Color.primary.opacity(0.03))
    }

    private var rowStroke: Color {
        if isSelected {
            return Color.accentColor.opacity(0.32)
        }
        if isCurrentConnection {
            return Color.green.opacity(0.16)
        }
        if isStarred {
            return Color.yellow.opacity(0.20)
        }
        return Color.primary.opacity(0.05)
    }
}

private struct SidebarOverviewValue: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(tint)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Quiet placeholder used inside the sidebar list panel when no networks
/// exist yet. Mirrors the small spinner macOS ships in File > Open and
/// similar sheets — subtle, centered, no heavy hero imagery.
private struct SidebarIdlePlaceholder: View {
    let status: WiFiEnvironmentStatus

    var body: some View {
        VStack(spacing: 10) {
            if showsSpinner {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var showsSpinner: Bool {
        switch status {
        case .idle, .scanning:
            return true
        default:
            return false
        }
    }

    private var icon: String {
        switch status {
        case .noInterface, .wifiDisabled:
            return "wifi.slash"
        case .failed:
            return "exclamationmark.triangle"
        default:
            return "wifi"
        }
    }

    private var message: LocalizedStringKey {
        switch status {
        case .idle:
            return "Preparing scan…"
        case .scanning:
            return "Scanning nearby networks…"
        case .noInterface:
            return "No Wi-Fi interface"
        case .wifiDisabled:
            return "Wi-Fi is off"
        case .failed:
            return "Scan failed"
        case .ready:
            return "No networks in range"
        }
    }
}
