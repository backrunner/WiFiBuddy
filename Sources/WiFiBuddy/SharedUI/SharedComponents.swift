import SwiftUI

extension View {
    /// Adds a semi-transparent blur fade at the top and bottom of a scroll
    /// container so users get an affordance that more content exists beyond
    /// the viewport. The fade is only rendered on an edge when there is
    /// content to scroll toward that edge (hidden when already pinned). The
    /// overlay is clipped to `cornerRadius` so it never bleeds past the
    /// surrounding panel's rounded corners.
    func wifiBuddyScrollFade(
        edges: Edge.Set = [.top, .bottom],
        height: CGFloat = 36,
        cornerRadius: CGFloat = 0
    ) -> some View {
        modifier(
            WiFiBuddyScrollFadeModifier(
                edges: edges,
                height: height,
                cornerRadius: cornerRadius
            )
        )
    }
}

private struct WiFiBuddyScrollFadeModifier: ViewModifier {
    let edges: Edge.Set
    let height: CGFloat
    let cornerRadius: CGFloat

    @State private var canScrollUp = false
    @State private var canScrollDown = false

    func body(content: Content) -> some View {
        // Overlay layer (clipped to the panel's rounded shape) so the fade
        // rectangles never bleed past the surrounding corners — while the
        // scroll content underneath stays un-clipped and fully visible.
        let fadeOverlay = ZStack {
            if edges.contains(.top), canScrollUp {
                VStack {
                    ScrollEdgeFade(direction: .top)
                        .frame(height: height)
                        .transition(.opacity)
                    Spacer(minLength: 0)
                }
            }
            if edges.contains(.bottom), canScrollDown {
                VStack {
                    Spacer(minLength: 0)
                    ScrollEdgeFade(direction: .bottom)
                        .frame(height: height)
                        .transition(.opacity)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)

        let layered = content
            .overlay { fadeOverlay }
            .animation(.easeInOut(duration: 0.22), value: canScrollUp)
            .animation(.easeInOut(duration: 0.22), value: canScrollDown)

        if #available(macOS 15.0, *) {
            layered
                .onScrollGeometryChange(for: ScrollState.self) { geo in
                    ScrollState(
                        offsetY: geo.contentOffset.y,
                        contentHeight: geo.contentSize.height,
                        viewportHeight: geo.containerSize.height
                    )
                } action: { _, newValue in
                    // Generous dead zones (8pt) so that a single-row
                    // over-scroll or a fade-triggered layout tweak doesn't
                    // oscillate the boolean and flicker the overlay.
                    let atTop = newValue.offsetY <= 8
                    let distanceToBottom = newValue.contentHeight
                        - newValue.viewportHeight
                        - newValue.offsetY
                    let atBottom = distanceToBottom <= 8

                    let scrollable = newValue.contentHeight > newValue.viewportHeight + 4
                    let newUp = scrollable && !atTop
                    let newDown = scrollable && !atBottom

                    if canScrollUp != newUp { canScrollUp = newUp }
                    if canScrollDown != newDown { canScrollDown = newDown }
                }
        } else {
            layered
                .onAppear {
                    canScrollUp = edges.contains(.top)
                    canScrollDown = edges.contains(.bottom)
                }
        }
    }
}

private struct ScrollState: Equatable {
    var offsetY: CGFloat
    var contentHeight: CGFloat
    var viewportHeight: CGFloat
}

private struct ScrollEdgeFade: View {
    enum Direction { case top, bottom }
    let direction: Direction

