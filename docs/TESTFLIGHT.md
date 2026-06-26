# TestFlight Release Guide

This guide explains how to upload WiFiBuddy builds to App Store Connect for
TestFlight using the repository scripts. The scripts use the generated Xcode
project, Xcode automatic signing, and Xcode's archive/export pipeline.

For the full App Store submission checklist, see
[APP_STORE_RELEASE.md](APP_STORE_RELEASE.md).

## What The Script Does

`Scripts/package_testflight.sh` wraps `xcodebuild` around the `WiFiBuddy`
scheme:

- `check` verifies that `WiFiBuddy.xcodeproj` and the scheme are usable.
- `archive` creates `build/WiFiBuddy.xcarchive`.
- `organizer` creates the archive and opens it in Xcode Organizer.
- `export` exports a local App Store Connect package under `build/testflight/`.
- `validate` validates the archive with App Store Connect.
- `upload` uploads the archive to App Store Connect, where it becomes available
  for TestFlight after Apple finishes processing it.
- `--bump-build-number` increments `BUILD_NUMBER` before archiving.
- `--build-number N` sets a specific build number before archiving.
- `--public-testflight` writes upload options suitable for public/external
  TestFlight.
- `--internal-only` writes upload options for internal-only TestFlight.

The upload is the same binary path used for TestFlight and App Store release.
After the build is uploaded, App Store Connect decides whether you attach it to
a TestFlight group, an App Store version, or both.

## One-Time Setup

Generate the Xcode project if it does not exist:

```bash
bash Scripts/generate_xcode_project.sh
```

Open the project once in Xcode:

```bash
open WiFiBuddy.xcodeproj
```

In Xcode:

1. Select the `WiFiBuddy` target.
2. Open `Signing & Capabilities`.
3. Enable `Automatically manage signing`.
4. Pick the Apple Developer team that owns `com.alkinum.wifibuddy`.
5. Confirm the App Sandbox capability is present and Location is enabled.
6. Confirm App Store Connect has a macOS app record for
   `com.alkinum.wifibuddy`.

Xcode can create or download the required signing assets when your account has
the right role. The release script passes `-allowProvisioningUpdates` by
default, so command-line builds use the same automatic signing machinery as
Organizer.

## Optional Local Team Default

If Xcode has more than one team, create an ignored local signing config:

```bash
cp Config/Signing.local.xcconfig.example Config/Signing.local.xcconfig
```

Edit `Config/Signing.local.xcconfig`:

```xcconfig
DEVELOPMENT_TEAM = TEAMID1234
```

You can also pass the team for a single command:

```bash
DEVELOPMENT_TEAM=TEAMID1234 bash Scripts/package_testflight.sh check
```

Do not commit `Config/Signing.local.xcconfig`.

## Preflight Checks

Run these before uploading a build:

```bash
swift test
bash Scripts/package_app.sh release
bash Scripts/package_testflight.sh check
```

The release build should create:

```text
build/WiFiBuddy.app
```

The TestFlight check should print the project, scheme, version, build number,
and team selection.

## Version And Build Number

The scripts read `version.env`:

```bash
MARKETING_VERSION=0.2.0
BUILD_NUMBER=6
```

Xcode also reads `Config/Version.xcconfig`, which is kept in sync for the
project UI. Every App Store Connect upload must have a build number that has not
already been uploaded for the same marketing version.

For a one-off upload with a specific build number:

```bash
bash Scripts/package_testflight.sh upload --build-number 7 --public-testflight
```

Preview the next build number:

```bash
bash Scripts/bump_build_number.sh --dry-run
```

Increment the build number before a manual Xcode Organizer archive:

```bash
bash Scripts/bump_build_number.sh
```

Set a specific build number:

```bash
bash Scripts/bump_build_number.sh --set 42
```

For a tagged release, commit all changes first, then run:

```bash
bash Scripts/tag_release.sh 0.2.0-beta.1 --push
```

`tag_release.sh` increments `BUILD_NUMBER`, updates both version files, commits
the bump, and creates an annotated git tag.

## Organizer Flow

Use this when you want Xcode to show every distribution step:

```bash
bash Scripts/package_testflight.sh organizer
```

Xcode Organizer opens after the archive is created. In Organizer:

1. Select the new `WiFiBuddy` archive.
2. Click `Distribute App`.
3. Choose `TestFlight & App Store`.
4. Choose `Upload`.
5. Leave automatic signing enabled.
6. Keep symbols enabled.
7. Upload.

