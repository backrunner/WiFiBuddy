import SwiftUI

struct AppShellView: View {
    @Environment(AppNavigationModel.self) private var navigation
    @Environment(WiFiScanService.self) private var wifiScanService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var navigation = navigation

        ZStack {
            WiFiBuddyChromeBackground()

            NavigationSplitView(columnVisibility: $navigation.columnVisibility) {
                SidebarView()
                    .toolbar(removing: .sidebarToggle)
                    .navigationSplitViewColumnWidth(
                        min: WiFiBuddyTokens.Sidebar.minWidth,
                        ideal: WiFiBuddyTokens.Sidebar.idealWidth,
                        max: WiFiBuddyTokens.Sidebar.maxWidth
                    )
            } detail: {
                Group {
                    if let emptyState = detailEmptyState {
                        DetailEmptyStateView(state: emptyState)
                    } else {
                        AdaptiveDetailLayout()
                    }
                }
                .padding(.horizontal, WiFiBuddyTokens.Spacing.regular)
                .padding(.top, detailTopPadding)
                .padding(.bottom, WiFiBuddyTokens.Spacing.regular)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .navigationTitle("WiFiBuddy")
        .navigationSplitViewStyle(.balanced)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .sheet(isPresented: $navigation.isSettingsPresented) {
            SettingsView()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await wifiScanService.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Run a new Wi-Fi scan now")

                Button {
                    navigation.isSettingsPresented = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .help("Open WiFiBuddy settings")
            }
        }
        .onChange(of: wifiScanService.snapshot.observations.map(\.id)) { _, ids in
            // Don't clobber the selection on a momentarily empty scan — the
            // next tick usually restores the same networks. Only pick a new
            // default when the current selection has *actually* disappeared
            // from a non-empty list.
            guard !ids.isEmpty else { return }

            if let selectedID = navigation.selectedNetworkID, ids.contains(selectedID) {
                return
            }

            navigation.selectedNetworkID = DefaultSelectionPolicy.preferredNetworkID(
                in: wifiScanService.snapshot.observations
            )
        }
        .onDisappear {
            wifiScanService.stopMonitoring()
        }
    }

    private var detailTopPadding: CGFloat {
        colorScheme == .light ? 34 : 22
    }

    private var detailEmptyState: DetailEmptyState? {
        // Only the hard-failure states hijack the whole detail column; the
        // day-to-day "scanning / empty" cases are handled by each panel
        // (Signal Map + Inspector) individually so users always see both
        // modules' empty states.
        switch wifiScanService.snapshot.status {
        case .noInterface:
            return DetailEmptyState(
                title: "No Wi-Fi Interface",
                message: "WiFiBuddy couldn't find a Wi-Fi interface on this Mac.",
                systemImage: "wifi.slash"
            )
        case .wifiDisabled:
            return DetailEmptyState(
                title: "Wi-Fi Is Turned Off",
                message: "Turn Wi-Fi back on to populate the analyzer and inspector.",
                systemImage: "wifi.slash"
            )
        case .failed(let message):
            return DetailEmptyState(
                title: "Scan Failed",
                message: message,
                systemImage: "exclamationmark.triangle"
            )
        default:
            return nil
        }
    }
}

private struct AdaptiveDetailLayout: View {
    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 40
            let availableHeight = max(proxy.size.height - spacing, 0)
            // Chart gets a healthy share of the detail canvas but always
            // leaves the inspector at least ~36% of the available height so
            // the two panels never collide visually.
            let chartShare: CGFloat = 0.58
            let proportionalChart = availableHeight * chartShare
            let upperBound = max(availableHeight - WiFiBuddyTokens.Chart.detailReserveHeight, 0)
            let chartHeight = min(
                max(
                    min(proportionalChart, upperBound > 0 ? upperBound : proportionalChart),
                    WiFiBuddyTokens.Chart.minHeight
                ),
                availableHeight * 0.68
            )

            VStack(alignment: .leading, spacing: spacing) {
                AnalyzerChartView()
                    .frame(height: chartHeight)
                    .frame(minHeight: 0)

                InspectorView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .frame(minHeight: 0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct DetailEmptyState {
    let title: String
    let message: String
    let systemImage: String
    var showsProgress = false
}

private struct DetailEmptyStateView: View {
    let state: DetailEmptyState

    var body: some View {
        GeometryReader { proxy in
            VStack {
                Spacer(minLength: 0)

                VStack(spacing: 16) {
                    Image(systemName: state.systemImage)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 64, height: 64)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    VStack(spacing: 6) {
                        Text(state.title)
                            .font(.title3.weight(.semibold))
                        Text(state.message)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if state.showsProgress {
                        ProgressView()
                            .controlSize(.regular)
                    }
                }
                .frame(maxWidth: min(max(proxy.size.width - 48, 240), 520))
                .padding(28)
                .wifiBuddyPanel(padding: 0)

                Spacer(minLength: 0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
