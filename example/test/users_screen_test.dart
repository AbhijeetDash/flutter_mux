import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mux_example/main.dart';
import 'package:mux_example/main.mux.dart';
import 'package:mux_example/users_repo.dart';

const _latency = Duration(milliseconds: 300);

/// Dispatches pending requests, lets the fake backend answer, and draws the
/// resulting frame. Spinners animate forever, so `pumpAndSettle` can't be used.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(_latency);
  await tester.pump();
}

void main() {
  Future<void> launch(WidgetTester tester) async {
    await tester.pumpWidget(
      MuxExample(
        create: () => $createMuxChannel(
          fakeUsersRepo: FakeUsersRepo(latency: _latency, jitter: false),
        ),
      ),
    );
    expect(find.byKey(const Key('initial-load')), findsOneWidget);
    await settle(tester);
  }

  testWidgets('loads the first page, then the next one on scroll', (
    tester,
  ) async {
    await launch(tester);
    expect(find.text('User 1'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('User 30'), 300);

    expect(find.text('User 30'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('switching filter swaps to that key', (tester) async {
    await launch(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Admins'));
    await tester.pump();
    expect(find.byKey(const Key('initial-load')), findsOneWidget);
    await settle(tester);

    expect(find.text('Users · Admins'), findsOneWidget);
    expect(find.text('User 6'), findsOneWidget);
    expect(find.text('User 2'), findsNothing);
  });

  testWidgets('a pushed screen is its own key and is evicted on pop', (
    tester,
  ) async {
    await launch(tester);

    Future<void> openAdmins() async {
      await tester.tap(find.byTooltip('Open admins'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    await openAdmins();
    expect(find.byKey(const Key('initial-load')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Users · Admins'), findsOneWidget);
    expect(find.text('User 6'), findsOneWidget);

    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Users · All'), findsOneWidget);
    expect(find.text('User 2'), findsOneWidget);

    // Re-opening starts from Idle: the admins entry was evicted on pop.
    await openAdmins();
    expect(find.byKey(const Key('initial-load')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
