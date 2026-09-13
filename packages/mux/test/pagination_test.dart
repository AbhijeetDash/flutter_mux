import 'package:mux/mux.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

/// Pure-Dart run of the first vertical slice: a paginated, filterable list
/// with pull-to-refresh.
void main() {
  late FakeBackend backend;
  late MuxChannel<TestRequest<Object?>> channel;

  setUp(() {
    backend = FakeBackend();
    channel = MuxChannel<TestRequest<Object?>>()
      ..bind(TestService(backend).handle);
  });

  tearDown(() => channel.close());

  test('two filters are independent live keys', () async {
    final a = channel.store.subscribe(const FetchUsers('a'));
    final b = channel.store.subscribe(const FetchUsers('b'));
    channel
      ..send(const FetchUsers('a'))
      ..send(const FetchUsers('b'));
    await pumpEventQueue();
    final [callA, callB] = backend.pages;

    callB.completer.complete(const UserPage(['b1']));
    await pumpEventQueue();
    expect(a.state, isLoading());
    expect(b.state, isData(['b1']));

    callA.completer.complete(const UserPage(['a1']));
    await pumpEventQueue();
    expect(a.state, isData(['a1']));
    expect(b.state, isData(['b1']));
  });

  test('load more appends pages until there is no next cursor', () async {
    final lease = await loadUsers(
      channel,
      backend,
      'a',
      const UserPage(['u1'], nextCursor: 1),
    );

    channel.send(const LoadMoreUsers('a'));
    await pumpEventQueue();
    expect(backend.pages.last.cursor, 1);
    expect(lease.state, isLoading(previous: ['u1']));

    backend.pages.last.completer.complete(const UserPage(['u2']));
    await pumpEventQueue();
    expect(lease.state, isData(['u1', 'u2']));

    channel.send(const LoadMoreUsers('a'));
    await pumpEventQueue();
    expect(backend.pages, hasLength(2));
  });

  test('load more is ignored while a refresh is in flight', () async {
    await loadUsers(
      channel,
      backend,
      'a',
      const UserPage(['u1'], nextCursor: 1),
    );

    channel.send(const FetchUsers('a'));
    await pumpEventQueue();
    channel.send(const LoadMoreUsers('a'));
    await pumpEventQueue();

    expect(backend.pages.map((call) => call.cursor), [0, 0]);
  });

  test('a refresh overtakes an in-flight load more', () async {
    final lease = await loadUsers(
      channel,
      backend,
      'a',
      const UserPage(['u1'], nextCursor: 1),
    );

    channel.send(const LoadMoreUsers('a'));
    await pumpEventQueue();
    channel.send(const FetchUsers('a'));
    await pumpEventQueue();
    final [_, loadMore, refresh] = backend.pages;

    loadMore.completer.complete(const UserPage(['u2']));
    await pumpEventQueue();
    expect(lease.state, isLoading(previous: ['u1']));

    refresh.completer.complete(const UserPage(['fresh']));
    await pumpEventQueue();
    expect(lease.state, isData(['fresh']));
  });

  test('popping one filter evicts it and keeps the other', () async {
    final a = await loadUsers(channel, backend, 'a', const UserPage(['a1']));
    final b = await loadUsers(channel, backend, 'b', const UserPage(['b1']));

    b.release();
    await pumpEventQueue();

    expect(channel.store.read(const FetchUsers('b')), isIdle);
    expect(a.state, isData(['a1']));
  });
}
