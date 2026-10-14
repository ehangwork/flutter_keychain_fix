import Flutter
import Security

/// Secure string storage backed by the iOS Keychain.
///
/// Behaviour, and more importantly the addresses used to reach already-stored items,
/// are unchanged from the Objective-C implementation this replaced.
@objc public class FlutterKeychainFixPlugin: NSObject, FlutterPlugin {

    // MARK: - Identifiers

    /// Storage identifier, not a brand name: it is the address of every item this plugin
    /// has already written. Renaming it makes existing Keychain entries unreachable, and
    /// because nothing is corrupt nothing reports an error.
    private static let keychainService = "flutter_keychain"

    /// Must stay byte-identical to the channel name in the Dart API and in the Kotlin
    /// plugin. A mismatch fails silently — the Dart future just never completes.
    private static let channelName = "plugin.com.ehangwork/flutter_keychain_fix"

    // MARK: - State

    /// Addressing query: how items are found. `kSecClass` + `kSecAttrService` identify the
    /// store, and `kSecAttrAccessGroup` narrows it to a shared group when configured.
    ///
    /// Set up in `init` rather than defaulted, because an empty query is not a neutral
    /// starting point. `SecItemAdd` rejects a query with no `kSecClass` as `errSecParam`,
    /// so every write would fail while still reporting success, and `get` would keep
    /// returning nil because it was searching the wrong thing.
    private var baseQuery: [String: Any]

    /// Display-only attribute, applied when an item is written so it shows a friendly
    /// name in the iOS Passwords app. Deliberately kept out of `baseQuery`: as a search
    /// filter it would hide every item stored before the label was configured, and
    /// `clear` would leave those items behind forever.
    private var itemLabel: String?

    override init() {
        baseQuery = Self.addressingQuery(accessGroup: nil)
        super.init()
    }

    /// The one place that knows how an item is addressed. Always carries the service, so
    /// an app that never calls `configure` still writes to the same place a later read
    /// looks in.
    private static func addressingQuery(accessGroup: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
        ]
        if let accessGroup, !accessGroup.isEmpty {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    // MARK: - Registration

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(FlutterKeychainFixPlugin(), channel: channel)
    }

    // MARK: - Configuration

    /// Applies optional configuration to subsequent operations.
    ///
    /// - Parameters:
    ///   - accessGroup: `kSecAttrAccessGroup`. The access group partitions the store, so
    ///     items written under one group are not readable under another. Pass nil for the
    ///     default app-specific group.
    ///   - label: `kSecAttrLabel`, shown in iOS Passwords. Pass nil to omit it. Display
    ///     only — never used to look items up, so it can change at any time without hiding
    ///     previously stored values.
    @objc public func configure(accessGroup: String?, label: String?) {
        baseQuery = Self.addressingQuery(accessGroup: accessGroup)
        itemLabel = (label?.isEmpty == false) ? label : nil
    }

    // MARK: - Method channel dispatch

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any]
        // Dart sends NSNull for an absent optional String?.
        func string(_ key: String) -> String? {
            arguments?[key] as? String
        }

        switch call.method {
        case "configure":
            configure(accessGroup: string("accessGroup"), label: string("label"))
            result(nil)
        case "get":
            result(get(string("key")))
        case "put":
            if let status = put(string("value"), forKey: string("key")) {
                result(FlutterError(
                    code: "keychain_error",
                    message: "Could not store the value in the Keychain.",
                    details: Self.describe(status)
                ))
            } else {
                result(nil)
            }
        case "remove":
            remove(string("key"))
            result(nil)
        case "clear":
            clear()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Keychain operations

    /// Returns the failing `OSStatus`, or `nil` when the value was stored.
    private func put(_ value: String?, forKey key: String?) -> OSStatus? {
        guard let value, let key else {
            return errSecParam
        }

        var query = baseQuery
        query[kSecAttrAccount as String] = key
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        let lookupStatus = SecItemCopyMatching(query as CFDictionary, nil)
        query[kSecMatchLimit as String] = nil

        if lookupStatus == errSecSuccess {
            // Item exists - update its data. The label is carried over too, otherwise
            // reconfiguring it would only ever affect items written afterwards and existing
            // ones would keep showing their old name in iOS Passwords.
            var attributes: [String: Any] = [kSecValueData as String: Data(value.utf8)]
            if let itemLabel {
                attributes[kSecAttrLabel as String] = itemLabel
            }
            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            return status == errSecSuccess ? nil : status
        }

        // No existing item - add one. `lookupStatus` is deliberately not narrowed to
        // errSecItemNotFound: on any other failure the add will fail the same way, and
        // reporting that failure beats reporting a success that did not happen.
        query[kSecValueData as String] = Data(value.utf8)
        if let itemLabel {
            query[kSecAttrLabel as String] = itemLabel
        }
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess ? nil : status
    }

    /// Names the `OSStatus` values a caller can actually act on. The raw number is the
    /// only clue that survives, so at least say what it means.
    private static func describe(_ status: OSStatus) -> String {
        switch status {
        case errSecParam:
            return "errSecParam: the Keychain rejected the query, so nothing was written"
        case errSecInteractionNotAllowed:
            return "errSecInteractionNotAllowed: the device is locked"
        case errSecAuthFailed:
            return "errSecAuthFailed: authentication failed"
        case errSecDuplicateItem:
            return "errSecDuplicateItem: an item for that key already exists"
        case errSecItemNotFound:
            return "errSecItemNotFound: no item matched"
        default:
            return "OSStatus \(status)"
        }
    }

    private func get(_ key: String?) -> String? {
        guard let key else { return nil }

        var query = baseQuery
        query[kSecAttrAccount as String] = key
        query[kSecReturnData as String] = kCFBooleanTrue as Any
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        // Swift takes ownership of a Core Foundation reference returned through an out
        // parameter, so there is nothing to release here — CFRelease is rejected by the
        // compiler precisely to prevent the double free it would cause.
        guard status == errSecSuccess, let item else { return nil }
        guard let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func remove(_ key: String?) {
        guard let key else { return }
        var query = baseQuery
        query[kSecAttrAccount as String] = key
        SecItemDelete(query as CFDictionary)
    }

    private func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}