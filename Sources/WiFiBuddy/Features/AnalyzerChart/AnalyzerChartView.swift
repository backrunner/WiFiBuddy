import SwiftUI

struct AnalyzerChartView: View {
    @Environment(AppNavigationModel.self) private var navigation
    @Environment(WiFiScanService.self) private var wifiScanService
    @Environment(FavoritesService.self) private var favoritesService
    @Environment(RegionPolicyService.self) private var regionPolicyService
    @Environment(\.colorScheme) private var colorScheme

    @State private var hoveredNetworkID: NetworkObservation.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: WiFiBuddyTokens.Spacing.regular) {
            HStack(alignment: .firstTextBaseline, spacing: WiFiBuddyTokens.Spacing.regular) {
                chartHeader
                Spacer(minLength: 0)

                if let hoveredObservation {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(hoveredObservation.displayName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text("Ch \(hoveredObservation.channelNumber) • \(hoveredObservation.centerFrequencyLabel) • \(WiFiBuddyFormatters.dbm(hoveredObservation.rssi))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Group {
                switch wifiScanService.snapshot.status {
                case .noInterface:
                    CenteredModuleStateView(
                        title: "No Wi-Fi Interface",
                        message: "The signal map becomes available once WiFiBuddy can access a Wi-Fi interface.",
                        systemImage: "wifi.slash"
                    )
                case .wifiDisabled:
                    CenteredModuleStateView(
                        title: "Wi-Fi Is Off",
                        message: "Turn Wi-Fi on to populate the channel graph.",
                        systemImage: "wifi.slash"
                    )
                case .failed(let message):
                    CenteredModuleStateView(
                        title: "Signal Map Unavailable",
                        message: message,
                        systemImage: "exclamationmark.triangle"
                    )
                default:
                    if filteredObservations.isEmpty {
                        CenteredModuleStateView(
                            title: "No Visible Networks",
                            message: "Scan again or switch to another frequency filter.",
                            systemImage: "dot.radiowaves.left.and.right"
                        )
                    } else {
                        chartContainer
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .wifiBuddyPanel(padding: 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(minHeight: 0)
    }

    private var chartHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Signal Map")
                .font(.title2.weight(.semibold))

            MutedMetadataLine(items: [
                "\(filteredObservations.count) visible networks",
                favoriteCount > 0 ? "\(favoriteCount) starred" : "",
                activeBandLabel
            ])
        }
    }

    private var filteredObservations: [NetworkObservation] {
        let observations = wifiScanService.snapshot.observations
        guard let band = navigation.selectedBandFilter.band else { return observations }
        return observations.filter { $0.band == band }
    }

    private var hoveredObservation: NetworkObservation? {
        guard let hoveredNetworkID else { return nil }
        return filteredObservations.first { $0.id == hoveredNetworkID }
    }

    private var selectedObservation: NetworkObservation? {
        filteredObservations.first { $0.id == navigation.selectedNetworkID }
    }

    private var favoriteCount: Int {
        filteredObservations.filter(isFavorite(_:)).count
    }

    private var activeBandLabel: String {
        navigation.selectedBandFilter.band?.title ?? "All Bands"
    }

    private var chartContainer: some View {
        GeometryReader { proxy in
            let plot = AnalyzerPlotDescriptor(
                filter: navigation.selectedBandFilter,
                snapshot: wifiScanService.snapshot,
                regionPolicyService: regionPolicyService,
                availableWidth: proxy.size.width
            )
            let plotHeight = max(proxy.size.height - 28, 140)

            Group {
                if plot.axisItems.isEmpty {
                    CenteredModuleStateView(
                        title: "No Supported Channels",
                        message: "This band isn't available for the current region or this scan didn't return any legal channels to plot.",
                        systemImage: "wifi.exclamationmark"
                    )
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .topLeading) {
                            Canvas { context, size in
                                drawBackground(into: context, size: size, plot: plot)
                                drawYAxis(into: context, size: size)
                                drawXAxis(into: context, size: size, plot: plot)
                                drawCurves(into: context, size: size, plot: plot)
                            }
                            .frame(width: plot.width, height: plotHeight)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.primary.opacity(0.03))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                    )
                            )

                            hoverOverlay(plot: plot, height: plotHeight)
                        }

                        Text(chartFootnote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(minHeight: 0)
    }

    private var chartFootnote: String {
        if favoriteCount > 0 {
            return "Starred networks use a gold outline, while the selected curve carries the strongest emphasis."
        }
        return "Hover to preview a network, or click a curve to inspect it."
    }

    private func hoverOverlay(plot: AnalyzerPlotDescriptor, height: CGFloat) -> some View {
        Rectangle()
            .fill(.clear)
            .frame(width: plot.width, height: height)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoveredNetworkID = plot.hitTestNetworkID(
                        to: location,
                        observations: filteredObservations,
                        height: height
                    )
                case .ended:
                    hoveredNetworkID = nil
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        hoveredNetworkID = plot.hitTestNetworkID(
                            to: value.location,
                            observations: filteredObservations,
                            height: height
                        )
                    }
                    .onEnded { value in
                        let hit = plot.hitTestNetworkID(
                            to: value.location,
                            observations: filteredObservations,
                            height: height
                        )
                        hoveredNetworkID = hit
                        if let hit {
                            navigation.selectedNetworkID = hit
                        }
                    }
            )
            .accessibilityLabel("Wi-Fi signal map")
            .accessibilityHint("Hover or click a curve to inspect a network")
    }

    private func drawBackground(into context: GraphicsContext, size: CGSize, plot: AnalyzerPlotDescriptor) {
        for bandRange in plot.bandRanges {
            let color = WiFiBuddyTokens.bandColor(bandRange.band).opacity(colorScheme == .dark ? 0.07 : 0.04)
            let rect = CGRect(
                x: bandRange.startX,
                y: WiFiBuddyTokens.Chart.topInset,
                width: bandRange.endX - bandRange.startX,
                height: size.height - WiFiBuddyTokens.Chart.topInset - WiFiBuddyTokens.Chart.bottomInset
            )
            context.fill(Path(roundedRect: rect, cornerRadius: 12), with: .color(color))
        }

        for item in plot.axisItems {
            var guide = Path()
            guide.move(to: CGPoint(x: item.x, y: WiFiBuddyTokens.Chart.topInset))
            guide.addLine(to: CGPoint(x: item.x, y: size.height - WiFiBuddyTokens.Chart.bottomInset))
            context.stroke(guide, with: .color(Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.04)), lineWidth: 0.6)
        }
    }

    private var chartCanvasFill: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.18)
            : Color.white.opacity(0.55)
    }

    private func drawYAxis(into context: GraphicsContext, size: CGSize) {
        let ticks = [-30.0, -50.0, -67.0, -75.0, -90.0]

        for tick in ticks {
            let y = yPosition(forRSSI: tick, height: size.height)
            var line = Path()
            line.move(to: CGPoint(x: WiFiBuddyTokens.Chart.leadingInset, y: y))
            line.addLine(to: CGPoint(x: size.width - WiFiBuddyTokens.Chart.trailingInset, y: y))
            context.stroke(
                line,
                with: .color(Color.primary.opacity(tick == -67 ? (colorScheme == .dark ? 0.22 : 0.18) : (colorScheme == .dark ? 0.12 : 0.08))),
                lineWidth: tick == -67 ? 1.1 : 0.8
            )

            let text = Text("\(Int(tick))")
                .font(.caption)
                .foregroundStyle(.secondary)
            context.draw(context.resolve(text), at: CGPoint(x: 22, y: y), anchor: .center)
        }
    }

    private func drawXAxis(into context: GraphicsContext, size: CGSize, plot: AnalyzerPlotDescriptor) {
        for item in plot.axisItems where item.isLabeled {
            let text = Text("\(item.channel)")
                .font(.caption)
                .foregroundStyle(.secondary)
            context.draw(
                context.resolve(text),
                at: CGPoint(x: item.x, y: size.height - 16),
                anchor: .center
            )
        }

        for bandRange in plot.bandRanges {
            let title = Text(bandRange.band.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(WiFiBuddyTokens.bandColor(bandRange.band))
            context.draw(
                context.resolve(title),
                at: CGPoint(x: (bandRange.startX + bandRange.endX) / 2, y: 10),
                anchor: .center
            )
        }
    }

    private func drawCurves(into context: GraphicsContext, size: CGSize, plot: AnalyzerPlotDescriptor) {
        // Keep curves inside the chart's drawable area so selected/favourite
        // strokes don't spill over the axis labels or beyond the trailing
        // edge of the chart canvas.
        let chartRect = CGRect(
            x: WiFiBuddyTokens.Chart.leadingInset,
            y: WiFiBuddyTokens.Chart.topInset,
            width: max(0, size.width - WiFiBuddyTokens.Chart.leadingInset - WiFiBuddyTokens.Chart.trailingInset),
            height: max(0, size.height - WiFiBuddyTokens.Chart.topInset - WiFiBuddyTokens.Chart.bottomInset)
        )
        var clipped = context
        clipped.clip(to: Path(roundedRect: chartRect, cornerRadius: 8))

        for observation in filteredObservations {
            guard let centerX = plot.xPosition(for: observation.band, channel: observation.channelNumber) else {
                continue
            }

            let isSelected = observation.id == selectedObservation?.id
            let isFavorite = isFavorite(observation)
            let width = observation.channelWidth.displaySpanInChannelSteps(for: observation.band) * plot.slotWidth
            let peakY = yPosition(forRSSI: Double(observation.rssi), height: size.height)
            let baselineY = yPosition(forRSSI: WiFiBuddyTokens.Chart.floorRSSI, height: size.height)

            var fillPath = Path()
            var strokePath = Path()

            let leftX = centerX - (width / 2)
            let rightX = centerX + (width / 2)
            fillPath.move(to: CGPoint(x: leftX, y: baselineY))
            strokePath.move(to: CGPoint(x: leftX, y: baselineY))

            let sampleCount = 36
            for index in 0...sampleCount {
                let progress = Double(index) / Double(sampleCount)
                let x = leftX + (width * progress)
                let normalized = abs((x - centerX) / (width / 2))
                let attenuation = pow(normalized, 2.2)
                let y = peakY + (baselineY - peakY) * attenuation
                if index == 0 {
                    strokePath.move(to: CGPoint(x: x, y: y))
                } else {
                    strokePath.addLine(to: CGPoint(x: x, y: y))
                }
                fillPath.addLine(to: CGPoint(x: x, y: y))
            }

            fillPath.addLine(to: CGPoint(x: rightX, y: baselineY))
            fillPath.closeSubpath()

            let baseColor = WiFiBuddyTokens.networkColor(for: observation)
            let fillOpacity: Double = isSelected ? 0.16 : (isFavorite ? 0.09 : 0.05)
            let strokeOpacity: Double = isSelected ? 0.98 : (isFavorite ? 0.86 : 0.32)
            let lineWidth: CGFloat = isSelected ? 3.0 : (isFavorite ? 2.4 : 1.3)

            if isFavorite {
                clipped.stroke(
                    strokePath,
                    with: .color(Color.yellow.opacity(isSelected ? 0.36 : 0.24)),
                    lineWidth: lineWidth + 3.4
                )
            }

            if isSelected {
                clipped.stroke(
                    strokePath,
                    with: .color(baseColor.opacity(0.18)),
                    lineWidth: lineWidth + 5.2
                )
            }

            clipped.fill(fillPath, with: .color(baseColor.opacity(fillOpacity)))
            clipped.stroke(strokePath, with: .color(baseColor.opacity(strokeOpacity)), lineWidth: lineWidth)
        }
    }

    private func yPosition(forRSSI rssi: Double, height: CGFloat) -> CGFloat {
        let normalized = max(
            0,
            min(
                1,
                (rssi - WiFiBuddyTokens.Chart.floorRSSI) /
                    (WiFiBuddyTokens.Chart.ceilingRSSI - WiFiBuddyTokens.Chart.floorRSSI)
            )
        )
        let plotHeight = height - WiFiBuddyTokens.Chart.topInset - WiFiBuddyTokens.Chart.bottomInset
        return height - WiFiBuddyTokens.Chart.bottomInset - (plotHeight * CGFloat(normalized))
    }

    private func isFavorite(_ observation: NetworkObservation) -> Bool {
        favoritesService.isFavorite(observation, currentConnection: wifiScanService.snapshot.currentConnection)
    }
}

