# Distribution and Signing

## Local Build

```sh
./scripts/build.sh
```

The app is created at:

```text
build/NetBar.app
```

## DMG Build

```sh
./scripts/package_dmg.sh
```

The DMG is created at:

```text
dist/NetBar.dmg
```

## Signing Modes

The default build uses ad-hoc signing:

```sh
./scripts/build.sh
```

For a Developer ID build:

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build.sh
./scripts/package_dmg.sh
```

## Notarization

For wider distribution, sign with Developer ID and notarize with Apple. The current scripts prepare a signed app and DMG, but they do not submit notarization automatically.

Typical release flow:

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build.sh
./scripts/package_dmg.sh
```

Then submit the DMG using your Apple Developer credentials and staple the result.

## File Provider Metadata Note

Some synced folders can attach Finder or File Provider metadata to `.app` bundles after copying. The build scripts sign and verify in a temporary folder first, then copy the app into `build/`. The DMG packaging step also stages a clean copy before creating the image.
