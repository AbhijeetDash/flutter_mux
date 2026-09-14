import 'dart:async';

import 'package:mux/mux.dart';
import 'package:test/test.dart';

final class UserPage {
  const UserPage(this.users, {this.nextCursor});

  final List<String> users;
  final int? nextCursor;
}

/// Key tag shared by [FetchUsers] and [LoadMoreUsers].
abstract final class UsersList {}

sealed class TestRequest<T> extends Request<T> {
  const TestRequest();
}

final class FetchUsers extends TestRequest<UserPage> {
  const FetchUsers(this.filter);

  final String filter;

  @override
  Object get key => (UsersList, filter);
}

final class LoadMoreUsers extends TestRequest<UserPage> {
  const LoadMoreUsers(this.filter);

  final String filter;

  @override
  Object get key => (UsersList, filter);
}

final class FetchConfig extends TestRequest<String> {
  const FetchConfig();

  @override
  Object get key => FetchConfig;

  @override
  bool get keepAlive => true;
}

final class Explode extends TestRequest<int> {
  const Explode();

  @override
  Object get key => Explode;
}

final class Misroute extends TestRequest<UserPage> {
  const Misroute();

  @override
  Object get key => Misroute;
}

/// Its handler finishes at once and replies later, when the backend answers.
final class LateReply extends TestRequest<int> {
  const LateReply();

  @override
  Object get key => LateReply;
}

abstract final class Requests {
  static const config = FetchConfig();
  static const explode = Explode();
  static const misroute = Misroute();
  static const lateReply = LateReply();
}

typedef PageCall = ({String filter, int cursor, Completer<UserPage> completer});

/// Backend whose calls stay pending until the test completes them.
final class FakeBackend {
  final pages = <PageCall>[];
  final configs = <Completer<String>>[];
  final lateReplies = <Completer<int>>[];

  Future<UserPage> page(String filter, int cursor) {
    final completer = Completer<UserPage>();
    pages.add((filter: filter, cursor: cursor, completer: completer));
    return completer.future;
  }

  Future<String> config() {
    final completer = Completer<String>();
    configs.add(completer);
    return completer.future;
  }

  Future<int> lateReply() {
    final completer = Completer<int>();
    lateReplies.add(completer);
    return completer.future;
  }
}

final class TestService {
  TestService(this.backend);

  final FakeBackend backend;

  Future<void> handle(TestRequest<Object?> request, Responder respond) =>
      switch (request) {
        FetchUsers r => _fetch(r, respond),
        LoadMoreUsers r => _loadMore(r, respond),
        FetchConfig r => _config(r, respond),
        Explode() => throw StateError('boom'),
        Misroute() => _misroute(respond),
        LateReply r => _replyLater(r, respond),
      };

  Future<void> _fetch(FetchUsers request, Responder respond) async {
    respond.loading(request);
    respond.data(request, await backend.page(request.filter, 0));
  }

  Future<void> _loadMore(LoadMoreUsers request, Responder respond) async {
    // Only page from settled data; a refresh in flight wins.
    final current = respond.current(request);
    if (current is! Data<UserPage>) return;
    final cursor = current.value.nextCursor;
    if (cursor == null) return;
    respond.loading(request);
    final next = await backend.page(request.filter, cursor);
    respond.data(
      request,
      UserPage([
        ...current.value.users,
        ...next.users,
      ], nextCursor: next.nextCursor),
    );
  }

  Future<void> _config(FetchConfig request, Responder respond) async {
    respond.loading(request);
    respond.data(request, await backend.config());
  }

  /// Responds to a key it was not dispatched for.
  Future<void> _misroute(Responder respond) async {
    respond.data(const FetchUsers('elsewhere'), const UserPage([]));
  }

  Future<void> _replyLater(LateReply request, Responder respond) async {
    unawaited(
      backend.lateReply().then((value) => respond.data(request, value)),
    );
  }
}

/// Subscribes to [filter], sends the first fetch and resolves it with [page].
Future<MuxLease<UserPage>> loadUsers(
  MuxChannel<TestRequest<Object?>> channel,
  FakeBackend backend,
  String filter,
  UserPage page,
) async {
  final lease = channel.store.subscribe(FetchUsers(filter));
  channel.send(FetchUsers(filter));
  await pumpEventQueue();
  backend.pages.last.completer.complete(page);
  await pumpEventQueue();
  return lease;
}

Matcher get isIdle => isA<Idle<UserPage>>();

Matcher isData(List<String> users) =>
    isA<Data<UserPage>>().having((d) => d.value.users, 'users', users);

Matcher isLoading({List<String>? previous}) => isA<Loading<UserPage>>().having(
  (l) => l.previous?.users,
  'previous.users',
  previous,
);
