#!/usr/bin/env swift

import Foundation

private struct Shot {
    let id: String
    let output: String
    let theme: String
    let title: String
    let subtitle: String
    let image: String
    let accent: String
    let variant: String
}

private let canvasWidth = 2880
private let canvasHeight = 1800
private let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let outputDirectory = repoRoot.appendingPathComponent("docs/app-store/screenshots/mac", isDirectory: true)
private let buildDirectory = repoRoot.appendingPathComponent("build/app-store-screenshots", isDirectory: true)

private let shots = [
    Shot(
        id: "light",
        output: "01-light-overview.png",
        theme: "light",
        title: "Visual Wi-Fi scanning",
        subtitle: "See channels, signal strength, and overlap at a glance.",
        image: "docs/screenshots/main.png",
        accent: "#0B84FF",
        variant: "standard"
    ),
    Shot(
        id: "dark",
        output: "02-dark-overview.png",
        theme: "dark",
        title: "Find cleaner channels",
        subtitle: "Compare 2.4 GHz, 5 GHz, and 6 GHz activity in one view.",
        image: "docs/screenshots/main.png",
        accent: "#61D55B",
        variant: "standard"
    ),
    Shot(
        id: "privacy",
        output: "03-private-channel-insight.png",
        theme: "midnight",
        title: "Private by design",
        subtitle: "No account, no analytics SDK, no cloud upload.",
        image: "docs/screenshots/main.png",
        accent: "#16C8D8",
        variant: "privacy"
    )
]

private func fileURLString(_ path: String) -> String {
    repoRoot.appendingPathComponent(path).absoluteString
}

private func escapeHTML(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
}

private func shotMarkup(_ shot: Shot) -> String {
    let logoURL = fileURLString("Sources/WiFiBuddy/Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png")
    let imageURL = fileURLString(shot.image)
    return """
    <section class="shot theme-\(shot.theme) variant-\(shot.variant)" style="--accent: \(shot.accent);">
      <img class="watermark" src="\(logoURL)" alt="">
      <header class="topbar" aria-label="WiFiBuddy">
        <div class="brand">
          <img class="brand-icon" src="\(logoURL)" alt="">
          <span>WiFiBuddy</span>
        </div>
      </header>
      <div class="copy">
        <h1>\(escapeHTML(shot.title))</h1>
        <p>\(escapeHTML(shot.subtitle))</p>
      </div>
      <div class="stage">
        <div class="window-frame">
          <img class="app-shot" src="\(imageURL)" alt="WiFiBuddy app interface">
          <div class="light-wash"></div>
        </div>
      </div>
      <aside class="privacy-stack" aria-hidden="true">
        <div><strong>Local</strong><span>CoreWLAN scan</span></div>
        <div><strong>No account</strong><span>Open and inspect</span></div>
        <div><strong>No upload</strong><span>Your network list stays here</span></div>
      </aside>
    </section>
    """
}