This path is closest to pressing Archive and Distribute manually in Xcode.

## CLI Flow With Xcode Account

Use this when Xcode is already signed in to the right Apple Developer account:

```bash
bash Scripts/package_testflight.sh upload --bump-build-number --public-testflight
```

If Xcode needs a specific team:

```bash
DEVELOPMENT_TEAM=TEAMID1234 \
  bash Scripts/package_testflight.sh upload --bump-build-number --public-testflight
```

To validate before upload:

```bash
bash Scripts/package_testflight.sh validate --bump-build-number --public-testflight
bash Scripts/package_testflight.sh upload --public-testflight
```

Output paths:

```text
build/WiFiBuddy.xcarchive
build/testflight/
build/ExportOptions-validate.plist
build/ExportOptions-upload.plist
```

## CLI Flow With App Store Connect API Key

Use this for headless machines or CI where Xcode is not interactively signed in.
Create an App Store Connect API key in App Store Connect, then keep the `.p8`
file outside the repository.

```bash
DEVELOPMENT_TEAM=TEAMID1234 \
XCODE_AUTH_KEY_PATH=/secure/path/AuthKey_ABC123DEF4.p8 \
XCODE_AUTH_KEY_ID=ABC123DEF4 \
XCODE_AUTH_ISSUER_ID=00000000-0000-0000-0000-000000000000 \
  bash Scripts/package_testflight.sh upload --bump-build-number --public-testflight
```

The script also accepts these aliases:

```bash
ASC_API_KEY_PATH=/secure/path/AuthKey_ABC123DEF4.p8
ASC_API_KEY=ABC123DEF4
ASC_API_ISSUER=00000000-0000-0000-0000-000000000000
```

Never commit API keys or private signing material.

## Public TestFlight

Use this path for builds that may be assigned to external groups or a public
TestFlight link:

```bash
bash Scripts/package_testflight.sh upload --bump-build-number --public-testflight
```

`--public-testflight` writes `testFlightInternalTestingOnly=false` into the
generated export options plist. App Store Connect still controls the public link
and external tester groups after upload.

## Internal-Only TestFlight

For a build that should stay internal and never be submitted to App Review:

```bash
TESTFLIGHT_INTERNAL_ONLY=1 \
  bash Scripts/package_testflight.sh upload --bump-build-number --internal-only
```

The script writes `testFlightInternalTestingOnly` into the generated export
options plist.

## After Upload

In App Store Connect:

1. Open `Apps > WiFiBuddy > TestFlight`.
2. Wait for the uploaded build to finish processing.
3. Add beta release notes and required compliance answers.
4. Add the build to an internal testing group.
5. For external testers, submit the build for Beta App Review.
6. Add external groups after the beta build is approved.
7. Enable a public link from the external tester group if desired.

Internal testing is usually available after processing. External testing needs
Apple beta review.

## Troubleshooting

If the script says the project is missing:

```bash
bash Scripts/generate_xcode_project.sh
```

If signing fails, open `WiFiBuddy.xcodeproj`, confirm automatic signing and the
team in `Signing & Capabilities`, then retry:

```bash
DEVELOPMENT_TEAM=TEAMID1234 bash Scripts/package_testflight.sh upload
```

If upload fails with `exportArchive Error Downloading App Information`, open the
Xcode distribution log path printed by the script. When the log contains
`missingApp(bundleId: "com.alkinum.wifibuddy")` or an empty
`AppStoreConnectAppsResponse`, App Store Connect cannot see an app record for
that bundle ID under the selected team/provider. Create the macOS app record in
App Store Connect with bundle ID `com.alkinum.wifibuddy`, or switch Xcode to the
team that owns the existing record, then retry:

```bash
DEVELOPMENT_TEAM=TEAMID1234 \
  bash Scripts/package_testflight.sh upload --public-testflight
```

Xcode automatic signing can create or update signing assets, but the App Store
Connect app record must exist before upload.

If App Store Connect rejects a duplicate build number, increment
`BUILD_NUMBER` and upload again:

```bash
bash Scripts/package_testflight.sh upload --bump-build-number --public-testflight
```

Or set an explicit replacement build number:

```bash
bash Scripts/package_testflight.sh upload --build-number 8 --public-testflight
```

If validation passes but upload does not appear in App Store Connect, wait for
processing first, then check `Apps > WiFiBuddy > TestFlight > Builds`.

## Official References

- [Distributing your app for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview)
- [App Store Connect Help](https://developer.apple.com/help/app-store-connect/)
