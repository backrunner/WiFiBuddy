import Foundation

enum WiFiBuddyFormatters {
    static func relativeString(for date: Date?) -> String {
        guard let date else { return String(localized: "N/A") }
        let now = Date()
        let clampedDate = min(date, now)
        if now.timeIntervalSince(clampedDate) < 5 {
            return String(localized: "Just now")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: clampedDate, relativeTo: now)
    }

    static func mbps(_ value: Double?) -> String {
        guard let value else { return String(localized: "N/A") }
        return String(format: String(localized: "%.1f Mbps"), value)
    }

    static func milliseconds(_ value: Double?) -> String {
        guard let value else { return String(localized: "N/A") }
        return String(format: String(localized: "%.1f ms"), value)
    }

    static func dbm(_ value: Int?) -> String {
        guard let value else { return String(localized: "N/A") }
        return String(format: String(localized: "%d dBm"), value)
    }

    static func integer(_ value: Int?) -> String {
        guard let value else { return String(localized: "N/A") }
        return "\(value)"
    }
}
