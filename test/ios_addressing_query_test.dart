import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the two iOS failure modes that cannot be seen from Dart.
///
/// Both are silent. Dart tests run against a mock channel, so they would keep passing
/// while the real plugin wrote nothing at all — and neither failure throws on device
/// either. The plugin is specifically a place where "it worked" and "it silently did
/// nothing" look identical from the outside, so the contract is pinned to the source.
void main() {
  const swiftPlugin =
      'ios/flutter_keychain_fix/Sources/flutter_keychain_fix/'
      'FlutterKeychainFixPlugin.swift';

  String readSwift() {
    final file = File('${Directory.current.path}/$swiftPlugin');
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'Expected $swiftPlugin to exist. A guard that cannot read the file would '
          'pass without checking anything.',
    );
    return file.readAsStringSync();
  }

  group('the plugin can address its own items without being configured', () {
    // Regression: baseQuery defaulted to an empty dictionary and was only ever filled in
    // by configure(). Without a kSecClass, SecItemAdd rejects the write with
    // errSecParam, so nothing was stored — while Dart was told the write succeeded.
    // Declaring the property without a default makes that state unrepresentable, since
    // Swift then refuses to construct the object until the query has been assigned.
    test('baseQuery is declared without an inline default', () {
      final source = readSwift();
      final declaration = RegExp(
        r'private var baseQuery: \[String: Any\](.*)$',
        multiLine: true,
      ).firstMatch(source);

      expect(
        declaration,
        isNotNull,
        reason:
            'Could not find the baseQuery declaration. This guard is checking '
            'nothing if the property has been renamed or restructured.',
      );
      expect(
        declaration!.group(1)!.trim(),
        isEmpty,
        reason:
            'baseQuery must have no default value. An empty default is what made '
            'every unconfigured write fail with errSecParam while reporting success.',
      );
    });

    test('an initializer assigns the addressing query', () {
      final source = readSwift();
      expect(
        RegExp(
          r'init\s*\(\)\s*\{[^}]*baseQuery',
          multiLine: true,
        ).hasMatch(source),
        isTrue,
        reason:
            'The addressing query has to be built before any call arrives. If only '
            'configure() builds it, an app that never configures can neither store '
            'nor find its own values.',
      );
    });

    test('the query that names the storage service also names the item class', () {
      // kSecAttrService alone is not a valid query: SecItemAdd and SecItemCopyMatching
      // both reject it. The two attributes must be set together, in one query.
      final source = readSwift();
      final service = source.indexOf(
        'kSecAttrService as String: keychainService',
      );
      final itemClass = source.indexOf('kSecClassGenericPassword');

      expect(
        service,
        isNot(-1),
        reason:
            'The service is no longer set from the '
            'declared storage identifier.',
      );
      expect(
        itemClass,
        isNot(-1),
        reason: 'kSecClassGenericPassword is missing.',
      );

      expect(
        (service - itemClass).abs(),
        lessThan(500),
        reason:
            'The service and the item class are set far apart in the source. They '
            'have to describe the same query, otherwise a query can reach the '
            'Keychain without kSecClass and be rejected.',
      );
    });
  });

  group('a failed write is reported rather than swallowed', () {
    // The original symptom of the regression above was a demo app printing "stored"
    // while the value was never written. Only surfacing the failure makes the next one
    // visible without a trip to the simulator's Keychain database.
    test('put hands its OSStatus back to the caller', () {
      expect(
        RegExp(
          r'private func put\([^)]*\)\s*->\s*OSStatus\?',
        ).hasMatch(readSwift()),
        isTrue,
        reason:
            'put should return the failing OSStatus (or nil on success) so the '
            'dispatch can act on it.',
      );
    });

    test('the dispatch turns a failing status into an error', () {
      expect(
        RegExp(r'if let status = put\(').hasMatch(readSwift()),
        isTrue,
        reason:
            'The method channel handler must check the status put returned. '
            'Returning nil unconditionally is what made a failed write look '
            'successful.',
      );
    });
  });
}
