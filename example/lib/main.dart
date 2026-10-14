import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_keychain_fix/flutter_keychain_fix.dart';

void main() => runApp(const ExampleApp());

/// Demo shell.
///
/// Each button on the home screen maps to exactly one method of
/// [FlutterKeychainFix], and every call reports what came back, so the example doubles
/// as a way to try each method and see its result.
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_keychain_fix',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const KeychainPage(),
    );
  }
}

/// The key this page reads and writes. A real app would use keys such as `auth_token`;
/// one fixed key keeps the demo readable.
const _demoKey = 'demo_key';

/// One line in the activity list.
class _Entry {
  const _Entry(this.text, {this.isError = false});

  final String text;
  final bool isError;
}

class KeychainPage extends StatefulWidget {
  const KeychainPage({super.key});

  @override
  State<KeychainPage> createState() => _KeychainPageState();
}

class _KeychainPageState extends State<KeychainPage> {
  final _valueController = TextEditingController(text: 'hello world');
  final _labelController = TextEditingController();

  final List<_Entry> _entries = [];
  String? _stored;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Show what is already there, so the page is useful before anything is tapped.
    WidgetsBinding.instance.addPostFrameCallback((_) => _read(silent: true));
  }

  @override
  void dispose() {
    _valueController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  /// Runs [body], then prepends one line describing the outcome.
  ///
  /// Platform failures surface as [PlatformException] and an unregistered plugin as
  /// [MissingPluginException]; both are reported in the list instead of being swallowed,
  /// because on Android a mis-typed storage identifier fails exactly this quietly.
  ///
  /// Returns the entry it added so a caller that wants to retract its own line can do so
  /// by identity. Removing by index would drop whichever line happened to be first by
  /// then, which is not necessarily the one this call wrote.
  Future<_Entry?> _perform(
    String operation,
    Future<String> Function() body,
  ) async {
    setState(() => _busy = true);

    String message;
    var isError = false;
    try {
      message = await body();
    } on PlatformException catch (e) {
      message = '${e.code}: ${e.message ?? 'no message'}';
      isError = true;
    } on MissingPluginException {
      message = 'the plugin is not registered on this platform';
      isError = true;
    } catch (e) {
      message = e.toString();
      isError = true;
    }

    if (!mounted) return null;
    final entry = _Entry('$operation → $message', isError: isError);
    setState(() {
      _busy = false;
      _entries.insert(0, entry);
    });
    return entry;
  }

  Future<void> _save() async {
    final value = _valueController.text;
    await _perform('put', () async {
      await FlutterKeychainFix.put(key: _demoKey, value: value);
      await _syncStoredValue();
      return 'stored "$value" under "$_demoKey"';
    });
  }

  Future<void> _read({bool silent = false}) async {
    final entry = await _perform('get', () async {
      await _syncStoredValue();
      return _stored == null
          ? 'nothing stored under "$_demoKey"'
          : 'read "${_stored!}"';
    });
    // The opening read runs before the user has touched anything. It still refreshes the
    // card above, but logging it would make the activity list look as though something
    // had already failed.
    if (silent && entry != null && mounted) {
      setState(() => _entries.remove(entry));
    }
  }

  Future<void> _delete() async {
    await _perform('remove', () async {
      await FlutterKeychainFix.remove(key: _demoKey);
      await _syncStoredValue();
      return 'deleted "$_demoKey"';
    });
  }

  Future<void> _clearAll() async {
    await _perform('clear', () async {
      await FlutterKeychainFix.clear();
      await _syncStoredValue();
      return 'deleted every entry, encryption key kept';
    });
  }

  /// Applies the iOS keychain label. Android ignores it, which is worth seeing: the call
  /// succeeds and changes nothing there.
  Future<void> _configure() async {
    final label = _labelController.text;
    await _perform('configure', () async {
      await FlutterKeychainFix.configure(label: label.isEmpty ? null : label);
      return label.isEmpty
          ? 'reset to the default iOS configuration'
          : 'label set to "$label" for items written from now on';
    });
  }

  Future<void> _syncStoredValue() async {
    final value = await FlutterKeychainFix.get(key: _demoKey);
    if (mounted) setState(() => _stored = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('flutter_keychain_fix')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Secure store', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Values are encrypted by the iOS Keychain and the Android Keystore, then '
              'read back by key.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _valueController,
              decoration: const InputDecoration(
                labelText: 'Value to store',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: const Text('Save'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _read,
                  child: const Text('Read'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _delete,
                  child: const Text('Delete key'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _clearAll,
                  child: const Text('Clear all'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _StoredValueCard(value: _stored),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),

            Text('iOS configuration', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'A label controls how an item appears in iOS Passwords. Apply it before '
              'saving if you want one. Android has no equivalent and ignores this.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Keychain label (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : _configure,
              child: const Text('Apply configuration'),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),

            Text('Activity', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_entries.isEmpty)
              Text(
                'Nothing yet — tap a button above.',
                style: theme.textTheme.bodySmall,
              )
            else
              for (final entry in _entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    entry.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: entry.isError ? theme.colorScheme.error : null,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _StoredValueCard extends StatelessWidget {
  const _StoredValueCard({required this.value});

  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Currently stored under "$_demoKey"',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Text(
              value ?? '(nothing)',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontStyle: value == null ? FontStyle.italic : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
