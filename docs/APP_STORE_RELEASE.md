# App Store Release Guide

This guide describes how to take WiFiBuddy from a local build to App Store
Connect, TestFlight, and final App Store submission. The command-line path uses
`Scripts/package_testflight.sh`, which drives Xcode archive/export with
automatic signing.

## Release Model

WiFiBuddy has one binary distribution path:

```text
Xcode archive -> App Store Connect upload -> TestFlight and/or App Store review
```

There is no separate "App Store binary" script. A build uploaded by
`Scripts/package_testflight.sh upload` can be used for TestFlight testing and,
after App Store Connect processing, selected for an App Store version.

Final submission to App Review is completed in App Store Connect, unless you add
a separate App Store Connect API automation later. The current repository script
builds, validates, and uploads the binary.

## Required Accounts And Records

Before the first upload, make sure these exist:

- Apple Developer Program membership.
- App Store Connect access with permission to upload builds.
- App record for macOS with bundle ID `com.alkinum.wifibuddy`.
- Xcode signed in to the developer account, or an App Store Connect API key.
- `WiFiBuddy.xcodeproj` generated from `project.yml`.
- Automatic signing enabled for the `WiFiBuddy` target.

Generate and open the project:

```bash
bash Scripts/generate_xcode_project.sh
open WiFiBuddy.xcodeproj
```

In Xcode, select `WiFiBuddy > Signing & Capabilities`, enable
`Automatically manage signing`, and select the team that owns
`com.alkinum.wifibuddy`.

## Command Summary

Show the supported release script modes:

```bash
bash Scripts/package_testflight.sh --help
```

Check project and signing context:

```bash
bash Scripts/package_testflight.sh check
```

Create an archive:

```bash
bash Scripts/package_testflight.sh archive
```

Open the archive in Organizer:

```bash
bash Scripts/package_testflight.sh organizer
```

Export locally:

```bash
bash Scripts/package_testflight.sh export
```

Validate with App Store Connect:

```bash
bash Scripts/package_testflight.sh validate
```

Upload to App Store Connect:

```bash
bash Scripts/package_testflight.sh upload
```

Upload and automatically increment the build number:

```bash
bash Scripts/package_testflight.sh upload --bump-build-number --public-testflight
```

## Recommended Release Checklist

Start from a clean working tree for a real release:

```bash
git status --short
```

Run tests and a release build:

```bash
swift test
bash Scripts/package_app.sh release
```

Verify the App Store Connect release path:

```bash
bash Scripts/package_testflight.sh check
bash Scripts/package_testflight.sh archive
bash Scripts/package_testflight.sh validate
```

Upload when validation passes:

```bash
bash Scripts/package_testflight.sh upload --bump-build-number --public-testflight
```

If Xcode has multiple teams, pass the team explicitly:

```bash
DEVELOPMENT_TEAM=TEAMID1234 \
  bash Scripts/package_testflight.sh upload --bump-build-number --public-testflight
```

## Headless Upload

For CI or any machine without an interactive Xcode login, use an App Store
Connect API key:

```bash
DEVELOPMENT_TEAM=TEAMID1234 \
XCODE_AUTH_KEY_PATH=/secure/path/AuthKey_ABC123DEF4.p8 \
XCODE_AUTH_KEY_ID=ABC123DEF4 \
XCODE_AUTH_ISSUER_ID=00000000-0000-0000-0000-000000000000 \
  bash Scripts/package_testflight.sh upload --bump-build-number --public-testflight
```

Keep the `.p8` file outside the repository. Do not commit API keys, signing
certificates, provisioning profiles, or local team configuration.

## Versioning

The scripts read:

```text
version.env
Config/Version.xcconfig
```

Current shape:

```bash
MARKETING_VERSION=0.2.0
BUILD_NUMBER=6
```

Rules:

- `MARKETING_VERSION` is the App Store version, for example `0.2.0`.
- `BUILD_NUMBER` is the App Store Connect build number.
- Each upload for the same marketing version needs a new build number.
- The App Store version created in App Store Connect should match
  `MARKETING_VERSION`.

For a quick re-upload:

```bash
bash Scripts/package_testflight.sh upload --build-number 7 --public-testflight
```

Preview or bump the next build number manually:

```bash
bash Scripts/bump_build_number.sh --dry-run
bash Scripts/bump_build_number.sh
```