    var body: some View {
        // Soft haze, never fully opaque — the content should feel like it is
        // dissolving into the panel rather than hitting a dark horizontal
        // bar. Max opacity stays below 0.5 so the edge never reads as a
        // hard line in either light or dark mode.
        let base = Color(nsColor: .windowBackgroundColor)
        let stops: [Gradient.Stop] = direction == .top
            ? [
                .init(color: base.opacity(0.48), location: 0.0),
                .init(color: base.opacity(0.32), location: 0.35),
                .init(color: base.opacity(0.12), location: 0.7),
                .init(color: .clear, location: 1.0)
            ]
            : [
                .init(color: .clear, location: 0.0),
                .init(color: base.opacity(0.12), location: 0.3),
                .init(color: base.opacity(0.32), location: 0.65),
                .init(color: base.opacity(0.48), location: 1.0)
            ]

        LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }
}

extension View {
    func wifiBuddyPanel(padding: CGFloat = WiFiBuddyTokens.Spacing.panelPadding) -> some View {
        modifier(WiFiBuddyGlassPanel(padding: padding, emphasized: false))
    }

    func wifiBuddySidebarPanel(padding: CGFloat = 0) -> some View {
        modifier(WiFiBuddyGlassPanel(padding: padding, emphasized: true))
    }

    func wifiBuddyInsetPanel(padding: CGFloat = WiFiBuddyTokens.Spacing.regular) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: WiFiBuddyTokens.CornerRadius.inset, style: .continuous)
                    .fill(WiFiBuddyTokens.Surface.cardFillEmphasized)
                    .overlay {
                        RoundedRectangle(cornerRadius: WiFiBuddyTokens.CornerRadius.inset, style: .continuous)
                            .fill(WiFiBuddyTokens.Surface.insetFill)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: WiFiBuddyTokens.CornerRadius.inset, style: .continuous)
                            .stroke(WiFiBuddyTokens.Surface.insetStroke, lineWidth: 1)
                    }
            )
    }
}

/// Panel chrome that adopts macOS 26 Liquid Glass when available and falls back to
/// layered regular-material surfaces on older systems. The emphasized variant is
/// used for the sidebar where the panel holds scrolling content.
private struct WiFiBuddyGlassPanel: ViewModifier {
    let padding: CGFloat
    let emphasized: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: WiFiBuddyTokens.CornerRadius.panel, style: .continuous)

        if #available(macOS 26.0, *) {
            // Glass is given a fairly opaque window-background tint so panels
            // don't mirror their neighbors. The inner specular highlight is
            // dampened by the tint color. Stroke stays hairline.
            let tint = Color(nsColor: .windowBackgroundColor)
                .opacity(emphasized ? 0.75 : 0.62)

            return AnyView(
                content
                    .padding(padding)
                    .background {
                        shape.fill(tint)
                    }
                    .glassEffect(.regular, in: shape)
                    .overlay {
                        shape.stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
                    }
            )
        }

        return AnyView(
            content
                .padding(padding)
                .background(
                    shape
                        .fill(.regularMaterial)
                        .overlay {
                            shape.stroke(
                                emphasized
                                    ? WiFiBuddyTokens.Surface.panelStrokeStrong
                                    : WiFiBuddyTokens.Surface.panelStroke,
                                lineWidth: 1
                            )
                        }
                        .shadow(
                            color: WiFiBuddyTokens.Surface.panelShadow.opacity(0.35),
                            radius: 6,
                            x: 0,
                            y: 2
                        )
                )
        )
    }
}

struct CenteredModuleStateView: View {
    let title: String
    let message: String
    let systemImage: String
    var showsProgress = false