@MainActor
struct AnalyzerPlotDescriptor {
    struct AxisItem: Identifiable {
        let id: String
        let band: WiFiBand
        let channel: Int
        let x: CGFloat
        let isLabeled: Bool
    }

    struct BandRange {
        let band: WiFiBand
        let startX: CGFloat
        let endX: CGFloat
    }

    let axisItems: [AxisItem]
    let bandRanges: [BandRange]
    let width: CGFloat
    let slotWidth: CGFloat

    init(
        filter: WiFiBandFilter,
        snapshot: WiFiEnvironmentSnapshot,
        regionPolicyService: RegionPolicyService,
        availableWidth: CGFloat
    ) {
        let interfaceCountry = snapshot.interfaceSummary?.countryCode
        let supported = snapshot.interfaceSummary?.supportedChannelsByBand ?? [:]
        let visibleObservations = filter.band.map { selectedBand in
            snapshot.observations.filter { $0.band == selectedBand }
        } ?? snapshot.observations
        let observedBands = Set(visibleObservations.map(\.band))
        let visibleBands = filter.band.map { [$0] } ?? WiFiBand.allCases.filter { observedBands.contains($0) }
        var channelsByBand: [(WiFiBand, [Int])] = []

        for band in visibleBands {
            let observedChannels = Array(Set(
                visibleObservations
                    .filter { $0.band == band }
                    .map(\.channelNumber)
            )).sorted()
            let channels = regionPolicyService.channels(
                for: band,
                interfaceCountry: interfaceCountry,
                networkCountry: nil,
                supportedChannels: supported[band] ?? []
            )
            let effectiveChannels = channels.isEmpty ? observedChannels : channels
            if filter.band == nil, observedChannels.isEmpty {
                continue
            }
            guard !effectiveChannels.isEmpty else { continue }
            channelsByBand.append((band, effectiveChannels))
        }

        let totalChannelCount = channelsByBand.reduce(0) { $0 + $1.1.count }
        let totalGapUnits = CGFloat(max(0, channelsByBand.count - 1)) * WiFiBuddyTokens.Chart.sectionGap
        let totalUnits = CGFloat(totalChannelCount) + totalGapUnits
        let usableWidth = max(
            availableWidth - WiFiBuddyTokens.Chart.leadingInset - WiFiBuddyTokens.Chart.trailingInset,
            80
        )
        let computedSlotWidth = usableWidth / max(totalUnits, 1)

        var currentIndex: CGFloat = 0
        var items: [AxisItem] = []
        var ranges: [BandRange] = []

        for (bandIndex, element) in channelsByBand.enumerated() {
            let (band, effectiveChannels) = element
            let labelStride = max(
                1,
                Int(ceil(WiFiBuddyTokens.Chart.preferredLabelSpacing / max(computedSlotWidth, 1)))
            )
            let rangeStart = WiFiBuddyTokens.Chart.leadingInset + (currentIndex * computedSlotWidth)
            for (channelIndex, channel) in effectiveChannels.enumerated() {
                let x = WiFiBuddyTokens.Chart.leadingInset + (currentIndex * computedSlotWidth)
                let isEdgeChannel = channelIndex == 0 || channelIndex == effectiveChannels.count - 1
                let shouldLabel = effectiveChannels.count <= 14 || isEdgeChannel || channelIndex.isMultiple(of: labelStride)
                items.append(
                    AxisItem(
                        id: "\(band.rawValue)-\(channel)",
                        band: band,
                        channel: channel,
                        x: x,
                        isLabeled: shouldLabel
                    )
                )
                currentIndex += 1
            }
            let rangeEnd = WiFiBuddyTokens.Chart.leadingInset + ((currentIndex - 1) * computedSlotWidth)
            ranges.append(BandRange(band: band, startX: rangeStart - 12, endX: rangeEnd + 12))
            if bandIndex < channelsByBand.count - 1 {
                currentIndex += WiFiBuddyTokens.Chart.sectionGap
            }
        }

        axisItems = items
        bandRanges = ranges
        slotWidth = computedSlotWidth
        width = max(availableWidth, 0)
    }

