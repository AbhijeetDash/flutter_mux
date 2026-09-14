# mux_generator example

A repository, a service that uses it, and a screen that declares the service.

```dart
// lib/users_repo.dart
@MuxProvide()
final class UsersRepo {
  Future<List<String>> fetch() async => ['Ada', 'Linus'];
}
```

```dart
// lib/users_service.dart
sealed class UserRequest<T> extends Request<T> {
  const UserRequest();
}

final class FetchUsers extends UserRequest<List<String>> {
  const FetchUsers();

  @override
  Object get key => FetchUsers;
}

final class UsersService extends MuxService<UserRequest<Object?>> {
  UsersService(this.repo); // UsersRepo is injected

  final UsersRepo repo;

  @override
  Future<void> handle(UserRequest<Object?> request, Responder respond) async {
    switch (request) {
      case FetchUsers r:
        respond.loading(r);
        respond.data(r, await repo.fetch());
    }
  }
}
```

```dart
// lib/users_screen.dart
@WithService(UsersService)
class UsersScreen extends StatefulWidget {
  // ... calls context.send(const FetchUsers()) and renders a MuxBuilder
}
```

```dart
// lib/main.dart
import 'main.mux.dart';

@MuxInit()
void main() => runApp(
  const MuxApp(create: $createMuxChannel, child: MaterialApp(home: UsersScreen())),
);
```

Running `dart run build_runner build` generates `lib/main.mux.dart`:

```dart
mux.MuxChannel<mux.Request<Object?>> $createMuxChannel({i0.UsersRepo? usersRepo}) {
  final $usersRepo = usersRepo ?? i0.UsersRepo();
  final $usersService = i1.UsersService($usersRepo);

  return mux.MuxChannel<mux.Request<Object?>>()..bind(
    (request, respond) => switch (request) {
      final i1.UserRequest<Object?> r => $usersService.handle(r, respond),
      _ => throw StateError('No @WithService service handles ${request.runtimeType}'),
    },
  );
}
```

A complete app, a paginated, filterable list with pull-to-refresh, is in the
[repository's `example/`](https://github.com/AbhijeetDash/flutter_mux/tree/main/example).
