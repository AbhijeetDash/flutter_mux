import 'package:mux/mux.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  late FakeBackend backend;
  late MuxChannel<TestRequest<Object?>> channel;

  setUp(() {
    backend = FakeBackend();
    channel = MuxChannel<TestRequest<Object?>>()
      ..bind(TestService(backend).handle);
  });

  tearDown(() => channel.close());

  group('cache', () {
    test('read is Idle before anything is sent', () {
      expect(channel.store.read(const FetchUsers('a')), isIdle);
    });

    test('a late subscriber gets the cached state synchronously', () async {
      final first = await loadUsers(
        channel,
        backend,
        'a',
        const UserPage(['u1']),
      );

      final second = channel.store.subscribe(const FetchUsers('a'));

      expect(second.state, same(first.state));
      expect(second.state, isData(['u1']));
    });

    test('listeners see each state in order', () async {
      final lease = channel.store.subscribe(const FetchUsers('a'));
      final seen = <AsyncState<UserPage>>[];
      lease.addListener(() => seen.add(lease.state));

      channel.send(const FetchUsers('a'));
      await pumpEventQueue();
      backend.pages.single.completer.complete(const UserPage(['u1']));
      await pumpEventQueue();

      expect(seen, [
        isLoading(),
        isData(['u1']),
      ]);
    });

    test('requests with the same key share one entry', () async {
      final lease = await loadUsers(
        channel,
        backend,
        'a',
        const UserPage(['u1']),
      );

      expect(channel.store.read(const LoadMoreUsers('a')), same(lease.state));
    });
  });

  group('sequencing', () {
    test('a slower earlier refresh is dropped', () async {
      final lease = channel.store.subscribe(const FetchUsers('a'));
      final seen = <AsyncState<UserPage>>[];
      lease.addListener(() => seen.add(lease.state));

      channel
        ..send(const FetchUsers('a'))
        ..send(const FetchUsers('a'));
      await pumpEventQueue();
      final [first, second] = backend.pages;

      second.completer.complete(const UserPage(['new']));
      await pumpEventQueue();
      first.completer.complete(const UserPage(['old']));
      await pumpEventQueue();

      expect(lease.state, isData(['new']));
      expect(seen, [
        isLoading(),
        isLoading(),
        isData(['new']),
      ]);
    });
  });

  group('eviction', () {
    test('releasing the last lease evicts after the current turn', () async {
      final lease = await loadUsers(
        channel,
        backend,
        'a',
        const UserPage(['u1']),
      );

      lease.release();
      expect(channel.store.read(const FetchUsers('a')), isData(['u1']));

      await pumpEventQueue();
      expect(channel.store.read(const FetchUsers('a')), isIdle);
    });

    test('resubscribing in the same turn cancels eviction', () async {
      final lease = await loadUsers(
        channel,
        backend,
        'a',
        const UserPage(['u1']),
      );

      lease.release();
      final again = channel.store.subscribe(const FetchUsers('a'));
      await pumpEventQueue();

      expect(again.state, isData(['u1']));
    });

    test(
      'an entry with a dispatch in flight outlives its last lease',
      () async {
        final lease = channel.store.subscribe(const FetchUsers('a'));
        channel.send(const FetchUsers('a'));
        await pumpEventQueue();
        lease.release();
        await pumpEventQueue();
        expect(channel.store.read(const FetchUsers('a')), isLoading());

        backend.pages.single.completer.complete(const UserPage(['u1']));
        await pumpEventQueue();
        expect(channel.store.read(const FetchUsers('a')), isIdle);
      },
    );

    test(
      'a subscriber arriving after send gets the in-flight response',
      () async {
        channel.send(const FetchUsers('a'));
        await pumpEventQueue();

        final lease = channel.store.subscribe(const FetchUsers('a'));
        expect(lease.state, isLoading());

        backend.pages.single.completer.complete(const UserPage(['u1']));
        await pumpEventQueue();
        expect(lease.state, isData(['u1']));
      },
    );

    test(
      'a reply sent after its handler finished skips a re-created entry',
      () async {
        final lease = channel.store.subscribe(Requests.lateReply);
        channel.send(Requests.lateReply);
        await pumpEventQueue();
        lease.release();
        await pumpEventQueue();

        final again = channel.store.subscribe(Requests.lateReply);
        backend.lateReplies.single.complete(1);
        await pumpEventQueue();
        expect(again.state, isA<Idle<int>>());

        channel.send(Requests.lateReply);
        await pumpEventQueue();
        backend.lateReplies.last.complete(2);
        await pumpEventQueue();
        expect(
          again.state,
          isA<Data<int>>().having((d) => d.value, 'value', 2),
        );
      },
    );

    test('keepAlive entries survive their last release', () async {
      final lease = channel.store.subscribe(Requests.config);
      channel.send(Requests.config);
      await pumpEventQueue();
      backend.configs.single.complete('dark');
      await pumpEventQueue();

      lease.release();
      await pumpEventQueue();

      expect(
        channel.store.read(Requests.config),
        isA<Data<String>>().having((d) => d.value, 'value', 'dark'),
      );
    });

    test('release is idempotent and detaches only its listeners', () async {
      final kept = channel.store.subscribe(const FetchUsers('a'));
      final released = channel.store.subscribe(const FetchUsers('a'));
      var calls = 0;
      released
        ..addListener(() => calls++)
        ..release()
        ..release();

      channel.send(const FetchUsers('a'));
      await pumpEventQueue();

      expect(calls, 0);
      expect(kept.state, isLoading());
      expect(() => released.addListener(() {}), throwsStateError);
    });
  });

  group('errors', () {
    test(
      'a synchronous throw becomes a Failure and handling continues',
      () async {
        final lease = channel.store.subscribe(Requests.explode);
        channel.send(Requests.explode);
        await pumpEventQueue();

        expect(
          lease.state,
          isA<Failure<int>>().having((f) => f.error, 'error', isStateError),
        );

        channel.send(const FetchUsers('a'));
        await pumpEventQueue();
        expect(backend.pages, hasLength(1));
      },
    );

    test('an async error keeps the previous value on the Failure', () async {
      final lease = await loadUsers(
        channel,
        backend,
        'a',
        const UserPage(['u1']),
      );

      channel.send(const FetchUsers('a'));
      await pumpEventQueue();
      backend.pages.last.completer.completeError(Exception('offline'));
      await pumpEventQueue();

      expect(
        lease.state,
        isA<Failure<UserPage>>()
            .having((f) => f.error, 'error', isException)
            .having((f) => f.previous?.users, 'previous.users', ['u1']),
      );
    });

    test('responding to another key fails the dispatched request', () async {
      final lease = channel.store.subscribe(Requests.misroute);
      channel.send(Requests.misroute);
      await pumpEventQueue();

      expect(
        lease.state,
        isA<Failure<UserPage>>().having(
          (f) => f.error,
          'error',
          isArgumentError,
        ),
      );
      expect(channel.store.read(const FetchUsers('elsewhere')), isIdle);
    });
  });

  group('lifecycle', () {
    test('requests sent before bind are handled once bound', () async {
      final unbound = MuxChannel<TestRequest<Object?>>();
      addTearDown(unbound.close);
      final lease = unbound.store.subscribe(const FetchUsers('a'));

      unbound.send(const FetchUsers('a'));
      await pumpEventQueue();
      expect(backend.pages, isEmpty);

      unbound.bind(TestService(backend).handle);
      await pumpEventQueue();
      expect(backend.pages, hasLength(1));
      expect(lease.state, isLoading());
    });

    test('binding twice throws', () {
      expect(() => channel.bind(TestService(backend).handle), throwsStateError);
    });

    test(
      'after close, send throws and in-flight responses are ignored',
      () async {
        final lease = channel.store.subscribe(const FetchUsers('a'));
        channel.send(const FetchUsers('a'));
        await pumpEventQueue();
        await channel.close();

        expect(() => channel.send(const FetchUsers('a')), throwsStateError);
        backend.pages.single.completer.complete(const UserPage(['late']));
        await pumpEventQueue();
        expect(lease.state, isLoading());
      },
    );
  });
}
