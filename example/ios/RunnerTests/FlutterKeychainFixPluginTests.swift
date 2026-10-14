import Flutter
import XCTest
import flutter_keychain_fix

/// XCTest suite for FlutterKeychainFixPlugin.
///
/// SETUP – add this file to a test target in Xcode:
///   1. Open example/ios/Runner.xcworkspace in Xcode.
///   2. File > New > Target > Unit Testing Bundle, name it "RunnerTests".
///      (If RunnerTests already exists, skip this step.)
///   3. Set "Host Application" to "Runner".
///   4. Add this file to the RunnerTests target's "Compile Sources".
///   5. Link the flutter_keychain_fix package into the RunnerTests target so
///      `import flutter_keychain_fix` resolves.
///
/// RUN:
///   Product > Test  (⌘U)
///   or: xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,...'

final class FlutterKeychainFixPluginTests: XCTestCase {

    private var plugin: FlutterKeychainFixPlugin!

    override func setUp() {
        super.setUp()
        plugin = FlutterKeychainFixPlugin()
        plugin.configure(accessGroup: nil, label: nil)
        // Start every test with a clean keychain service.
        _ = invoke("clear")
    }

    override func tearDown() {
        _ = invoke("clear")
        super.tearDown()
    }

    /// Invokes a plugin method and returns its result. All Keychain operations are
    /// synchronous, so the result closure runs before `handle` returns.
    @discardableResult
    private func invoke(_ method: String, _ arguments: [String: Any] = [:]) -> Any? {
        var result: Any?
        plugin.handle(FlutterMethodCall(methodName: method, arguments: arguments)) { result = $0 }
        return result
    }

    // MARK: - put

    func testPut_basicValue_doesNotThrow() {
        XCTAssertNoThrow(invoke("put", ["key": "token", "value": "abc123"]))
    }

    func testPut_returnsNil() {
        XCTAssertNil(invoke("put", ["key": "k", "value": "v"]), "put should return nil")
    }

    func testPut_multipleKeys_storedIndependently() {
        invoke("put", ["key": "k1", "value": "v1"])
        invoke("put", ["key": "k2", "value": "v2"])
        invoke("put", ["key": "k3", "value": "v3"])

        XCTAssertEqual(invoke("get", ["key": "k1"]) as? String, "v1")
        XCTAssertEqual(invoke("get", ["key": "k2"]) as? String, "v2")
        XCTAssertEqual(invoke("get", ["key": "k3"]) as? String, "v3")
    }

    func testPut_overwritesExistingValue() {
        invoke("put", ["key": "k", "value": "old"])
        invoke("put", ["key": "k", "value": "new"])
        XCTAssertEqual(invoke("get", ["key": "k"]) as? String, "new")
    }

    func testPut_emptyStringValue() {
        invoke("put", ["key": "empty", "value": ""])
        XCTAssertEqual(invoke("get", ["key": "empty"]) as? String, "")
    }

    func testPut_unicodeValue() {
        let value = "日本語テスト 🔑 àéîõü"
        invoke("put", ["key": "unicode", "value": value])
        XCTAssertEqual(invoke("get", ["key": "unicode"]) as? String, value)
    }

    func testPut_specialCharactersInValue() {
        let value = "!@#$%^&*()_+-=[]{}|;:\"',.<>?/\\`~"
        invoke("put", ["key": "special", "value": value])
        XCTAssertEqual(invoke("get", ["key": "special"]) as? String, value)
    }

    func testPut_newlinesAndTabsInValue() {
        let value = "line1\nline2\ttabbed\r\nwindows"
        invoke("put", ["key": "whitespace", "value": value])
        XCTAssertEqual(invoke("get", ["key": "whitespace"]) as? String, value)
    }

    func testPut_longValue() {
        let value = String(repeating: "A", count: 10_000)
        invoke("put", ["key": "long", "value": value])
        XCTAssertEqual(invoke("get", ["key": "long"]) as? String, value)
    }

