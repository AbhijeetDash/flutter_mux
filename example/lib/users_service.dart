import 'package:mux/mux.dart';

import 'models.dart';
import 'requests.dart';
import 'users_repo.dart';

final class UsersService extends MuxService<AppRequest<Object?>> {
  UsersService(this._repo);

  final FakeUsersRepo _repo;

  @override
  Future<void> handle(AppRequest<Object?> request, Responder respond) =>
      switch (request) {
        FetchUsers r => _fetch(r, respond),
        LoadMoreUsers r => _loadMore(r, respond),
      };

  Future<void> _fetch(FetchUsers request, Responder respond) async {
    respond.loading(request);
    respond.data(request, await _repo.page(request.filter));
  }

  Future<void> _loadMore(LoadMoreUsers request, Responder respond) async {
    // Only page from settled data: a refresh or another load-more in flight
    // wins, and duplicate scroll triggers are ignored.
    final current = respond.current(request);
    if (current is! Data<UserPage>) return;
    final cursor = current.value.nextCursor;
    if (cursor == null) return;
    respond.loading(request);
    final next = await _repo.page(request.filter, cursor: cursor);
    respond.data(
      request,
      UserPage(
        [...current.value.users, ...next.users],
        nextCursor: next.nextCursor,
        fetch: next.fetch,
      ),
    );
  }
}
