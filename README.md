# flutter_keychain_fix

[![pub points](https://img.shields.io/pub/points/flutter_keychain_fix)](https://pub.dev/packages/flutter_keychain_fix)
[![pub likes](https://img.shields.io/pub/likes/flutter_keychain_fix)](https://pub.dev/packages/flutter_keychain_fix)
[![Platform iOS](https://img.shields.io/badge/platform-iOS-000000.svg)](https://flutter.dev)
[![Platform Android](https://img.shields.io/badge/platform-Android-3DDC84.svg)](https://flutter.dev)

Secure string storage for Flutter, backed by the **iOS Keychain** and the **Android
Keystore**. Values are addressed by key, so `get` returns exactly what `put` stored and
nothing else on the device can read it.

> ### This is a maintained fork
>
> `flutter_keychain_fix` began as
> [`flutter_keychain`](https://pub.dev/packages/flutter_keychain) by Jeroen Trappers,
> which upstream no longer maintains. It keeps that package's behaviour and storage
> layout, and continues from there under the `flutter_keychain_fix` name.
>
> Both packages can be installed side by side: their method channels and Android package
> names differ, so both stay registered and neither shadows the other. They do,
> however, **read and write the same entries** — see
> [Using both packages](#using-both-packages) below.
>
> Copyright 2018 Jeroen Trappers, BSD 3-Clause. Also partly based on
> `flutter_secure_storage` by German Saprykin, BSD 3-Clause. See [LICENSE](LICENSE).

## Features

- `put` / `get` / `remove` / `clear` over a simple string key-value API
- iOS Keychain items can be given an **access group**, for sharing with your other apps or
  extensions, and a **label**, so they read nicely in iOS Passwords
- Android values are encrypted with AES-128-CBC under a key that is itself wrapped by an
  RSA-2048 key held in the AndroidKeyStore, so the key material never leaves the device
- Crypto initialisation runs off the main thread, and calls that arrive before it is ready
  are queued rather than dropped

## Requirements

| | |
|---|---|
| Flutter | 3.44 or newer |
| Dart | 3.12 or newer |
| iOS | 15.0 or newer. The plugin's own sources use nothing newer than iOS 12, but Flutter 3.44's generated Swift package requires an app deployment target of 15.0, so that is the effective floor. |
| Android | API 21 or newer (the plugin itself only needs API 18, but Flutter 3.44 requires 21) |

## Installation

```yaml
dependencies:
  flutter_keychain_fix: ^0.0.1
```

```dart
import 'package:flutter_keychain_fix/flutter_keychain_fix.dart';
```

## Usage

```dart
// Store
await FlutterKeychainFix.put(key: 'auth_token', value: 'abc123');

// Read — null when the key was never stored, or on Android when the stored value can
// no longer be decrypted
final token = await FlutterKeychainFix.get(key: 'auth_token');

// Delete one entry
await FlutterKeychainFix.remove(key: 'auth_token');

// Delete every entry
await FlutterKeychainFix.clear();
```

`clear()` on Android preserves the encryption key, so values written afterwards still
encrypt the same way as before.

### iOS access group and label

```dart
await FlutterKeychainFix.configure(
  accessGroup: 'group.com.example.shared', // optional
  label: 'Example App',                    // optional
);
```

Call it before the first `get`, `put`, `remove` or `clear` if you need non-default values.
It is a no-op on Android.

- **`accessGroup`** partitions the store. Items written under one access group are not
  readable under another, so configure the same group before reading values a previous
  call wrote. Sharing requires the App Group entitlement on every app in the group.
- **`label`** only changes how an item appears in iOS Passwords. It is applied when an
  item is created and when an existing one is overwritten, and it is never used to look
  items up — so it is safe to change at any time, and changing it will not hide values
  that were already stored.

## Platform behaviour worth knowing

| | iOS | Android |
|---|---|---|
| Storage | Keychain, `kSecClassGenericPassword` | `SharedPreferences` file with encrypted values |
| Encryption | Handled by the OS | AES-128-CBC, key wrapped by an RSA-2048 KeyStore key |
| `get` on a missing key | `null` | `null` |
| `get` on an unreadable value | `null` | `null` (key rotated or data corrupted) |
| `put` / `remove` / `clear` on a failed write | throws `PlatformException` | throws `PlatformException` |
| `configure` | Sets access group and label | No-op |
| Survives app restart | Yes | Yes |
| Survives uninstall | Keychain items may persist | No |

A write that fails is reported, not logged. `put`, `remove` and `clear` complete only once
the underlying store has confirmed the change; otherwise they throw a `PlatformException`.
This is deliberate: the alternative is a `put` that appears to succeed and a `get` that
later returns `null` with nothing to explain the gap.

On Android, clearing the app's data or reinstalling it deletes the encryption key along
with the values, so anything stored there is unrecoverable afterwards. Keep a recovery
path for anything you cannot afford to lose.

## Migrating from `flutter_keychain`

The API is the same apart from the renamed class, so the change is mechanical:

| `flutter_keychain` | `flutter_keychain_fix` |
|---|---|
| `package:flutter_keychain/flutter_keychain.dart` | `package:flutter_keychain_fix/flutter_keychain_fix.dart` |
| `FlutterKeychain` | `FlutterKeychainFix` |

Already-stored values carry over untouched. The Android `SharedPreferences` file, the
KeyStore alias and the iOS Keychain service are storage addresses that predate the rename,
and this fork keeps all three — which is what makes the migration lossless.

### Using both packages

Import each package under its own name. Their method channels and Android package names
differ, so both remain registered and neither interferes with the other.

They do **not** give you two separate stores. Both packages address the same entries —
`FlutterKeychain` on Android and the `flutter_keychain` Keychain service on iOS — so a
value written through one is visible through the other. That follows from the addresses
being shared; if you genuinely need isolated storage, store the two sets under distinct
keys.

## Example

`example/` is a runnable demo of the whole API.

```bash
cd example
flutter run
```

## Contributing

Issues and pull requests are welcome at
[github.com/ehangwork/flutter_keychain_fix](https://github.com/ehangwork/flutter_keychain_fix).
See [AGENTS.md](AGENTS.md) for the repository conventions, and
[CHANGELOG.md](CHANGELOG.md) for what changed in each release.

## License

BSD 3-Clause. Copyright 2018 Jeroen Trappers. Partly based on `flutter_secure_storage` by
German Saprykin, also BSD 3-Clause. See [LICENSE](LICENSE) for the full text.
