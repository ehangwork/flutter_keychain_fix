import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the values that must stay identical across the Dart, Kotlin and Swift
/// implementations of the plugin.
///
/// Every assertion here exists because one of these strings already drifted once. The
/// failure mode is always the same and never visible: a renamed method channel makes the
/// plugin do nothing at all, and a renamed storage identifier makes every previously
/// stored secret silently unreadable. Neither throws, neither logs, and no unit test on
/// its own can see it — the Dart tests run against a mock channel, so they would keep
/// passing while the real plugin was dead on device.
///
/// Reading the native sources is deliberate. The alternative, copying these literals into
/// the test, just creates a fourth place for them to drift.
///
/// Each check extracts the declared value with a pattern and compares the value, rather
/// than matching source text: formatters reflow long literals across lines, and a test
/// that breaks every time someone reformats is a test that gets deleted.
void main() {
  final packageRoot = Directory.current;

  String read(String relativePath) {
    final file = File('${packageRoot.path}/$relativePath');
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'Expected $relativePath to exist. The guard cannot verify a file it '
          'cannot read, so it must fail rather than pass silently.',
    );
    return file.readAsStringSync();
  }

  /// Returns the first capture group of [pattern], or fails with [what] when absent.
  String? extract(String source, RegExp pattern, String what) {
    final match = pattern.firstMatch(source);
    expect(
      match,
      isNotNull,
      reason:
          'Could not find $what. The pattern may no longer match the source, in '
          'which case this guard is checking nothing.',
    );
    return match!.group(1);
  }

  const kotlinPlugin =
      'android/src/main/kotlin/com/ehangwork/flutterkeychainfix/'
      'FlutterKeychainFixPlugin.kt';
  const swiftPlugin =
      'ios/flutter_keychain_fix/Sources/flutter_keychain_fix/'
      'FlutterKeychainFixPlugin.swift';

  group('method channel is the same on every side', () {
    const channel = 'plugin.com.ehangwork/flutter_keychain_fix';

    test('Dart opens that channel', () {
      final value = extract(
        read('lib/flutter_keychain_fix.dart'),
        RegExp(r"MethodChannel\(\s*'([^']*)'"),
        'the MethodChannel name in lib/flutter_keychain_fix.dart',
      );
      expect(value, channel);
    });

    test('Kotlin answers on that channel', () {
      final value = extract(
        read(kotlinPlugin),
        RegExp(r'CHANNEL_NAME\s*=\s*"([^"]*)"'),
        'CHANNEL_NAME in the Kotlin plugin',
      );
      expect(value, channel);
    });

    test('Swift answers on that channel', () {
      final value = extract(
        read(swiftPlugin),
        RegExp(r'channelName\s*=\s*"([^"]*)"'),
        'channelName in the Swift plugin',
      );
      expect(value, channel);
    });
  });

  group('storage identifiers keep their original values', () {
    // These are the addresses already-persisted data is written under. Renaming any of
    // them orphans that data: reads return null instead of failing loudly.

    test('Android SharedPreferences file name is still "FlutterKeychain"', () {
      final value = extract(
        read(kotlinPlugin),
        RegExp(r'PREFERENCES_NAME\s*=\s*"([^"]*)"'),
        'PREFERENCES_NAME in the Kotlin plugin',
      );
      expect(
        value,
        'FlutterKeychain',
        reason:
            'The preferences file name must not follow the rename, otherwise every '
            'existing install loses its stored values on upgrade.',
      );
    });

    test('Android KeyStore alias suffix is still ".FlutterKeychain"', () {
      final value = extract(
        read(kotlinPlugin),
        RegExp(r'KEY_ALIAS_SUFFIX\s*=\s*"([^"]*)"'),
        'KEY_ALIAS_SUFFIX in the Kotlin plugin',
      );
      expect(
        value,
        '.FlutterKeychain',
        reason:
            'The KeyStore alias must not follow the rename, otherwise the RSA key '
            'becomes unreachable and every stored value is undecryptable.',
      );
    });

    test('wrapped AES key preference key is unchanged', () {
      final value = extract(
        read(kotlinPlugin),
        RegExp(r'WRAPPED_AES_KEY_ITEM\s*=\s*"([^"]*)"'),
        'WRAPPED_AES_KEY_ITEM in the Kotlin plugin',
      );
      expect(value, 'W0n5hlJtrAH0K8mIreDGxtG');
    });

    test('iOS keychain service is still "flutter_keychain"', () {
      final value = extract(
        read(swiftPlugin),
        RegExp(r'keychainService\s*=\s*"([^"]*)"'),
        'keychainService in the Swift plugin',
      );
      expect(
        value,
        'flutter_keychain',
        reason:
            'The keychain service must not follow the rename, otherwise existing '
            'Keychain items become unreachable.',
      );
    });
  });

  group('the Swift sources are not duplicated', () {
    test('there is exactly one plugin implementation', () {
      final implementations = Directory('${packageRoot.path}/ios')
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path)
          .where((p) => p.contains('FlutterKeychainFixPlugin.'))
          .toList();

      expect(
        implementations,
        hasLength(1),
        reason:
            'CocoaPods and Swift Package Manager must compile the same file. A '
            'second copy — a leftover .m next to the .swift, or a mirrored tree — would '
            'drift silently, because neither integration notices the other changing.\n'
            'Found: $implementations',
      );
    });

    test('the implementation is Swift', () {
      expect(read(swiftPlugin), contains('class FlutterKeychainFixPlugin'));
    });

    test('the podspec compiles sources from the Swift package tree', () {
      final value = extract(
        read('ios/flutter_keychain_fix.podspec'),
        RegExp(r"s\.source_files\s*=\s*'([^']*)'"),
        'source_files in the podspec',
      );
      expect(
        value,
        'flutter_keychain_fix/Sources/flutter_keychain_fix/**/*.swift',
      );
    });

    test('the Swift package declares its Flutter dependency', () {
      final manifest = read('ios/flutter_keychain_fix/Package.swift');
      expect(
        manifest,
        contains('.package(name: "FlutterFramework"'),
        reason:
            'Without this Flutter refuses to build the package and prints '
            'migration instructions on every iOS build.',
      );
    });

    test('the Swift package has no Objective-C header settings left over', () {
      final manifest = read('ios/flutter_keychain_fix/Package.swift');
      expect(manifest, isNot(contains('publicHeadersPath')));
      expect(manifest, isNot(contains('cSettings')));
    });
  });
}
