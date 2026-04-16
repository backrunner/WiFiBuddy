import SwiftUI

enum WiFiBuddyTokens {
    enum Spacing {
        static let tight: CGFloat = 6
        static let compact: CGFloat = 10
        static let regular: CGFloat = 14
        static let roomy: CGFloat = 20
        static let section: CGFloat = 28
        static let panelPadding: CGFloat = 20
    }

    enum CornerRadius {
        static let panel: CGFloat = 24
        static let row: CGFloat = 14
        static let inset: CGFloat = 16
        static let badge: CGFloat = 999
    }

    enum Surface {
        static let canvasTop = Color(nsColor: .windowBackgroundColor)
        static let canvasBottom = Color(nsColor: .underPageBackgroundColor)
        static let cardFill = Color(nsColor: .controlBackgroundColor).opacity(0.72)
        static let cardFillEmphasized = Color(nsColor: .windowBackgroundColor).opacity(0.88)
        static let insetFill = Color.primary.opacity(0.035)
        static let insetStroke = Color.primary.opacity(0.08)
        static let panelStroke = Color.primary.opacity(0.08)
        static let panelStrokeStrong = Color.primary.opacity(0.14)
        static let panelShadow = Color.black.opacity(0.08)
    }

    enum Sidebar {
        static let minWidth: CGFloat = 280
        static let idealWidth: CGFloat = 320
        static let maxWidth: CGFloat = 360
    }

    enum Chart {
        static let minHeight: CGFloat = 280
        static let preferredHeight: CGFloat = 420
        static let detailReserveHeight: CGFloat = 140
        static let sectionGap: CGFloat = 1.8
        static let preferredLabelSpacing: CGFloat = 44
        static let topInset: CGFloat = 28
        static let bottomInset: CGFloat = 40
        static let leadingInset: CGFloat = 48
        static let trailingInset: CGFloat = 20
        static let floorRSSI = -95.0
        static let ceilingRSSI = -25.0
    }

    static func bandColor(_ band: WiFiBand?) -> Color {
        switch band {
        case .band2GHz:
            .orange
        case .band5GHz:
            .blue
        case .band6GHz:
            .teal
        case nil:
            .secondary
        }
    }

    static func signalColor(forRSSI rssi: Int) -> Color {
        switch rssi {
        case -55...0:
            .green
        case -67 ..< -55:
            .mint
        case -75 ..< -67:
            .orange
        default:
            .red
        }
    }

    static func networkColor(for observation: NetworkObservation) -> Color {
        let seed = stableColorSeed(for: observation.id)
        let hue = Double(seed % 360) / 360.0
        let saturation = 0.60 + (Double((seed / 360) % 12) / 100.0)
        let brightnessBase: Double = switch observation.band {
        case .band2GHz:
            0.94
        case .band5GHz:
            0.90
        case .band6GHz:
            0.86
        }
        let brightness = min(0.98, brightnessBase + (Double((seed / 4096) % 6) / 100.0))

        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    static func canvasGradient() -> LinearGradient {
        LinearGradient(
            colors: [
                Surface.canvasTop,
                Surface.canvasBottom,
                Surface.canvasTop.opacity(0.92)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private static func stableColorSeed(for value: String) -> UInt64 {
        value.utf8.reduce(14_695_981_039_346_656_037 as UInt64) { partialResult, byte in
            (partialResult ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }
}