    var body: some View {
        GeometryReader { proxy in
            VStack {
                Spacer(minLength: 0)

                VStack(spacing: 14) {
                    Image(systemName: systemImage)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 56, height: 56)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(spacing: 4) {
                        Text(title)
                            .font(.headline.weight(.semibold))
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if showsProgress {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .frame(maxWidth: min(max(proxy.size.width - 40, 240), 460))
                .padding(28)

                Spacer(minLength: 0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WiFiBuddyChromeBackground: View {
    var body: some View {
        ZStack {
            WiFiBuddyTokens.canvasGradient()

            Circle()
                .fill(WiFiBuddyTokens.bandColor(.band5GHz).opacity(0.04))
                .frame(width: 520, height: 520)
                .blur(radius: 80)
                .offset(x: -360, y: -260)

            Circle()
                .fill(WiFiBuddyTokens.bandColor(.band2GHz).opacity(0.03))
                .frame(width: 460, height: 460)
                .blur(radius: 84)
                .offset(x: 360, y: 280)
        }
        .ignoresSafeArea()
    }
}

struct MetricBadge: View {
    let title: String
    let value: String
    var systemImage: String?
    var tint: Color = .accentColor

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle().fill(tint.opacity(0.12))
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.quaternary.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

struct BandBadge: View {
    let band: WiFiBand?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(WiFiBuddyTokens.bandColor(band))
                .frame(width: 6, height: 6)

            Text(band?.title ?? "Unknown")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .foregroundStyle(.primary)
    }
}

struct SignalStrengthMeter: View {
    let rssi: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(index < level ? color : Color.primary.opacity(0.08))
                    .frame(width: 4, height: 6 + CGFloat(index * 3))
            }
        }
        .accessibilityHidden(true)
    }

    private var level: Int {
        switch rssi {
        case -55...0:
            4
        case -67 ..< -55:
            3
        case -75 ..< -67:
            2
        default:
            1
        }
    }

    private var color: Color {
        WiFiBuddyTokens.signalColor(forRSSI: rssi)
    }
}

struct DividerDot: View {
    var body: some View {
        Circle()
            .fill(Color.secondary.opacity(0.35))
            .frame(width: 3, height: 3)
    }
}

struct VerticalMetricDivider: View {
    var height: CGFloat = 20

    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 1, height: height)
    }
}

struct SectionHeadline: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

struct KeyValueLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }
}

struct SectionContainer<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeadline(title: title)
            content
        }
    }
}

struct MutedMetadataLine: View {
    let items: [String]

    var body: some View {
        let filteredItems = items.filter { !$0.isEmpty }

        HStack(spacing: 8) {
            ForEach(Array(filteredItems.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    DividerDot()
                }
                Text(item)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

struct TrailingSignalSummary: View {
    let rssi: Int
    var centerFrequencyLabel: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            SignalStrengthMeter(rssi: rssi)

            VStack(alignment: .trailing, spacing: 1) {
                Text(WiFiBuddyFormatters.dbm(rssi))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()

                if let centerFrequencyLabel {
                    Text(centerFrequencyLabel)
                        .font(.caption2)
                }
            }
            .foregroundStyle(WiFiBuddyTokens.signalColor(forRSSI: rssi))
        }
    }
}

struct FavoriteHighlightTag: View {
    var body: some View {
        Label("Starred", systemImage: "star.fill")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.yellow.opacity(0.14), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.yellow.opacity(0.24), lineWidth: 1)
            )
            .foregroundStyle(.yellow)
    }
}

struct OwnerHighlightTag: View {
    var body: some View {
        Label("Owner", systemImage: "house.fill")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.14), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.green.opacity(0.28), lineWidth: 1)
            )
            .foregroundStyle(.green)
    }
}

/// Small capsule used inside list rows to show channel/width/security.
struct RowChip: View {
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(tint == .secondary ? .secondary : tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(tint == .secondary
                        ? Color.primary.opacity(0.06)
                        : tint.opacity(0.12))
            )
    }
}

/// Minimal left-aligned flow layout so chips wrap onto the next line when the
/// parent width isn't enough — used by the sidebar rows so metadata chips are
/// never truncated, regardless of the sidebar column width.
struct ChipFlowLayout: Layout {
    var horizontalSpacing: CGFloat = 6
    var verticalSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            let newRowWidth = rowWidth == 0 ? size.width : rowWidth + horizontalSpacing + size.width
            if newRowWidth > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + verticalSpacing
                usedWidth = max(usedWidth, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth = newRowWidth
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        usedWidth = max(usedWidth, rowWidth)
        return CGSize(width: min(usedWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