For a release tag after the tree is clean:

```bash
bash Scripts/tag_release.sh 0.2.0 --push
```

For a TestFlight beta tag:

```bash
bash Scripts/tag_release.sh 0.2.0-beta.1 --push
```

## App Store Connect Metadata Checklist

Before submitting to App Review, complete the macOS version page in App Store
Connect:

- App name and subtitle.
- Category, currently `Utilities` in the app Info.plist.
- Description, keywords, support URL, marketing URL if used.
- Privacy details and data collection answers.
- Age rating.
- Export compliance answers.
- Screenshots for macOS.
- Localized metadata for the languages the product supports.
- Beta notes or review notes that explain location permission usage.

WiFiBuddy requests location permission because macOS gates SSID, BSSID, and
country-code Wi-Fi metadata behind Core Location. Mention that clearly in App
Review notes.

## TestFlight Release Flow

Upload:

```bash
bash Scripts/package_testflight.sh upload --bump-build-number --public-testflight
```

Then in App Store Connect:

1. Open `Apps > WiFiBuddy > TestFlight`.
2. Wait until the build finishes processing.
3. Add beta release notes.
4. Answer compliance questions.
5. Add the build to internal tester groups.
6. For external testers, submit the build for Beta App Review.
7. Add external tester groups after approval.

For an internal-only build:

```bash
TESTFLIGHT_INTERNAL_ONLY=1 \
  bash Scripts/package_testflight.sh upload --bump-build-number --internal-only
```

Do not use internal-only builds for App Store submission.

For a public TestFlight link, upload with `--public-testflight`, wait for Beta
App Review if required, then enable the public link on the external tester group
inside App Store Connect.

## App Store Submission Flow

Use the same upload command for the production candidate:

```bash
bash Scripts/package_testflight.sh upload --bump-build-number --public-testflight
```

After App Store Connect processing:

1. Open `Apps > WiFiBuddy`.
2. Create or open the macOS version matching `MARKETING_VERSION`.
3. In the `Build` section, choose the uploaded build.
4. Complete all required metadata and compliance sections.
5. Click `Add for Review`.
6. Open the draft submission.
7. Click `Submit for Review`.

Apple may review TestFlight beta builds and App Store submissions separately.
Use the exact build you tested in TestFlight when submitting the final App Store
version whenever possible.

## Organizer Alternative

If you prefer the Xcode UI:

```bash
bash Scripts/package_testflight.sh organizer
```

In Organizer:

1. Select the generated archive.
2. Click `Distribute App`.
3. Choose `TestFlight & App Store`.
4. Choose `Upload`.
5. Keep automatic signing enabled.
6. Keep symbol upload enabled.
7. Upload.

After the upload finishes, continue in App Store Connect using either the
TestFlight or App Store submission flow above.

## Outputs

The release scripts create these local artifacts:

```text
build/WiFiBuddy.app
build/WiFiBuddy.xcarchive
build/testflight/
build/ExportOptions-export.plist
build/ExportOptions-validate.plist
build/ExportOptions-upload.plist
```

`build/WiFiBuddy.xcarchive` is the archive Xcode Organizer can open.

## Recovery Notes

If archive creation fails because the project is missing:

```bash
bash Scripts/generate_xcode_project.sh
```

If signing fails, confirm the team in Xcode and retry with:

```bash
DEVELOPMENT_TEAM=TEAMID1234 \
XCODE_ALLOW_PROVISIONING_UPDATES=1 \
  bash Scripts/package_testflight.sh upload --bump-build-number --public-testflight
```

If upload fails with `exportArchive Error Downloading App Information`, inspect
the Xcode distribution log path printed by the script. A
`missingApp(bundleId: "com.alkinum.wifibuddy")` entry means App Store Connect has
no visible macOS app record for this bundle ID under the selected team/provider.
Create the app record in App Store Connect, or use the team/provider that owns
the existing record, then retry the upload. Automatic signing does not create
the App Store Connect app record.

If App Store Connect rejects the build number, increment `BUILD_NUMBER` and
upload again.

If the build uploads successfully but is not visible yet, wait for App Store
Connect processing and check `TestFlight > Builds`.

## Official References

- [Preparing your app for distribution](https://developer.apple.com/documentation/Xcode/preparing-your-app-for-distribution)
- [Distributing your app for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- [Submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)
- [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview)
