import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppSettingsModel.self) private var settings
    @Environment(RegionPolicyService.self) private var regionPolicyService

    var body: some View {
        @Bindable var settings = settings

        VStack(alignment: .leading, spacing: 16) {
            settingsHeader

            VStack(spacing: 10) {
                appearanceCard(settings: settings)
                scanningCard(settings: settings)
                regionCard(settings: settings)
                languageCard(settings: settings)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 34)
        .frame(width: 540, alignment: .topLeading)
        .background(WiFiBuddyChromeBackground())
        .fixedSize(horizontal: false, vertical: true)
    }

    private var settingsHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Preferences")
                    .font(.title2.weight(.semibold))

                Text("Tune scanning cadence and regulatory behavior for WiFiBuddy.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .controlSize(.regular)
        }
        .padding(.top, 2)
    }

    private func appearanceCard(settings: AppSettingsModel) -> some View {
        @Bindable var settings = settings

        return SettingsCard(
            title: "Appearance",
            systemImage: "circle.lefthalf.filled",
            tint: .indigo
        ) {
            SettingsRow(title: "Theme") {
                Picker("", selection: $settings.appearanceMode) {
                    ForEach(AppAppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 260)
            }
        }
    }

    private func scanningCard(settings: AppSettingsModel) -> some View {
        @Bindable var settings = settings

        return SettingsCard(
            title: "Scanning",
            systemImage: "dot.radiowaves.left.and.right",
            tint: .blue
        ) {
            SettingsRow(title: "Scan Interval") {
                HStack(spacing: 8) {
                    Text("\(Int(settings.scanInterval)) sec")
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                        .frame(minWidth: 58, alignment: .trailing)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.045))
                        )
                    Stepper("", value: $settings.scanInterval, in: 5...60, step: 5)
                        .labelsHidden()
                }
            }

            SettingsDivider()

            SettingsRow(title: "Include Hidden Networks") {
                Toggle("", isOn: $settings.includeHiddenNetworks)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
            }
        }
    }

    private func regionCard(settings: AppSettingsModel) -> some View {
        @Bindable var settings = settings

        return SettingsCard(
            title: "Region & Compliance",
            systemImage: "globe",
            tint: .teal
        ) {
            SettingsRow(title: "Region Override") {
                Picker("", selection: $settings.regionOverrideCode) {
                    Text("Automatic").tag("")
                    ForEach(regionPolicyService.allPolicies()) { policy in
                        Text("\(policy.displayName) (\(policy.countryCode))")
                            .tag(policy.countryCode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(maxWidth: 220)
            }
        }
    }

    private func languageCard(settings: AppSettingsModel) -> some View {
        @Bindable var settings = settings

        return SettingsCard(
            title: "Language",
            systemImage: "character.bubble",
            tint: .purple
        ) {
            SettingsRow(
                title: "Display Language",
                subtitle: "Changes take effect the next time WiFiBuddy launches."
            ) {
                Picker("", selection: $settings.languageCode) {
                    Text("System Default").tag("")
                    Text("English").tag("en")
                    Text("简体中文").tag("zh-Hans")
                    Text("日本語").tag("ja")
                    Text("한국어").tag("ko")
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(maxWidth: 200)
            }
        }
    }
}

private struct SettingsCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(tint.opacity(colorScheme == .dark ? 0.14 : 0.12)))
                Text(title)
                    .font(.headline.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(rowGroupFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(rowGroupStroke, lineWidth: 1)
                    }
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(cardStroke, lineWidth: 1)
                }
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.08 : 0.035),
                    radius: colorScheme == .dark ? 8 : 5,
                    x: 0,
                    y: colorScheme == .dark ? 3 : 2
                )
        )
    }

    private var cardFill: Color {
        colorScheme == .dark
            ? Color(nsColor: .controlBackgroundColor).opacity(0.34)
            : Color.white.opacity(0.92)
    }

    private var cardStroke: Color {
        colorScheme == .dark
            ? Color.primary.opacity(0.10)
            : Color.black.opacity(0.08)
    }

    private var rowGroupFill: Color {
        colorScheme == .dark
            ? Color.primary.opacity(0.035)
            : Color(nsColor: .controlBackgroundColor).opacity(0.58)
    }

    private var rowGroupStroke: Color {
        colorScheme == .dark
            ? Color.primary.opacity(0.06)
            : Color.black.opacity(0.055)
    }
}

private struct SettingsRow<Control: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            control
                .fixedSize()
        }
        .padding(.vertical, subtitle == nil ? 7 : 6)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 1)
            .padding(.vertical, 1)
    }
}
