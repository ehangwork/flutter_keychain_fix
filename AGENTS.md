# Repository Guidelines

Conventions for working in this repository. It is a Flutter plugin, so the Dart, Kotlin
and Swift sides all have to agree on the method channel contract.

## What this package is

`flutter_keychain_fix` is a maintained fork of
[`flutter_keychain`](https://pub.dev/packages/flutter_keychain) by Jeroen Trappers (BSD
3-Clause, © Jeroen Trappers; also partly based on `flutter_secure_storage` by German
Saprykin, BSD 3-Clause). Upstream is unmaintained. Behaviour and on-disk layout are
inherited deliberately — see "Storage identifiers" below before changing anything in that
area.

## Project structure

```
flutter_keychain_fix/
├── lib/flutter_keychain_fix.dart          # Dart public API (MethodChannel)
├── test/                                   # Dart tests, incl. cross-platform guards
├── android/src/main/kotlin/com/ehangwork/flutterkeychainfix/
│   └── FlutterKeychainFixPlugin.kt        # AES + RSA/KeyStore, and StorageIdentifiers
├── android/src/test/                       # JVM unit tests (Robolectric)
├── android/src/androidTest/                # on-device tests
├── ios/flutter_keychain_fix/
│   ├── Package.swift                       # Swift Package Manager manifest
│   └── Sources/flutter_keychain_fix/      # the only copy of the Swift sources
├── ios/flutter_keychain_fix.podspec       # CocoaPods manifest, compiles the same sources
├── example/                                # runnable demo app
└── pubspec.yaml
```

The Swift sources live only under `ios/flutter_keychain_fix/Sources/` because that is
where Flutter requires a plugin's Swift package to be. The podspec compiles them from
there too, so CocoaPods and SPM share one copy. Do not add a second copy under `ios/`.

Use `example/` to check behaviour on a real app. Do not commit `build/`,
`example/build/`, `.dart_tool/` or `ios/Pods/`.

## Storage identifiers

Four strings decide where already-persisted secrets live. They are addresses, not names:
renaming any of them does not corrupt data, it makes data unreachable, so `get` quietly
returns `null` and the user simply loses their login state. Nothing throws, nothing logs.

| | Value | Holds |
|---|---|---|
| Android `SharedPreferences` file | `FlutterKeychain` | the wrapped AES key and every ciphertext |
| Android preferences key | `W0n5hlJtrAH0K8mIreDGxtG` | the RSA-wrapped AES key |
| Android KeyStore alias suffix | `.FlutterKeychain` | the RSA key |
| iOS `kSecAttrService` | `flutter_keychain` | every Keychain item |

All three Android values are declared once in the `StorageIdentifiers` object at the top of
`FlutterKeychainFixPlugin.kt`; reference them instead of writing a literal. The iOS service
lives in `KEYCHAIN_SERVICE`.

`test/storage_identifiers_test.dart` reads the Kotlin and Swift sources and asserts all
four values plus the method channel name across Dart, Kotlin and Swift. **Run it after any
rename.** If it fails, the rename is wrong — not the test.

## Build, test, and development commands

Use FVM in this repo; `.fvmrc` pins Flutter `3.44.9`.

```bash
fvm flutter pub get                        # install dependencies
fvm flutter test                           # Dart tests (includes the cross-platform guards)
fvm flutter analyze                        # static analysis
fvm dart format lib test example/lib       # format before review

cd example && fvm flutter run              # launch the demo app
```

The plugin is an Android subproject of the example app, so Android tests must run from
there — the plugin has no standalone Gradle build:

```bash
cd example/android
./gradlew :flutter_keychain_fix:testDebugUnitTest          # JVM unit tests
./gradlew :flutter_keychain_fix:connectedDebugAndroidTest  # on a connected device or emulator
```

iOS XCTest coverage lives in `example/ios/RunnerTests/`. That target has to be wired up in
Xcode manually (see the setup comment at the top of the test file) and has never been run
in CI, so treat it as reference rather than as a passing suite.

## Testing guidelines

Add or update tests with every behaviour change. Dart API tests go in
`test/*_test.dart`; native Android unit tests in `android/src/test/...`; device-dependent
coverage in `android/src/androidTest/...`.

Favour round-trip, null-handling and regression cases for storage and encryption changes.
Dart tests run against a mock method channel, so **they cannot catch a mismatch between
the Dart channel name and the native one** — that is what the cross-platform guard test is
for. Anything that spans Dart, Kotlin and Swift needs a guard on both sides, not just
a mock.

There is no CI. Everything is verified manually before release.

## Coding style

Standard Flutter, Kotlin and Swift style: 2-space indentation in Dart, 4-space in Kotlin
and Swift. `UpperCamelCase` for types, `lowerCamelCase` for members, and test names that
state behaviour (for example `constructor - rotates the stored wrapped key when it cannot be
unwrapped`). Prefer a comment explaining *why* over one restating the code; do not write
implementation traces or unit-conversion tables into comments.

When a guard test inspects source files, extract the declared value with a regular
expression and compare the value rather than matching source text. `dart format` and
ktlint reflow long literals across lines, and a substring assertion breaks every time
someone reformats.

## Security notes

This package stores secrets. Never log stored values, test secrets or keystore material,
including in failing assertions. Do not add analytics, telemetry or network calls.

## Releasing

1. Bump `version` in `pubspec.yaml` and add the matching `CHANGELOG.md` section.
2. Update `s.version` in `ios/flutter_keychain_fix.podspec` to match.
3. `fvm flutter pub publish --dry-run` and resolve anything it reports.
4. Re-run `fvm flutter test`, `fvm flutter analyze`, the APK build and the iOS build.
5. Tag the release in git.

Checklist before publishing:

- [ ] `version` in `pubspec.yaml` and `podspec` agree
- [ ] `homepage` and `repository` point at `ehangwork/flutter_keychain_fix`
- [ ] README API list matches `lib/flutter_keychain_fix.dart`
- [ ] `Storage identifiers` above still matches the code
- [ ] `dart format` reports no changes