    func testPut_jsonFormattedValue() {
        let value = "{\"user\":\"alice\",\"token\":\"eyJhbGci\",\"roles\":[\"admin\"]}"
        invoke("put", ["key": "json", "value": value])
        XCTAssertEqual(invoke("get", ["key": "json"]) as? String, value)
    }

    func testPut_keyWithSpacesAndSpecialChars() {
        invoke("put", ["key": "my key name!", "value": "val"])
        XCTAssertEqual(invoke("get", ["key": "my key name!"]) as? String, "val")
    }

    func testPut_repeatedOverwrite_onlyLatestValueReturned() {
        for i in 0..<20 {
            invoke("put", ["key": "rotating", "value": "v\(i)"])
        }
        XCTAssertEqual(invoke("get", ["key": "rotating"]) as? String, "v19")
    }

    // MARK: - get

    func testGet_existingKey_returnsStoredValue() {
        invoke("put", ["key": "token", "value": "secret"])
        XCTAssertEqual(invoke("get", ["key": "token"]) as? String, "secret")
    }

    func testGet_nonExistentKey_returnsNil() {
        XCTAssertNil(invoke("get", ["key": "never_stored"]),
                     "get for a missing key must return nil")
    }

    func testGet_afterOverwrite_returnsLatestValue() {
        invoke("put", ["key": "k", "value": "v1"])
        invoke("put", ["key": "k", "value": "v2"])
        XCTAssertEqual(invoke("get", ["key": "k"]) as? String, "v2")
    }

    func testGet_returnsCorrectValueForEachKey() {
        let pairs = ["a": "alpha", "b": "beta", "c": "gamma"]
        for (key, value) in pairs {
            invoke("put", ["key": key, "value": value])
        }
        for (key, expected) in pairs {
            XCTAssertEqual(invoke("get", ["key": key]) as? String, expected,
                           "Wrong value for key '\(key)'")
        }
    }

    // MARK: - remove

    func testRemove_deletesKey() {
        invoke("put", ["key": "del", "value": "bye"])
        invoke("remove", ["key": "del"])
        XCTAssertNil(invoke("get", ["key": "del"]))
    }

    func testRemove_returnsNil() {
        invoke("put", ["key": "del", "value": "bye"])
        XCTAssertNil(invoke("remove", ["key": "del"]), "remove should return nil")
    }

    func testRemove_nonExistentKey_doesNotThrow() {
        XCTAssertNoThrow(invoke("remove", ["key": "ghost"]))
    }

    func testRemove_onlyRemovesSpecifiedKey() {
        invoke("put", ["key": "keep", "value": "safe"])
        invoke("put", ["key": "del", "value": "bye"])
        invoke("remove", ["key": "del"])

        XCTAssertEqual(invoke("get", ["key": "keep"]) as? String, "safe")
        XCTAssertNil(invoke("get", ["key": "del"]))
    }

    func testRemove_canReAddKeyAfterRemoval() {
        invoke("put", ["key": "k", "value": "v1"])
        invoke("remove", ["key": "k"])
        invoke("put", ["key": "k", "value": "v2"])
        XCTAssertEqual(invoke("get", ["key": "k"]) as? String, "v2")
    }

    func testRemove_allKeys_storeIsEmpty() {
        let keys = ["a", "b", "c", "d", "e"]
        for key in keys {
            invoke("put", ["key": key, "value": "v"])
        }
        for key in keys {
            invoke("remove", ["key": key])
        }
        for key in keys {
            XCTAssertNil(invoke("get", ["key": key]),
                         "Key '\(key)' should be nil after removal")
        }
    }

    // MARK: - clear

    func testClear_removesAllEntries() {
        invoke("put", ["key": "a", "value": "1"])
        invoke("put", ["key": "b", "value": "2"])
        invoke("put", ["key": "c", "value": "3"])
        invoke("clear")

        XCTAssertNil(invoke("get", ["key": "a"]))
        XCTAssertNil(invoke("get", ["key": "b"]))
        XCTAssertNil(invoke("get", ["key": "c"]))
    }

    func testClear_returnsNil() {
        invoke("put", ["key": "k", "value": "v"])
        XCTAssertNil(invoke("clear"), "clear should return nil")
    }

