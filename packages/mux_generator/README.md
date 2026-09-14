# mux_generator

`build_runner` code generation for [`mux`](https://pub.dev/packages/mux). Annotate
the widgets that use a service. The generator creates the app's single channel,
builds each service with its constructor dependencies, and routes each service's
request family to it.

> **Pre-release (0.1.0-dev.1).** The API may change before 0.1.0.

## Install

```yaml
dependencies:
  flutter_mux: ^0.1.0-dev.1
  mux: ^0.1.0-dev.1

dev_dependencies:
  build_runner: ^2.15.1
  mux_generator: ^0.1.0-dev.1
```

## Annotations

| Annotation | Put it on | Effect |
|---|---|---|
| `@WithService(SomeService)` | A widget class that uses the service | Registers `SomeService` (a `MuxService<R>`) and routes requests of type `R` to it. |
| `@MuxProvide()` | A class services depend on, such as a repository | Makes it injectable into service constructors by type. |
| `@MuxInit()` | One function, usually `main` | The generated `<file>.mux.dart` is written next to this file. |

Run `dart run build_runner build`, then import the generated file:

```dart
import 'main.mux.dart';

@MuxInit()
void main() => runApp(const MuxApp(create: $createMuxChannel, child: App()));
```

In tests, replace any `@MuxProvide` class through an optional parameter:
`$createMuxChannel(usersRepo: FakeUsersRepo())`.

## Build errors

The build fails with a message naming the class if:

- a `@WithService` class doesn't extend `MuxService`,
- a constructor parameter's type has no `@MuxProvide` class and isn't a service,
- services or providers depend on each other in a cycle, or
- two services handle overlapping request families.

## Limits

- Annotations go on declarations (classes), not on widget instances inside
  `build()`.
- Annotated classes must live under `lib/`.

See [`example/example.md`](example/example.md) for a full walkthrough.
