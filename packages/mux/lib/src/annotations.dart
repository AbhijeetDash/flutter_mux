part of '../mux.dart';

/// Wires [service] into the generated channel.
///
/// Place it on the widget that sends the service's requests. Every service
/// named this way is created once, with its constructor parameters injected
/// from `@MuxProvide` classes, and receives its request family.
final class WithService {
  const WithService(this.service);

  /// A class extending [MuxService].
  final Type service;
}

/// Makes a class injectable into services by constructor parameter type.
final class MuxProvide {
  const MuxProvide();
}

/// Marks the function whose file gets the generated `.mux.dart` library,
/// which defines `$createMuxChannel`.
final class MuxInit {
  const MuxInit();
}
