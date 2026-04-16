import SwiftUI

extension View {
    func withWiFiBuddyDependencies(
        navigation: AppNavigationModel,
        settings: AppSettingsModel,
        permissionService: WiFiPermissionService,
        favoritesService: FavoritesService,
        regionPolicyService: RegionPolicyService,
        wifiScanService: WiFiScanService
    ) -> some View {
        environment(navigation)
            .environment(settings)
            .environment(permissionService)
            .environment(favoritesService)
            .environment(regionPolicyService)
            .environment(wifiScanService)
    }
}
