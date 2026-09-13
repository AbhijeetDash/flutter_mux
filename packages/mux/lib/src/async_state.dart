part of '../mux.dart';

/// The cached state of one request key.
sealed class AsyncState<T> {
  const AsyncState();

  /// The most recent value: [Data.value], or `previous` while loading or
  /// failed.
  T? get latest => switch (this) {
    Idle() => null,
    Loading(:final previous) => previous,
    Data(:final value) => value,
    Failure(:final previous) => previous,
  };
}

/// Nothing has been requested for this key yet.
final class Idle<T> extends AsyncState<T> {
  const Idle();
}

/// A request is in flight. [previous] holds the last value, if any.
final class Loading<T> extends AsyncState<T> {
  const Loading({this.previous});

  final T? previous;
}

final class Data<T> extends AsyncState<T> {
  const Data(this.value);

  final T value;
}

/// The handler failed. [previous] holds the last value, if any.
final class Failure<T> extends AsyncState<T> {
  const Failure(this.error, {this.stackTrace, this.previous});

  final Object error;
  final StackTrace? stackTrace;
  final T? previous;
}
