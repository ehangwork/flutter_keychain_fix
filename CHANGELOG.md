# Changelog

## 0.0.2
Fixed README.md.

## 0.0.1

First release.

`flutter_keychain_fix` is a maintained fork of `flutter_keychain` by Jeroen Trappers.

Licensed BSD 3-Clause, © Jeroen Trappers. Also partly based on `flutter_secure_storage` by
German Saprykin, also BSD 3-Clause.

### What this package is called

Everything renamed here is a name, not a stored address. `flutter_keychain` and
`flutter_keychain_fix` can be installed side by side — their method channels and Android
package names differ, so both stay registered and neither shadows the other. They
nonetheless address the same entries, which is exactly why the storage identifiers below
are left alone.

- Dart package `flutter_keychain` → `flutter_keychain_fix`, so the import becomes
  `package:flutter_keychain_fix/flutter_keychain_fix.dart`.
- Dart class `FlutterKeychain` → `FlutterKeychainFix`.
- Native plugin class `FlutterKeychainPlugin` → `FlutterKeychainFixPlugin`, on Android and
  iOS.
- Android package `be.appmire.flutterkeychain` → `com.ehangwork.flutterkeychainfix`; the
  example app id follows as `com.ehangwork.flutterkeychainfix.example`.
- Method channel `plugin.appmire.be/flutter_keychain` →
  `plugin.com.ehangwork/flutter_keychain_fix`.
- iOS CocoaPods pod and Swift package `flutter_keychain_fix`.

### Platform requirements

Requires Flutter 3.44 or newer and Dart 3.12 or newer. The Android side does not apply
`kotlin-android` itself and does not declare its own AGP/KGP classpath, so it inherits the
host application's Gradle setup rather than colliding with it — which is what lets it build
on AGP 9.

### Fixes

Relative to the upstream code this fork was created from:

- iOS: `kSecAttrLabel` is no longer part of the lookup query. It is a display attribute for
  iOS Passwords, and treating it as a filter meant values stored before `configure(label:)`
  became unreadable and survived `clear()` — silently, with no error. `configure(label:)`
  now also updates the label of an existing item, so changing it actually changes how that
  item appears.
- iOS: the Keychain lookup query is built when the plugin is constructed rather than waiting
  for `configure()`. An app that never calls `configure` was writing items with no
  `kSecClass`, which `SecItemAdd` rejects as `errSecParam` — so `put` stored nothing while
  reporting success, and `get` kept returning `null`. Storing worked for anyone who happened
  to call `configure` first, which is what made it look like values surviving a restart or
  not.
- Both platforms: a write that fails is now reported instead of logged. `put`, `remove` and
  `clear` complete only once the underlying store has confirmed the change, and otherwise
  throw a `PlatformException`. The silent case was indistinguishable from a value that was
  never there, on a package whose whole job is telling the two apart.
- Android: `clear()` wipes the preferences file and restores the wrapped AES key in a
  single transaction. The previous two-commit sequence could be interrupted in between,
  losing the key and with it every stored value.
- Android: `AesStringEncryptor` creates its `Cipher` per call. A `Cipher` carries the mode
  and IV it was initialised with, so sharing one instance let concurrent calls overwrite
  each other's state between `init()` and `doFinal()`.
- Android: a failed crypto initialisation no longer leaves every later call queued forever;
  they now return an error instead of hanging.
- Android: the coroutine scope is created on engine attach instead of at construction. It
  used to be cancelled on detach and never replaced, so re-attaching the same plugin
  instance left a dead scope in which every later call hung.

### Build

- Android: all Gradle build scripts migrated to Kotlin DSL (`build.gradle.kts`), which also
  lets the plugin drop its `sourceSets { main.java.srcDirs += 'src/main/kotlin' }` block —
  the Kotlin plugin registers that source directory itself.
- Android: AGP 9.0.1, Gradle 9.1.0, `compileSdk` 36, Java/Kotlin target 17. The redundant
  explicit `kotlin-stdlib` dependency is gone; the Kotlin plugin already contributes it.
- iOS: the implementation is now Swift rather than Objective-C, and the sources live
  under `ios/flutter_keychain_fix/Sources/`, where Flutter requires a plugin's Swift
  package to be. The podspec compiles them from there, so CocoaPods and Swift Package
  Manager build one copy instead of two that could drift apart without either noticing.
- iOS: the Swift package declares its `FlutterFramework` dependency. Without it Flutter
  refused to build the package and printed migration instructions on every build.

### Not changed on purpose

The addresses already-persisted data is written under keep their original values. Renaming
any of them does not corrupt anything — it makes the data unreachable, so reads quietly
return `null` instead of failing:

- Android `SharedPreferences` file name (`FlutterKeychain`) — holds the wrapped AES key and
  every ciphertext.
- Android preferences key for the wrapped AES key (`W0n5hlJtrAH0K8mIreDGxtG`).
- Android KeyStore alias (`<applicationId>.FlutterKeychain`) — holds the RSA key. It
  follows the *application* id rather than the plugin's package name, so upgrading the
  plugin leaves it untouched.
- iOS `kSecAttrService` (`flutter_keychain`) — holds every Keychain item.

These live in a single `StorageIdentifiers` object in the Kotlin plugin, and
`test/storage_identifiers_test.dart` asserts all of them plus the method channel name
across the Dart, Kotlin and Swift sides. `test/ios_addressing_query_test.dart` guards the
related trap: the iOS lookup query has to exist before any call arrives, or the Keychain
rejects every write while the caller is told it succeeded. Change the package, channel or
class names as freely as you like; change those four strings only with a migration in hand.