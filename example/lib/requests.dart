import 'package:flutter_mux/flutter_mux.dart';

import 'models.dart';

sealed class AppRequest<T> extends Request<T> {
  const AppRequest();
}

/// Key tag shared by [FetchUsers] and [LoadMoreUsers], so pages append to the
/// same cache entry as the first fetch.
abstract final class UsersList {}

/// Loads the first page, replacing whatever is cached (also pull-to-refresh).
final class FetchUsers extends AppRequest<UserPage> {
  const FetchUsers(this.filter);

  final UserFilter filter;

  @override
  Object get key => (UsersList, filter);
}

/// Appends the next page to the cached list, if there is one.
final class LoadMoreUsers extends AppRequest<UserPage> {
  const LoadMoreUsers(this.filter);

  final UserFilter filter;

  @override
  Object get key => (UsersList, filter);
}
