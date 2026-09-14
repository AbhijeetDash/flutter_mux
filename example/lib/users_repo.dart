import 'dart:math';

import 'package:mux/mux.dart';

import 'models.dart';

/// In-memory backend with latency. Jitter makes rapid refreshes finish out of
/// order, which is what sequencing has to handle.
@MuxProvide()
final class FakeUsersRepo {
  FakeUsersRepo({
    this.latency = const Duration(milliseconds: 800),
    this.jitter = true,
    this.pageSize = 15,
  });

  final Duration latency;
  final bool jitter;
  final int pageSize;

  static final _users = List.generate(
    60,
    (i) => User(
      id: i + 1,
      name: 'User ${i + 1}',
      isActive: i % 3 != 0,
      isAdmin: i % 5 == 0,
    ),
  );

  final _random = Random();
  var _fetches = 0;

  Future<UserPage> page(UserFilter filter, {int cursor = 0}) async {
    final fetch = ++_fetches;
    final ms = latency.inMilliseconds;
    await Future<void>.delayed(
      jitter ? Duration(milliseconds: ms ~/ 2 + _random.nextInt(ms)) : latency,
    );
    final matches = _users.where(filter.matches).toList();
    final end = min(cursor + pageSize, matches.length);
    return UserPage(
      matches.sublist(cursor, end),
      nextCursor: end < matches.length ? end : null,
      fetch: fetch,
    );
  }
}
