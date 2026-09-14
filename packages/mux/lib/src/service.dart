part of '../mux.dart';

/// Handles one sealed request family [R].
///
/// The generated channel routes every request of type [R] to [handle].
abstract class MuxService<R extends Request<Object?>> {
  const MuxService();

  FutureOr<void> handle(R request, Responder respond);
}
