import 'package:flutter/material.dart';
import 'package:flutter_mux/flutter_mux.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  late TestService service;
  late MuxChannel<TestRequest<Object?>> channel;

  /// Opens the channel inside the test body. `testWidgets` runs in a FakeAsync
  /// zone and stream events are delivered in the zone that called `listen`, so
  /// a channel built in `setUp` never delivers during `tester.pump()`.
  ///
  /// Tests use `pumpAndSettle`: responses land a microtask after the frame
  /// check in `pump`, so their rebuild needs a second frame.
  void testMux(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) async {
      service = TestService();
      channel = MuxChannel<TestRequest<Object?>>()..bind(service.handle);
      addTearDown(channel.close);
      await body(tester);
    });
  }

  Widget app(Widget home, {GlobalKey<NavigatorState>? navigatorKey}) =>
      MuxScope(
        channel: channel,
        child: MaterialApp(navigatorKey: navigatorKey, home: home),
      );

  group('MuxBuilder', () {
    testMux('rebuilds only itself as states arrive', (tester) async {
      var outerBuilds = 0;
      var builderBuilds = 0;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) {
              outerBuilds++;
              return muxText(
                const FetchUsers('a'),
                onBuild: () => builderBuilds++,
              );
            },
          ),
        ),
      );
      expect(find.text('idle'), findsOneWidget);

      channel.send(const FetchUsers('a'));
      await tester.pumpAndSettle();
      expect(find.text('loading'), findsOneWidget);

      service.complete(const FetchUsers('a'), ['u1']);
      await tester.pumpAndSettle();
      expect(find.text('[u1]'), findsOneWidget);

      expect(outerBuilds, 1);
      expect(builderBuilds, 3);
    });

    testMux('builders on the same key share state', (tester) async {
      await tester.pumpWidget(
        app(
          Column(
            children: [
              muxText(const FetchUsers('a')),
              muxText(const FetchUsers('a')),
            ],
          ),
        ),
      );

      channel.send(const FetchUsers('a'));
      await tester.pumpAndSettle();
      service.complete(const FetchUsers('a'), ['u1']);
      await tester.pumpAndSettle();

      expect(find.text('[u1]'), findsNWidgets(2));
    });

    testMux('a new request key resubscribes and evicts the old key', (
      tester,
    ) async {
      final filter = ValueNotifier('a');
      addTearDown(filter.dispose);
      await tester.pumpWidget(
        app(
          ValueListenableBuilder(
            valueListenable: filter,
            builder: (context, value, _) => muxText(FetchUsers(value)),
          ),
        ),
      );
      channel.send(const FetchUsers('a'));
      await tester.pumpAndSettle();
      service.complete(const FetchUsers('a'), ['a1']);
      await tester.pumpAndSettle();
      expect(find.text('[a1]'), findsOneWidget);

      filter.value = 'b';
      await tester.pumpAndSettle();

      expect(find.text('idle'), findsOneWidget);
      expect(
        channel.store.read(const FetchUsers('a')),
        isA<Idle<List<String>>>(),
      );
    });

    testMux('unmounting with a response in flight is safe', (tester) async {
      await tester.pumpWidget(app(muxText(const FetchUsers('a'))));
      channel.send(const FetchUsers('a'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      service.complete(const FetchUsers('a'), ['late']);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        channel.store.read(const FetchUsers('a')),
        isA<Idle<List<String>>>(),
      );
    });
  });

  group('navigation', () {
    testMux('popping a route evicts its key and keeps the one below', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        app(muxText(const FetchUsers('a')), navigatorKey: navigator),
      );
      channel.send(const FetchUsers('a'));
      await tester.pumpAndSettle();
      service.complete(const FetchUsers('a'), ['a1']);
      await tester.pumpAndSettle();

      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(body: muxText(const FetchUsers('b'))),
        ),
      );
      await tester.pumpAndSettle();
      channel.send(const FetchUsers('b'));
      await tester.pumpAndSettle();
      service.complete(const FetchUsers('b'), ['b1']);
      await tester.pumpAndSettle();
      expect(find.text('[b1]'), findsOneWidget);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      expect(
        channel.store.read(const FetchUsers('b')),
        isA<Idle<List<String>>>(),
      );
      expect(find.text('[a1]'), findsOneWidget);
    });

    testMux('keepAlive keys survive a pop', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(app(const SizedBox(), navigatorKey: navigator));

      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(body: muxText(const FetchConfig())),
        ),
      );
      await tester.pumpAndSettle();
      channel.send(const FetchConfig());
      await tester.pumpAndSettle();
      service.complete(const FetchConfig(), 'dark');
      await tester.pumpAndSettle();

      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      expect(
        channel.store.read(const FetchConfig()),
        isA<Data<String>>().having((d) => d.value, 'value', 'dark'),
      );
    });
  });

  group('MuxScope', () {
    testMux('context.send dispatches on the scoped channel', (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) {
              captured = context;
              return muxText(const FetchUsers('a'));
            },
          ),
        ),
      );

      captured.send(const FetchUsers('a'));
      await tester.pumpAndSettle();

      expect(find.text('loading'), findsOneWidget);
    });

    testWidgets('MuxApp creates its channel once and closes it on dispose', (
      tester,
    ) async {
      var creates = 0;
      late MuxChannel<Request<Object?>> created;
      Widget build() => MuxApp(
        create: () {
          creates++;
          return created = MuxChannel<Request<Object?>>();
        },
        child: const SizedBox(),
      );

      await tester.pumpWidget(build());
      await tester.pumpWidget(build());
      expect(creates, 1);

      await tester.pumpWidget(const SizedBox());
      expect(() => created.send(const FetchUsers('a')), throwsStateError);
    });

    testWidgets('lookup without a scope throws', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: MuxBuilder<List<String>>(
            request: FetchUsers('a'),
            builder: _unreachable,
          ),
        ),
      );

      expect(tester.takeException(), isFlutterError);
    });
  });
}

Widget _unreachable(BuildContext context, AsyncState<List<String>> state) =>
    throw StateError('built without a scope');
