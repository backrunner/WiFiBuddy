import Foundation

enum WiFiBuddyFormatters {
    static func relativeString(for date: Date?) -> String {
        guard let date else { return "N/A" }
        let now = Date()
        let clampedDate = min(date, now)
        if now.timeIntervalSince(clampedDate) < 5 {
            return "Just now"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: clampedDate, relativeTo: now)
    }

    static func mbps(_ value: Double?) -> String {
        guard let value else { return "N/A" }
        return String(format: "%.1f Mbps", value)
    }

    static func milliseconds(_ value: Double?) -> String {
        guard let value else { return "N/A" }
        return String(format: "%.1f ms", value)
    }

    static func dbm(_ value: Int?) -> String {
        guard let value else { return "N/A" }
        return "\(value) dBm"
    }

    static func integer(_ value: Int?) -> String {
        guard let value else { return "N/A" }
        return "\(value)"
    }
}
