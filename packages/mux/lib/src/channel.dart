part of '../mux.dart';

/// Handles one request, pushing states back through [respond].
///
/// Runs unawaited; a sync or async throw becomes a [Failure] for the request.
/// The request's key stays cached until the handler completes.
typedef MuxHandler<R> = FutureOr<void> Function(R request, Responder respond);

/// The bidirectional channel: the UI [send]s requests down, the bound handler
/// responds up, and [store] retains the latest state per key.
final class MuxChannel<R extends Request<Object?>> {
  MuxChannel() {
    _responseSub = _responses.stream.listen(store._apply);
  }

  final MuxStore store = MuxStore._();
  final _requests = StreamController<(R, int, _Entry)>();
  final _responses = StreamController<_Response>();
  late final StreamSubscription<_Response> _responseSub;
  StreamSubscription<(R, int, _Entry)>? _requestSub;
  bool _closed = false;

  /// Queues [request] for the handler. Requests sent before [bind] are
  /// buffered.
  void send(R request) {
    if (_closed) throw StateError('MuxChannel is closed');
    final (entry, seq) = store._dispatch(request);
    _requests.add((request, seq, entry));
  }

  /// Attaches the service handler. A channel has exactly one.
  void bind(MuxHandler<R> handler) {
    if (_requestSub != null) throw StateError('MuxChannel is already bound');
    _requestSub = _requests.stream.listen((dispatch) {
      final (request, seq, entry) = dispatch;
      final respond = Responder._(this, request.key, seq);
      // Not awaited: a slow handler never delays the next request.
      unawaited(
        Future.sync(() => handler(request, respond))
            .catchError(
              (Object error, StackTrace stackTrace) =>
                  respond.failure(request, error, stackTrace),
            )
            .whenComplete(() => store._settle(entry)),
      );
    });
  }

  /// Stops handling and ignores responses from handlers still in flight.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _requestSub?.cancel();
    await _responseSub.cancel();
    unawaited(_requests.close());
    unawaited(_responses.close());
  }
}

/// Pushes states for one dispatched request, stamped with its seq.
final class Responder {
  Responder._(this._channel, this._key, this._seq);

  final MuxChannel<Request<Object?>> _channel;
  final Object _key;
  final int _seq;

  /// The cached state for [request]'s key.
  AsyncState<T> current<T>(Request<T> request) => _channel.store.read(request);

  void loading<T>(Request<T> request) {
    final previous = current(request).latest;
    _emit(
      request,
      request._capture(<X>() => Loading<X>(previous: previous as X?)),
    );
  }

  void data<T>(Request<T> request, T value) =>
      _emit(request, request._capture(<X>() => Data<X>(value as X)));

  void failure<T>(Request<T> request, Object error, [StackTrace? stackTrace]) {
    final previous = current(request).latest;
    _emit(
      request,
      request._capture(
        <X>() =>
            Failure<X>(error, stackTrace: stackTrace, previous: previous as X?),
      ),
    );
  }

  void _emit(Request<Object?> request, AsyncState<Object?> state) {
    if (request.key != _key) {
      throw ArgumentError.value(
        request,
        'request',
        'Responder is bound to key $_key',
      );
    }
    if (_channel._closed) return;
    _channel._responses.add(_Response(_key, _seq, state));
  }
}

/// Envelope on the response direction: which key, which dispatch, what state.
final class _Response {
  const _Response(this.key, this.seq, this.state);

  final Object key;
  final int seq;
  final AsyncState<Object?> state;
}