    func xPosition(for band: WiFiBand, channel: Int) -> CGFloat? {
        axisItems.first { $0.band == band && $0.channel == channel }?.x
    }

    func hitTestNetworkID(
        to location: CGPoint,
        observations: [NetworkObservation],
        height: CGFloat
    ) -> String? {
        var best: (id: String, score: CGFloat, priority: Int)?
        let selectionThreshold = max(12, min(26, slotWidth * 2.8))

        for observation in observations {
            guard let geometry = curveGeometry(for: observation, height: height) else { continue }

            let clampedX = min(max(location.x, geometry.leftX), geometry.rightX)
            let curveY = curveY(
                atX: clampedX,
                centerX: geometry.centerX,
                width: geometry.width,
                peakY: geometry.peakY,
                baselineY: geometry.baselineY
            )

            let horizontalOutside: CGFloat
            if location.x < geometry.leftX {
                horizontalOutside = geometry.leftX - location.x
            } else if location.x > geometry.rightX {
                horizontalOutside = location.x - geometry.rightX
            } else {
                horizontalOutside = 0
            }
            let verticalDistance = abs(location.y - curveY)
            let insideEnvelope = location.x >= geometry.leftX
                && location.x <= geometry.rightX
                && location.y >= curveY
                && location.y <= geometry.baselineY

            let depthRatio: CGFloat
            if insideEnvelope, geometry.baselineY > curveY {
                depthRatio = max(0, min(1, (location.y - curveY) / (geometry.baselineY - curveY)))
            } else {
                depthRatio = 0
            }

            let score = verticalDistance
                + (horizontalOutside * 0.9)
                + (insideEnvelope ? depthRatio * 10 : 8)

            let priority = insideEnvelope ? 0 : 1
            guard insideEnvelope || score <= selectionThreshold else { continue }

            if best == nil
                || priority < best!.priority
                || (priority == best!.priority && score < best!.score) {
                best = (observation.id, score, priority)
            }
        }
        return best?.id
    }

