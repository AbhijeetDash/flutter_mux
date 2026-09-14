# flutter_mux

Flutter widgets for [`mux`](https://pub.dev/packages/mux). Widgets send typed
requests with `context.send(...)`, and each `MuxBuilder` rebuilds only when the
state for its own request changes.

> **Pre-release (0.1.0-dev.1).** The API may change before 0.1.0.

## Widgets

- **`MuxApp`**: creates the app's single channel once and closes it on dispose.
- **`MuxBuilder<T>`**: subscribes to one request key, rebuilds on every state
  change, and releases the key when disposed.
- **`context.send(request)`**: sends a request from anywhere below `MuxApp`.

## Usage

```dart
MuxBuilder<UserPage>(
  request: FetchUsers(filter),
  builder: (context, state) => switch (state) {
    Idle() || Loading(previous: null) => const CircularProgressIndicator(),
    Loading(:final UserPage previous) => UserList(previous, refreshing: true),
    Data(:final value) => UserList(value),
    Failure(:final error) => Text('Failed: $error'),
  },
)
```

`MuxBuilder` only reads state. Send the request yourself, for example from
`initState` or a refresh callback.

To wire services with annotations and skip creating the channel by hand, use
[`mux_generator`](https://pub.dev/packages/mux_generator). See
[`example/main.dart`](example/main.dart) for a complete app that wires one
service manually.

## Testing

- Create the channel inside the `testWidgets` body, not in `setUp`. Widget tests
  run in a FakeAsync zone, and a channel created outside it never delivers.
- Responses arrive a microtask after they are sent, so call `pumpAndSettle()` or
  `pump()` twice before expecting a rebuild.
