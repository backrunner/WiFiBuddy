import SwiftUI

@main
struct WiFiBuddyApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var navigation = AppNavigationModel()
    @State private var settings = AppSettingsModel()
    @State private var permissionService = WiFiPermissionService()
    @State private var favoritesService = FavoritesService()
    @State private var regionPolicyService = RegionPolicyService()
    @State private var wifiScanService = WiFiScanService()
    @State private var didBootstrap = false

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .withWiFiBuddyDependencies(
                    navigation: navigation,
                    settings: settings,
                    permissionService: permissionService,
                    favoritesService: favoritesService,
                    regionPolicyService: regionPolicyService,
                    wifiScanService: wifiScanService
                )
                .task {
                    guard !didBootstrap else { return }
                    didBootstrap = true
                    await bootstrap()
                }
                .onChange(of: settings.scanInterval) { _, newValue in
                    Task {
                        await wifiScanService.updatePreferences(
                            scanInterval: newValue,
                            includeHidden: settings.includeHiddenNetworks
                        )
                    }
                }
                .onChange(of: settings.includeHiddenNetworks) { _, newValue in
                    Task {
                        await wifiScanService.updatePreferences(
                            scanInterval: settings.scanInterval,
                            includeHidden: newValue
                        )
                    }
                }
                .onChange(of: settings.regionOverrideCode) { _, _ in
                    regionPolicyService.setRegionOverride(settings.regionOverride)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    permissionService.refresh()
                    Task {
                        await wifiScanService.refresh()
                    }
                }
        }
        .defaultSize(width: 1280, height: 780)
        .windowToolbarStyle(.unified(showsTitle: true))
    }

    private func bootstrap() async {
        settings.load()
        regionPolicyService.setRegionOverride(settings.regionOverride)
        permissionService.refresh()
        await favoritesService.load()
        await wifiScanService.updatePreferences(
            scanInterval: settings.scanInterval,
            includeHidden: settings.includeHiddenNetworks
        )
        await wifiScanService.refresh()
        await wifiScanService.startMonitoring()
    }
}
