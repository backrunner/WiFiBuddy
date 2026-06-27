import Observation
import SwiftUI

enum WiFiBandFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "ALL"
    case band2GHz = "2.4"
    case band5GHz = "5"
    case band6GHz = "6"

    var id: String { rawValue }

    var band: WiFiBand? {
        switch self {
        case .all:
            nil
        case .band2GHz:
            .band2GHz
        case .band5GHz:
            .band5GHz
        case .band6GHz:
            .band6GHz
        }
    }

    var title: String {
        switch self {
        case .all:
            String(localized: "All Bands")
        case .band2GHz, .band5GHz, .band6GHz:
            rawValue
        }
    }
}

enum WiFiSortMode: String, CaseIterable, Identifiable, Sendable {
    case smart
    case signal
    case name
    case channel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smart: String(localized: "Recommended")
        case .signal: String(localized: "Signal Strength")
        case .name: String(localized: "Name (A–Z)")
        case .channel: String(localized: "Channel")
        }
    }

    var systemImage: String {
        switch self {
        case .smart: "sparkles"
        case .signal: "wifi"
        case .name: "textformat"
        case .channel: "number"
        }
    }
}

enum AppAppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(localized: "Follow System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@MainActor
@Observable
final class AppNavigationModel {
    var selectedBandFilter: WiFiBandFilter = .all
    var selectedNetworkID: NetworkObservation.ID?
    var columnVisibility: NavigationSplitViewVisibility = .all
    var isSettingsPresented = false
    var sidebarSortMode: WiFiSortMode = .smart

    func select(_ observation: NetworkObservation?) {
        selectedNetworkID = observation?.id
    }
}

@MainActor
@Observable
final class AppSettingsModel {
    @ObservationIgnored
    private let defaults = UserDefaults.standard

    var scanInterval: Double = 15 {
        didSet { save() }
    }

    var includeHiddenNetworks = false {
        didSet { save() }
    }

    var appearanceMode: AppAppearanceMode = .system {
        didSet { save() }
    }

    var regionOverrideCode = "" {
        didSet { save() }
    }

    /// Empty string ("") means "follow system language"; otherwise a supported
    /// BCP-47 language tag such as "en", "zh-Hans", "zh-Hant", or "pt-BR".
    var languageCode = "" {
        didSet { saveLanguage() }
    }

    var regionOverride: String? {
        regionOverrideCode.normalizedRegionCode
    }

    func load() {
        scanInterval = defaults.object(forKey: "settings.scanInterval") as? Double ?? 15
        includeHiddenNetworks = defaults.object(forKey: "settings.includeHiddenNetworks") as? Bool ?? false
        appearanceMode = AppAppearanceMode(
            rawValue: defaults.string(forKey: "settings.appearanceMode") ?? ""
        ) ?? .system
        regionOverrideCode = defaults.string(forKey: "settings.regionOverrideCode") ?? ""
        languageCode = defaults.string(forKey: "settings.languageCode") ?? ""
    }

    private func save() {
        defaults.set(scanInterval, forKey: "settings.scanInterval")
        defaults.set(includeHiddenNetworks, forKey: "settings.includeHiddenNetworks")
        defaults.set(appearanceMode.rawValue, forKey: "settings.appearanceMode")
        defaults.set(regionOverrideCode, forKey: "settings.regionOverrideCode")
    }

    private func saveLanguage() {
        defaults.set(languageCode, forKey: "settings.languageCode")
        // AppleLanguages at the app-defaults level overrides the inherited
        // system language on the next launch of this bundle.
        if languageCode.isEmpty {
            defaults.removeObject(forKey: "AppleLanguages")
        } else {
            defaults.set([languageCode], forKey: "AppleLanguages")
        }
    }
}
