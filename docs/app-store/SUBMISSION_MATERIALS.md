# WiFiBuddy App Store Submission Materials

Use this file as the source of truth when completing the macOS App Store
version page in App Store Connect.

## Build Facts

- App name: WiFiBuddy
- Bundle ID: `com.alkinum.wifibuddy`
- SKU: `wifibuddy-macos`
- Platform: macOS
- Minimum macOS version: 14.0
- Category: Utilities
- Current version: 0.2.0
- Build number: 6
- Export compliance: `ITSAppUsesNonExemptEncryption = false`
- Encryption answer: The app does not use non-exempt encryption.
- Location permission reason: macOS requires Core Location permission before
  apps can read Wi-Fi metadata such as SSID, BSSID, and country code.

## App Information

### Name

WiFiBuddy

### Subtitle

Visual Wi-Fi Analyzer

### Category

Utilities

### Content Rights

WiFiBuddy does not contain, show, or access third-party content.

### Age Rating Notes

No objectionable content, user-generated content, web access, gambling,
contests, medical content, or unrestricted social features.

## English Metadata

### Promotional Text

Map nearby Wi-Fi signals, inspect channel overlap, and choose cleaner bands on
your Mac.

### Description

WiFiBuddy is a modern Wi-Fi analyzer for Mac that helps you understand the
wireless networks around you without sending scan data anywhere.

See nearby access points in a live signal map, compare 2.4 GHz, 5 GHz, and
6 GHz channel usage, and open detailed snapshots for signal strength, noise,
SNR, channel width, security, PHY mode, BSSID, frequency, country code, and
scan history.

Highlights:

- Live visual channel map for nearby Wi-Fi networks
- Per-network details including RSSI, noise, SNR, channel width, security, and
  PHY mode
- Region-aware channel recommendations based on the local regulatory domain
- Starred networks for quick follow-up
- Sorting and filtering across visible, named, and favorited networks
- Multilingual interface with ten included localizations
- Private on-device scanning with no analytics SDK and no cloud upload

WiFiBuddy uses CoreWLAN and Core Location on macOS. Location permission is
requested only because macOS gates SSID, BSSID, and country-code Wi-Fi metadata
behind that permission. Scan results are processed locally on your Mac.

### Keywords

wifi,wi-fi,wireless,analyzer,network,signal,channel,scanner,rssi,mac

### What's New

Initial App Store release with live Wi-Fi signal maps, network inspection,
region-aware channel guidance, starred networks, and multilingual support.

## Simplified Chinese Metadata

Use this if you add a `zh-Hans` App Store localization.

### Promotional Text

在 Mac 上查看附近 Wi-Fi 信号、分析信道重叠，并选择更干净的频段。

### Description

WiFiBuddy 是一款为 Mac 打造的现代 Wi-Fi 分析工具，帮助你了解周围无线网络，
同时不会把扫描数据上传到云端。

你可以在实时信号图中查看附近接入点，对比 2.4 GHz、5 GHz 和 6 GHz 频段的信道
占用，并查看每个网络的信号强度、噪声、SNR、信道宽度、安全类型、PHY 模式、
BSSID、频率、国家/地区代码和扫描历史。

亮点：

- 附近 Wi-Fi 网络的实时可视化信道图
- RSSI、噪声、SNR、信道宽度、安全类型和 PHY 模式等详细信息
- 基于本地监管区域的信道建议
- 星标网络，方便持续关注
- 按可见、已命名和已收藏网络排序与筛选
- 内置十种界面语言
- 本机处理扫描数据，无分析 SDK，无云端上传

WiFiBuddy 使用 macOS 的 CoreWLAN 和 Core Location。请求定位权限只是因为
macOS 将 SSID、BSSID 和国家/地区代码等 Wi-Fi 元数据放在定位权限之后。
扫描结果只在你的 Mac 本机处理。

### Keywords

wifi,wi-fi,无线,网络,信号,信道,扫描,分析,频段,mac

### What's New

首次 App Store 发布，包含实时 Wi-Fi 信号图、网络详情、地区信道建议、星标网络
和多语言支持。

## Screenshots

Generated App Store upload files live in:

```text
docs/app-store/screenshots/mac/
```

Upload these macOS screenshots in order:

1. `01-light-overview.png` - Visual Wi-Fi scanning
2. `02-dark-overview.png` - Find cleaner channels
3. `03-private-channel-insight.png` - Private by design

Each generated screenshot is `2880 x 1800` PNG, a 16:10 macOS App Store
screenshot size.

Regenerate them after updating source screenshots:

```bash
Scripts/generate_app_store_screenshots.swift
```

## App Review Notes

WiFiBuddy is a native macOS Wi-Fi analyzer. It uses CoreWLAN to scan nearby
Wi-Fi access points and Core Location only because macOS requires location
permission before exposing Wi-Fi metadata such as SSID, BSSID, and country
code.

The app does not require an account, does not connect to a remote service, does
not upload Wi-Fi scan results, and does not include analytics or advertising
SDKs. If App Review sees hidden SSIDs, that reflects what macOS exposes before
location access is granted or for networks that do not broadcast an SSID.

To test:

1. Launch WiFiBuddy on a Mac with Wi-Fi hardware.
2. Grant location permission if prompted.
3. Use the refresh button to scan nearby networks.
4. Select a signal curve or network row to inspect RSSI, noise, SNR, channel,
   security, PHY, and frequency details.
5. Open Settings to adjust scan interval, region policy, and language.

## Privacy Answers

Suggested App Privacy answers, based on the current codebase:

- Data collected: None.
- Third-party advertising: No.
- Analytics: No.
- Tracking: No.
- Data linked to user: No.
- Data used for tracking: No.

WiFiBuddy reads nearby Wi-Fi metadata locally using macOS APIs. It does not
transmit that information to the developer or any third party.

## Export Compliance Answers

Current binary configuration:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

Suggested answers:

- Does your app use encryption? No, not beyond standard Apple operating system
  functionality.
- Does your app use non-exempt encryption? No.
- Does your app contain proprietary or custom cryptographic algorithms? No.
- Does your app use encryption for VPN, DRM, end-to-end secure messaging, or
  custom secure communications? No.

Re-check this section if the app later adds networking, a custom crypto
library, VPN behavior, encrypted messaging, certificate handling, or cloud sync.

## URLs And Account Fields To Fill

These require the Apple Developer account owner or website owner:

- Support URL: `TODO`
- Marketing URL: optional, `TODO`
- Privacy Policy URL: `TODO`
- Copyright: `TODO`, for example `2026 <Legal Entity Name>`
- App Review contact first name, last name, phone, and email: `TODO`

If you do not have a public website yet, create a simple support/privacy page
before final submission. App Store Connect generally requires a support URL,
and a privacy policy URL is strongly recommended for a public App Store listing.

## Final Submission Checklist

- Confirm `Config/WiFiBuddy-Info.plist` contains
  `ITSAppUsesNonExemptEncryption = false`.
- Run `swift test`.
- Run `bash Scripts/package_app.sh release`.
- Run `bash Scripts/package_testflight.sh validate`.
- Upload the production build with
  `bash Scripts/package_testflight.sh upload --bump-build-number --public-testflight`.
- Wait for App Store Connect build processing.
- Attach the processed build to the macOS version.
- Upload the three screenshots from `docs/app-store/screenshots/mac/`.
- Complete English metadata, privacy answers, age rating, and export compliance.
- Fill the account-specific URLs and App Review contact fields.
- Add App Review notes from this document.
- Submit for review.