    func testClear_emptyStore_doesNotThrow() {
        // setUp already called clear; calling again on an empty store must not throw.
        XCTAssertNoThrow(invoke("clear"))
    }

    func testClear_canStoreManyValuesAfterClear() {
        invoke("put", ["key": "x", "value": "old"])
        invoke("clear")

        let keys = ["p", "q", "r", "s"]
        for key in keys {
            invoke("put", ["key": key, "value": "val_\(key)"])
        }
        for key in keys {
            XCTAssertEqual(invoke("get", ["key": key]) as? String, "val_\(key)")
        }
    }

    func testClear_doubleClear_isIdempotent() {
        invoke("put", ["key": "k", "value": "v"])
        invoke("clear")
        XCTAssertNoThrow(invoke("clear"))
        XCTAssertNil(invoke("get", ["key": "k"]))
    }

    func testClear_partialDataThenClear() {
        // Store some keys, remove one, then clear – nothing should remain.
        invoke("put", ["key": "a", "value": "1"])
        invoke("put", ["key": "b", "value": "2"])
        invoke("remove", ["key": "a"])
        invoke("clear")
        XCTAssertNil(invoke("get", ["key": "b"]))
    }

    // MARK: - configure

    func testConfigure_defaultArgs_returnsNil() {
        XCTAssertNil(invoke("configure"), "configure should return nil")
    }

    func testConfigure_withNullArgs_returnsNil() {
        XCTAssertNil(invoke("configure", ["accessGroup": NSNull(), "label": NSNull()]))
    }

    func testConfigure_withLabel_itemsStillRetrievable() {
        // Reconfigure with a label, then verify basic put/get still works.
        invoke("configure", ["label": "Test Credentials"])
        invoke("put", ["key": "lk", "value": "lv"])
        XCTAssertEqual(invoke("get", ["key": "lk"]) as? String, "lv")
        // Reset for subsequent tests.
        invoke("configure")
    }

    func testConfigure_withAccessGroup_doesNotThrow() {
        // Using an access group requires an entitlement; on simulator without one
        // the put will silently fail. We just verify configure itself does not throw.
        XCTAssertNoThrow(invoke("configure", ["accessGroup": "group.com.ehangwork.test"]))
        // Reset for subsequent tests.
        invoke("configure")
    }

    func testConfigure_labelAfterStore_keepsExistingItemsRetrievable() {
        // The label is a display attribute, not part of the addressing query. Configuring
        // one after values were stored must not filter those values out: this used to
        // silently orphan them, because the label ended up in every search dictionary.
        invoke("put", ["key": "before", "value": "v"])

        invoke("configure", ["label": "Late Label"])

        XCTAssertEqual(invoke("get", ["key": "before"]) as? String, "v",
                       "An item stored before the label was configured must stay readable")

        // Items created afterwards pick up the label and remain on the same addressing key.
        invoke("put", ["key": "after", "value": "w"])
        XCTAssertEqual(invoke("get", ["key": "before"]) as? String, "v")
        XCTAssertEqual(invoke("get", ["key": "after"]) as? String, "w")

        // Reset for subsequent tests.
        invoke("configure")
    }

    func testClear_afterConfigureWithLabel_removesLabelledItems() {
        // clear() must not be narrowed by the label either, otherwise labelled items would
        // survive a clear() and stay on the device.
        invoke("configure", ["label": "Clear Me"])
        invoke("put", ["key": "labelled", "value": "secret"])

        invoke("clear")

        XCTAssertNil(invoke("get", ["key": "labelled"]),
                     "clear() must remove items regardless of the configured label")

        // Reset for subsequent tests.
        invoke("configure")
    }

    // MARK: - Method channel – unimplemented method

    func testHandleMethodCall_unknownMethod_returnsNotImplemented() {
        var result: Any?
        let call = FlutterMethodCall(methodName: "unknownMethod", arguments: [:])
        plugin.handle(call) { result = $0 }

        XCTAssertTrue(result is NSObject && (result as? NSObject) === FlutterMethodNotImplemented,
                      "Unknown methods must return FlutterMethodNotImplemented")
    }
}