    func curveGeometry(
        for observation: NetworkObservation,
        height: CGFloat
    ) -> CurveGeometry? {
        guard let centerX = xPosition(for: observation.band, channel: observation.channelNumber) else {
            return nil
        }

        let width = observation.channelWidth.displaySpanInChannelSteps(for: observation.band) * slotWidth
        let peakY = yPosition(forRSSI: Double(observation.rssi), height: height)
        let baselineY = yPosition(forRSSI: WiFiBuddyTokens.Chart.floorRSSI, height: height)

        return CurveGeometry(
            centerX: centerX,
            width: width,
            leftX: centerX - (width / 2),
            rightX: centerX + (width / 2),
            peakY: peakY,
            baselineY: baselineY
        )
    }

    func curveY(
        atX x: CGFloat,
        centerX: CGFloat,
        width: CGFloat,
        peakY: CGFloat,
        baselineY: CGFloat
    ) -> CGFloat {
        guard width > 0 else { return baselineY }
        let normalized = abs((x - centerX) / (width / 2))
        let attenuation = pow(Double(normalized), 2.2)
        return peakY + (baselineY - peakY) * CGFloat(attenuation)
    }

    func yPosition(forRSSI rssi: Double, height: CGFloat) -> CGFloat {
        let normalized = max(
            0,
            min(
                1,
                (rssi - WiFiBuddyTokens.Chart.floorRSSI) /
                    (WiFiBuddyTokens.Chart.ceilingRSSI - WiFiBuddyTokens.Chart.floorRSSI)
            )
        )
        let plotHeight = height - WiFiBuddyTokens.Chart.topInset - WiFiBuddyTokens.Chart.bottomInset
        return height - WiFiBuddyTokens.Chart.bottomInset - (plotHeight * CGFloat(normalized))
    }
}

extension AnalyzerPlotDescriptor {
    struct CurveGeometry {
        let centerX: CGFloat
        let width: CGFloat
        let leftX: CGFloat
        let rightX: CGFloat
        let peakY: CGFloat
        let baselineY: CGFloat
    }
}
