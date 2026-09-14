# mux

A request-keyed state channel for Dart. The UI sends typed requests, a service
layer answers them, and a retained cache keeps the latest state per request.

> **Pre-release (0.1.0-dev.1).** The API may change before 0.1.0.

In Flutter apps, use [`flutter_mux`](https://pub.dev/packages/flutter_mux) for
widgets and [`mux_generator`](https://pub.dev/packages/mux_generator) to wire
services with annotations.

## Concepts

- **`Request<T>`**: a typed request. Its `key` (usually a record such as
  `(UsersList, filter)`) identifies its cache entry.
- **`AsyncState<T>`**: sealed `Idle | Loading | Data | Failure`. `Loading` and
  `Failure` keep the previous value, so lists stay visible while refreshing.
- **`MuxService<R>`**: handles one sealed request family with an exhaustive
  `switch`. Errors thrown by a handler become `Failure` states.
- **`MuxChannel`**: dispatches requests and applies responses in order. A slower,
  older response for a key never overwrites a newer one. A key is evicted once it
  has no subscribers and no request for it is still running, unless the request
  sets `keepAlive`.

## Usage

```dart
sealed class AppRequest<T> extends Request<T> {
  const AppRequest();
}

final class FetchUser extends AppRequest<String> {
  const FetchUser(this.id);

  final int id;

  @override
  Object get key => (FetchUser, id);
}

final class UserService extends MuxService<AppRequest<Object?>> {
  @override
  Future<void> handle(AppRequest<Object?> request, Responder respond) async {
    switch (request) {
      case FetchUser r:
        respond.loading(r);
        respond.data(r, 'user ${r.id}');
    }
  }
}

final channel = MuxChannel<AppRequest<Object?>>()..bind(UserService().handle);
final lease = channel.store.subscribe(const FetchUser(1));
lease.addListener(() => print(lease.state));
channel.send(const FetchUser(1));
```

See [`example/main.dart`](example/main.dart) for a runnable version.