private func html(for shot: Shot) -> String {
    """
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>WiFiBuddy App Store Screenshots</title>
  <style>
    * { box-sizing: border-box; }
    html, body {
      margin: 0;
      width: \(canvasWidth)px;
      min-height: \(canvasHeight)px;
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", sans-serif;
      background: #101316;
      color: #111820;
    }
    body { overflow: hidden; }
    .shot {
      position: relative;
      width: \(canvasWidth)px;
      height: \(canvasHeight)px;
      overflow: hidden;
      isolation: isolate;
    }
    .theme-light {
      --ink: #152129;
      --muted: #46606a;
      --panel: rgba(255, 255, 255, 0.86);
      --stroke: rgba(28, 54, 65, 0.12);
      --shadow: rgba(21, 38, 48, 0.18);
      background:
        radial-gradient(circle at 18% 18%, rgba(11, 132, 255, 0.16), transparent 28%),
        radial-gradient(circle at 88% 18%, rgba(33, 190, 165, 0.13), transparent 28%),
        radial-gradient(circle at 72% 92%, rgba(248, 170, 66, 0.14), transparent 34%),
        linear-gradient(142deg, #fbfdff 0%, #eef7f9 48%, #fff8ec 100%);
    }
    .theme-dark {
      --ink: #f6fbff;
      --muted: #b5c4cc;
      --panel: rgba(18, 23, 27, 0.84);
      --stroke: rgba(255, 255, 255, 0.14);
      --shadow: rgba(0, 0, 0, 0.42);
      background:
        radial-gradient(circle at 18% 16%, rgba(11, 132, 255, 0.28), transparent 25%),
        radial-gradient(circle at 84% 24%, rgba(98, 213, 91, 0.16), transparent 25%),
        radial-gradient(circle at 75% 88%, rgba(245, 166, 35, 0.14), transparent 33%),
        linear-gradient(142deg, #0d1115 0%, #151b1f 48%, #0b0d0f 100%);
    }
    .theme-midnight {
      --ink: #f8fcff;
      --muted: #b4c9d0;
      --panel: rgba(12, 18, 22, 0.86);
      --stroke: rgba(125, 241, 255, 0.20);
      --shadow: rgba(0, 0, 0, 0.48);
      background:
        radial-gradient(circle at 16% 22%, rgba(22, 200, 216, 0.24), transparent 26%),
        radial-gradient(circle at 88% 18%, rgba(11, 132, 255, 0.18), transparent 29%),
        radial-gradient(circle at 68% 96%, rgba(97, 213, 91, 0.12), transparent 33%),
        linear-gradient(142deg, #081014 0%, #12191e 48%, #05080b 100%);
    }
    .shot::before {
      content: "";
      position: absolute;
      inset: 0;
      background-image:
        linear-gradient(rgba(120, 145, 152, 0.10) 1px, transparent 1px),
        linear-gradient(90deg, rgba(120, 145, 152, 0.10) 1px, transparent 1px);
      background-size: 120px 120px;
      mask-image: radial-gradient(circle at 58% 46%, black, transparent 72%);
      opacity: 0.58;
      z-index: -2;
    }
    .watermark {
      position: absolute;
      right: -96px;
      top: -126px;
      width: 1040px;
      height: 1040px;
      opacity: 0.095;
      transform: rotate(-8deg);
      filter: saturate(1.08);
      z-index: -1;
    }
    .topbar {
      position: absolute;
      top: 118px;
      left: 156px;
      right: 156px;
      height: 92px;
      display: flex;
      align-items: center;
      justify-content: flex-end;
    }
    .brand {
      display: inline-flex;
      align-items: center;
      gap: 22px;
      min-height: 92px;
      padding: 10px 0;
      color: var(--ink);
      font-size: 52px;
      line-height: 1;
      font-weight: 760;
      letter-spacing: 0;
    }
    .brand-icon {
      width: 76px;
      height: 76px;
      display: block;
      filter: drop-shadow(0 14px 24px rgba(0, 0, 0, 0.14));
    }
    .copy {
      position: absolute;
      left: 156px;
      top: 210px;
      width: 740px;
      color: var(--ink);
    }
    h1 {
      margin: 0;
      max-width: 740px;
      font-size: 108px;
      line-height: 0.96;
      font-weight: 820;
      letter-spacing: 0;
    }
    p {
      margin: 34px 0 0;
      max-width: 690px;
      font-size: 46px;
      line-height: 1.15;
      font-weight: 560;
      letter-spacing: 0;
      color: var(--muted);
    }
    .stage {
      position: absolute;
      right: 156px;
      bottom: 142px;
      width: 1780px;
      height: 1190px;
    }
    .window-frame {
      position: absolute;
      inset: 0;
      border-radius: 54px;
      background: var(--panel);
      border: 2px solid var(--stroke);
      box-shadow:
        0 48px 110px var(--shadow),
        inset 0 1px 0 rgba(255, 255, 255, 0.24);
      overflow: hidden;
    }
    .app-shot {
      position: absolute;
      left: 0;
      top: 0;
      width: 100%;
      height: 100%;
      object-fit: contain;
      object-position: center center;
      filter: saturate(1.02) contrast(1.02);
    }
    .theme-light .app-shot {
      filter: invert(1) hue-rotate(180deg) saturate(0.76) contrast(0.90) brightness(1.18);
    }
    .light-wash {
      position: absolute;
      inset: 0;
      pointer-events: none;
      background: linear-gradient(180deg, rgba(255,255,255,0.04), rgba(0,0,0,0.02));
      z-index: 3;
    }
    .theme-light .light-wash {
      background:
        linear-gradient(180deg, rgba(255,255,255,0.24), rgba(255,255,255,0.04)),
        radial-gradient(circle at 74% 30%, rgba(11,132,255,0.10), transparent 32%);
      mix-blend-mode: soft-light;
    }
    .variant-privacy .stage {
      right: 204px;
      bottom: 266px;
      width: 1760px;
      height: 1176px;
    }
    .variant-privacy .window-frame {
      border-radius: 48px;
    }
    .variant-privacy .app-shot {
      opacity: 0.94;
    }
    .privacy-stack {
      display: none;
      position: absolute;
      left: 336px;
      right: 336px;
      bottom: 108px;
      grid-template-columns: repeat(3, 1fr);
      gap: 24px;
    }
    .variant-privacy .privacy-stack {
      display: grid;
    }
    .privacy-stack div {
      min-height: 118px;
      border-radius: 24px;
      padding: 24px 28px;
      background: rgba(255, 255, 255, 0.08);
      border: 1px solid rgba(255, 255, 255, 0.14);
      color: var(--ink);
      box-shadow: 0 20px 48px rgba(0, 0, 0, 0.18);
    }
    .privacy-stack strong {
      display: block;
      font-size: 34px;
      line-height: 1;
      font-weight: 780;
      letter-spacing: 0;
    }
    .privacy-stack span {
      display: block;
      margin-top: 12px;
      font-size: 28px;
      line-height: 1.15;
      color: var(--muted);
      font-weight: 560;
      letter-spacing: 0;
    }
  </style>
</head>
<body>
\(shotMarkup(shot))
</body>
</html>
"""
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: buildDirectory, withIntermediateDirectories: true)

for item in try FileManager.default.contentsOfDirectory(at: outputDirectory, includingPropertiesForKeys: nil) where item.pathExtension == "png" {
    try FileManager.default.removeItem(at: item)
}

for shot in shots {
    let htmlURL = buildDirectory.appendingPathComponent("\(shot.id).html")
    let outputURL = outputDirectory.appendingPathComponent(shot.output)
    try html(for: shot).write(to: htmlURL, atomically: true, encoding: .utf8)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [
        "npx",
        "--yes",
        "playwright",
        "screenshot",
        "--viewport-size",
        "\(canvasWidth),\(canvasHeight)",
        "--wait-for-timeout",
        "500",
        htmlURL.absoluteString,
        outputURL.path
    ]
    process.currentDirectoryURL = repoRoot
    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        throw NSError(
            domain: "WiFiBuddyScreenshots",
            code: Int(process.terminationStatus),
            userInfo: [NSLocalizedDescriptionKey: "Playwright render failed for \(shot.output) with status \(process.terminationStatus)"]
        )
    }
}

print("Preview HTML directory: \(buildDirectory.path)")
