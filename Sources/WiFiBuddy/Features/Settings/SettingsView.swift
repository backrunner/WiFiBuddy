import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettingsModel.self) private var settings
    @Environment(RegionPolicyService.self) private var regionPolicyService

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            VStack(spacing: 12) {
                scanningCard(settings: settings)
                regionCard(settings: settings)
                languageCard(settings: settings)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(WiFiBuddyChromeBackground())
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 420, idealHeight: 420)
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
                                .fill(Color.primary.opacity(0.06))
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
            SettingsRow(title: "Display Language") {
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

            Text("Changes take effect the next time WiFiBuddy launches.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(tint.opacity(0.14)))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 0) {
                content
            }
        }
        .wifiBuddyPanel(padding: 14)
    }
}

private struct SettingsRow<Control: View>: View {
    let title: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
            control
                .fixedSize()
        }
        .padding(.vertical, 6)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 1)
            .padding(.vertical, 2)
    }
}
