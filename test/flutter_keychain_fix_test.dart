import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_keychain_fix/flutter_keychain_fix.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugin.com.ehangwork/flutter_keychain_fix');

  // In-memory store that simulates the native keychain/keystore.
  final Map<String, String> store = {};

  setUp(() {
    store.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          switch (call.method) {
            case 'configure':
              return null;
            case 'put':
              final key = call.arguments['key'] as String;
              final value = call.arguments['value'] as String;
              store[key] = value;
              return null;
            case 'get':
              final key = call.arguments['key'] as String;
              return store[key]; // null when missing
            case 'remove':
              final key = call.arguments['key'] as String;
              store.remove(key);
              return null;
            case 'clear':
              store.clear();
              return null;
            default:
              throw PlatformException(
                code: 'NOT_IMPLEMENTED',
                message: 'method not implemented',
              );
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  // ---------------------------------------------------------------------------
  // put
  // ---------------------------------------------------------------------------
  group('FlutterKeychainFix.put', () {
    test('stores a string value for a given key', () async {
      await FlutterKeychainFix.put(key: 'token', value: 'abc123');
      expect(store['token'], 'abc123');
    });

    test('overwrites an existing value', () async {
      await FlutterKeychainFix.put(key: 'k', value: 'first');
      await FlutterKeychainFix.put(key: 'k', value: 'second');
      expect(store['k'], 'second');
    });

    test('stores an empty string', () async {
      await FlutterKeychainFix.put(key: 'empty', value: '');
      expect(store['empty'], '');
    });

    test('stores a unicode value', () async {
      const v = '日本語テスト 🔑 àéîõü';
      await FlutterKeychainFix.put(key: 'unicode', value: v);
      expect(store['unicode'], v);
    });

    test('stores a long string (10 000 chars)', () async {
      final v = 'A' * 10000;
      await FlutterKeychainFix.put(key: 'long', value: v);
      expect(store['long'], v);
    });

    test('stores special/punctuation characters', () async {
      const v = r'!@#$%^&*()_+-=[]{}|;:",.<>?/\`~';
      await FlutterKeychainFix.put(key: 'special', value: v);
      expect(store['special'], v);
    });

    test('stores a newline and tab', () async {
      const v = 'line1\nline2\ttabbed';
      await FlutterKeychainFix.put(key: 'whitespace', value: v);
      expect(store['whitespace'], v);
    });

    test('stores a JSON-formatted string', () async {
      const v = '{"user":"alice","token":"abc","active":true}';
      await FlutterKeychainFix.put(key: 'json', value: v);
      expect(store['json'], v);
    });

    test('stores a key whose name contains spaces', () async {
      await FlutterKeychainFix.put(key: 'my key name', value: 'v');
      expect(store['my key name'], 'v');
    });

    test('multiple distinct keys are stored independently', () async {
      await FlutterKeychainFix.put(key: 'a', value: '1');
      await FlutterKeychainFix.put(key: 'b', value: '2');
      await FlutterKeychainFix.put(key: 'c', value: '3');
      expect(store['a'], '1');
      expect(store['b'], '2');
      expect(store['c'], '3');
    });

    test('completes without throwing', () async {
      await expectLater(
        FlutterKeychainFix.put(key: 'k', value: 'v'),
        completes,
      );
    });

    test('surfaces a native write failure instead of completing quietly', () async {
      // A write that fails used to be swallowed natively, so the caller saw success and
      // the next get returned null with nothing to explain the gap. Whatever the native
      // side does, the Dart side must not turn a failure into a silent success.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'put') {
              throw PlatformException(
                code: 'keychain_error',
                message: 'Could not store the value in the Keychain.',
                details: 'errSecParam: the Keychain rejected the query',
              );
            }
            return null;
          });

      await expectLater(
        FlutterKeychainFix.put(key: 'k', value: 'v'),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // get
  // ---------------------------------------------------------------------------
  group('FlutterKeychainFix.get', () {
    test('returns the stored value', () async {
      await FlutterKeychainFix.put(key: 'token', value: 'secret');
      expect(await FlutterKeychainFix.get(key: 'token'), 'secret');
    });

    test('returns null for a key that was never stored', () async {
      expect(await FlutterKeychainFix.get(key: 'ghost'), isNull);
    });

    test('returns the latest value after an overwrite', () async {
      await FlutterKeychainFix.put(key: 'k', value: 'old');
      await FlutterKeychainFix.put(key: 'k', value: 'new');
      expect(await FlutterKeychainFix.get(key: 'k'), 'new');
    });

    test('returns an empty string when stored as empty', () async {
      await FlutterKeychainFix.put(key: 'e', value: '');
      expect(await FlutterKeychainFix.get(key: 'e'), '');
    });

    test('returns unicode characters intact', () async {
      const v = '日本語テスト 🔑 àéîõü';
      await FlutterKeychainFix.put(key: 'u', value: v);
      expect(await FlutterKeychainFix.get(key: 'u'), v);
    });

    test('returns a long string intact', () async {
      final v = 'B' * 10000;
      await FlutterKeychainFix.put(key: 'long', value: v);
      expect(await FlutterKeychainFix.get(key: 'long'), v);
    });

    test('returns correct value for each key when many are stored', () async {
      await FlutterKeychainFix.put(key: 'x', value: 'alpha');
      await FlutterKeychainFix.put(key: 'y', value: 'beta');
      await FlutterKeychainFix.put(key: 'z', value: 'gamma');
      expect(await FlutterKeychainFix.get(key: 'x'), 'alpha');
      expect(await FlutterKeychainFix.get(key: 'y'), 'beta');
      expect(await FlutterKeychainFix.get(key: 'z'), 'gamma');
    });

    test('returns null after the key was removed', () async {
      await FlutterKeychainFix.put(key: 'gone', value: 'present');
      await FlutterKeychainFix.remove(key: 'gone');
      expect(await FlutterKeychainFix.get(key: 'gone'), isNull);
    });

    test('returns null after clear', () async {
      await FlutterKeychainFix.put(key: 'k', value: 'v');
      await FlutterKeychainFix.clear();
      expect(await FlutterKeychainFix.get(key: 'k'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // remove
  // ---------------------------------------------------------------------------
  group('FlutterKeychainFix.remove', () {
    test('removes a key so it no longer exists in the store', () async {
      await FlutterKeychainFix.put(key: 'del', value: 'data');
      await FlutterKeychainFix.remove(key: 'del');
      expect(store.containsKey('del'), isFalse);
    });

    test('get returns null after removal', () async {
      await FlutterKeychainFix.put(key: 'del', value: 'data');
      await FlutterKeychainFix.remove(key: 'del');
      expect(await FlutterKeychainFix.get(key: 'del'), isNull);
    });

    test('removing a non-existent key completes without throwing', () async {
      await expectLater(FlutterKeychainFix.remove(key: 'ghost'), completes);
    });

    test('only removes the specified key, not others', () async {
      await FlutterKeychainFix.put(key: 'keep', value: 'safe');
      await FlutterKeychainFix.put(key: 'del', value: 'bye');
      await FlutterKeychainFix.remove(key: 'del');
      expect(await FlutterKeychainFix.get(key: 'keep'), 'safe');
      expect(await FlutterKeychainFix.get(key: 'del'), isNull);
    });

    test('can re-add a value after its key was removed', () async {
      await FlutterKeychainFix.put(key: 'k', value: 'v1');
      await FlutterKeychainFix.remove(key: 'k');
      await FlutterKeychainFix.put(key: 'k', value: 'v2');
      expect(await FlutterKeychainFix.get(key: 'k'), 'v2');
    });

    test('removes all listed keys correctly', () async {
      for (var i = 0; i < 5; i++) {
        await FlutterKeychainFix.put(key: 'key$i', value: 'val$i');
      }
      for (var i = 0; i < 5; i++) {
        await FlutterKeychainFix.remove(key: 'key$i');
      }
      for (var i = 0; i < 5; i++) {
        expect(await FlutterKeychainFix.get(key: 'key$i'), isNull);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // clear
  // ---------------------------------------------------------------------------
  group('FlutterKeychainFix.clear', () {
    test('removes all stored entries', () async {
      await FlutterKeychainFix.put(key: 'a', value: '1');
      await FlutterKeychainFix.put(key: 'b', value: '2');
      await FlutterKeychainFix.put(key: 'c', value: '3');
      await FlutterKeychainFix.clear();
      expect(store.isEmpty, isTrue);
    });

    test('get returns null for every key after clear', () async {
      await FlutterKeychainFix.put(key: 'a', value: '1');
      await FlutterKeychainFix.put(key: 'b', value: '2');
      await FlutterKeychainFix.clear();
      expect(await FlutterKeychainFix.get(key: 'a'), isNull);
      expect(await FlutterKeychainFix.get(key: 'b'), isNull);
    });

    test('clear on an empty store completes without throwing', () async {
      await expectLater(FlutterKeychainFix.clear(), completes);
    });

    test('can store and retrieve values after clear', () async {
      await FlutterKeychainFix.put(key: 'k', value: 'before');
      await FlutterKeychainFix.clear();
      await FlutterKeychainFix.put(key: 'k', value: 'after');
      expect(await FlutterKeychainFix.get(key: 'k'), 'after');
    });

    test('double clear is idempotent', () async {
      await FlutterKeychainFix.put(key: 'k', value: 'v');
      await FlutterKeychainFix.clear();
      await expectLater(FlutterKeychainFix.clear(), completes);
      expect(store.isEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // configure
  // ---------------------------------------------------------------------------
  group('FlutterKeychainFix.configure', () {
    test('sends correct method name with accessGroup and label', () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            captured = call;
            return null;
          });

      await FlutterKeychainFix.configure(
        accessGroup: 'group.com.example',
        label: 'My App',
      );
      expect(captured?.method, 'configure');
      expect(captured?.arguments['accessGroup'], 'group.com.example');
      expect(captured?.arguments['label'], 'My App');
    });

    test('sends null values when called without arguments', () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            captured = call;
            return null;
          });

      await FlutterKeychainFix.configure();
      expect(captured?.method, 'configure');
      expect(captured?.arguments['accessGroup'], isNull);
      expect(captured?.arguments['label'], isNull);
    });

    test('completes without throwing', () async {
      await expectLater(FlutterKeychainFix.configure(), completes);
    });

    test('configure with only accessGroup sets label to null', () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            captured = call;
            return null;
          });

      await FlutterKeychainFix.configure(accessGroup: 'group.com.example');
      expect(captured?.arguments['accessGroup'], 'group.com.example');
      expect(captured?.arguments['label'], isNull);
    });

    test('configure with only label sets accessGroup to null', () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            captured = call;
            return null;
          });

      await FlutterKeychainFix.configure(label: 'My Credentials');
      expect(captured?.arguments['accessGroup'], isNull);
      expect(captured?.arguments['label'], 'My Credentials');
    });
  });

  // ---------------------------------------------------------------------------
  // method channel contract
  // ---------------------------------------------------------------------------
  group('Method channel contract', () {
    test('put sends correct method name and arguments', () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            captured = call;
            return null;
          });

      await FlutterKeychainFix.put(key: 'myKey', value: 'myValue');
      expect(captured?.method, 'put');
      expect(captured?.arguments['key'], 'myKey');
      expect(captured?.arguments['value'], 'myValue');
    });

    test('get sends correct method name and key argument', () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            captured = call;
            return null;
          });

      await FlutterKeychainFix.get(key: 'myKey');
      expect(captured?.method, 'get');
      expect(captured?.arguments['key'], 'myKey');
    });

    test('remove sends correct method name and key argument', () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            captured = call;
            return null;
          });

      await FlutterKeychainFix.remove(key: 'myKey');
      expect(captured?.method, 'remove');
      expect(captured?.arguments['key'], 'myKey');
    });

    test('clear sends correct method name with no key argument', () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            captured = call;
            return null;
          });

      await FlutterKeychainFix.clear();
      expect(captured?.method, 'clear');
    });

    test('PlatformException from native side propagates to caller', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(
              code: 'NATIVE_ERROR',
              message: 'keychain locked',
            );
          });

      expect(
        () async => await FlutterKeychainFix.get(key: 'k'),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
