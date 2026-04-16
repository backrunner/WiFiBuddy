import CoreLocation
import Observation

@MainActor
@Observable
final class WiFiPermissionService: NSObject, CLLocationManagerDelegate {
    @ObservationIgnored
    private let manager = CLLocationManager()

    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var locationServicesEnabled = CLLocationManager.locationServicesEnabled()

    override init() {
        super.init()
        manager.delegate = self
        refresh()
    }

    var needsAttention: Bool {
        locationServicesEnabled == false
            || authorizationStatus == .notDetermined
            || authorizationStatus == .denied
            || authorizationStatus == .restricted
    }

    func refresh() {
        locationServicesEnabled = CLLocationManager.locationServicesEnabled()
        authorizationStatus = manager.authorizationStatus
    }

    func requestAuthorization() {
        guard locationServicesEnabled else {
            refresh()
            return
        }
        // Always authorization on macOS grants persistent access so the user
        // doesn't get re-prompted every launch and background scans keep the
        // SSID/BSSID/country metadata populated.
        manager.requestAlwaysAuthorization()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.refresh()
        }
    }
}
