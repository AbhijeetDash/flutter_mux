part of '../mux.dart';

/// Retained latest-state-per-key cache with refcounted eviction.
///
/// Obtain it from [MuxChannel.store]; the channel applies responses.
final class MuxStore {
  MuxStore._();

  final _entries = <Object, _Entry>{};

  /// Global dispatch counter. Monotonic overall, so also monotonic per key.
  int _seq = 0;

  /// The current state for [request]'s key, or [Idle] if none is cached.
  AsyncState<T> read<T>(Request<T> request) {
    final entry = _entries[request.key];
    return entry == null ? Idle<T>() : entry.state as AsyncState<T>;
  }

  /// Holds [request]'s key in the cache until the returned lease is released.
  MuxLease<T> subscribe<T>(Request<T> request) {
    final entry = _ensure(request)..refs += 1;
    return MuxLease<T>._(this, entry);
  }

  _Entry _ensure(Request<Object?> request) {
    // A fresh entry's floor is above every seq issued so far, so responses
    // dispatched before it existed (e.g. before an eviction) are dropped.
    final entry = _entries[request.key] ??= _Entry(
      request.key,
      request._capture(<X>() => Idle<X>()),
      _seq + 1,
    );
    if (request.keepAlive) entry.keepAlive = true;
    return entry;
  }

  /// Registers a dispatch for [request] and returns its entry and seq.
  ///
  /// The entry is held until [_settle], so a widget that subscribes after the
  /// send (e.g. on the next frame) still receives the response.
  (_Entry, int) _dispatch(Request<Object?> request) {
    final entry = _ensure(request)..inFlight += 1;
    return (entry, ++_seq);
  }

  /// Marks one dispatch for [entry] as finished.
  void _settle(_Entry entry) {
    entry.inFlight -= 1;
    _scheduleEviction(entry);
  }

  void _apply(_Response response) {
    final entry = _entries[response.key];
    if (entry == null || response.seq < entry.seq) return;
    entry
      ..seq = response.seq
      ..state = response.state;
    for (final listener in List.of(entry.listeners)) {
      listener();
    }
  }

  void _release(_Entry entry) {
    entry.refs--;
    _scheduleEviction(entry);
  }

  /// Evicts [entry] once it has no subscribers and no dispatch in flight.
  ///
  /// Deferred past the current synchronous work, so an unsubscribe/resubscribe
  /// in one frame keeps the value.
  void _scheduleEviction(_Entry entry) {
    if (!entry.evictable || entry.evictionPending) return;
    entry.evictionPending = true;
    scheduleMicrotask(() {
      entry.evictionPending = false;
      if (entry.evictable && identical(_entries[entry.key], entry)) {
        _entries.remove(entry.key);
      }
    });
  }
}

/// A counted hold on one cache key, and the listenable for its state.
///
/// Listeners are called synchronously whenever a response is applied.
final class MuxLease<T> {
  MuxLease._(this._store, this._entry);

  final MuxStore _store;
  final _Entry _entry;
  final _listeners = <void Function()>[];
  bool _released = false;

  AsyncState<T> get state => _entry.state as AsyncState<T>;

  void addListener(void Function() listener) {
    if (_released) throw StateError('MuxLease used after release');
    _listeners.add(listener);
    _entry.listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    if (_listeners.remove(listener)) _entry.listeners.remove(listener);
  }

  /// Detaches this lease's listeners and drops its hold. Safe to call twice.
  void release() {
    if (_released) return;
    _released = true;
    for (final listener in _listeners) {
      _entry.listeners.remove(listener);
    }
    _listeners.clear();
    _store._release(_entry);
  }
}

final class _Entry {
  _Entry(this.key, this.state, this.seq);

  final Object key;
  AsyncState<Object?> state;

  /// Seq of the last applied response, or the floor for a fresh entry.
  int seq;
  int refs = 0;

  /// Dispatches whose handler has not finished yet.
  int inFlight = 0;
  bool keepAlive = false;
  bool evictionPending = false;
  final listeners = <void Function()>[];

  bool get evictable => refs == 0 && inFlight == 0 && !keepAlive;
}
