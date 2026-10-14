// Widget tests for the example app.
//
// The activity list sits below the fold, and a ListView only builds what is visible, so
// anything asserted about it has to scroll first.
//
// The first test deliberately leaves the platform channel unanswered, which is what a
// real misconfiguration looks like: the page has to survive it and say so, rather than
// throwing during build or swallowing the failure.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_keychain_fix_example/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugin.com.ehangwork/flutter_keychain_fix');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// Brings the activity list, which lives below the fold, into the built tree.
  Future<void> revealActivity(WidgetTester tester) async {
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
  }

  testWidgets('renders every operation the demo exposes', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(AppBar, 'flutter_keychain_fix'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Read'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Delete key'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Clear all'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Apply configuration'),
      findsOneWidget,
    );
  });

  testWidgets('starts with an empty activity list', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);

    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();
    await revealActivity(tester);

    // The opening read happens on its own; it must not show up as user activity.
    expect(find.text('Nothing yet — tap a button above.'), findsOneWidget);
    expect(find.textContaining('nothing stored'), findsNothing);
  });

  testWidgets('reports a platform failure instead of crashing', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(
            code: 'NOT_AVAILABLE',
            message: 'no secure store here',
          );
        });

    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    await revealActivity(tester);

    expect(find.textContaining('NOT_AVAILABLE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows what a successful put reads back', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'get') return 'hello world';
          return null;
        });

    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    await revealActivity(tester);

    expect(find.textContaining('stored "hello world"'), findsOneWidget);
  });
}
