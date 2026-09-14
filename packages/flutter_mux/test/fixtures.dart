import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_mux/flutter_mux.dart';

sealed class TestRequest<T> extends Request<T> {
  const TestRequest();
}

final class FetchUsers extends TestRequest<List<String>> {
  const FetchUsers(this.filter);

  final String filter;

  @override
  Object get key => (FetchUsers, filter);
}

final class FetchConfig extends TestRequest<String> {
  const FetchConfig();

  @override
  Object get key => FetchConfig;

  @override
  bool get keepAlive => true;
}

/// Service whose responses stay pending until the test completes them.
final class TestService {
  final _pending = <Object, Completer<Object?>>{};

  Future<void> handle(TestRequest<Object?> request, Responder respond) =>
      switch (request) {
        FetchUsers r => _load(r, respond),
        FetchConfig r => _load(r, respond),
      };

  Future<void> _load<T>(Request<T> request, Responder respond) async {
    respond.loading(request);
    final completer = Completer<T>();
    _pending[request.key] = completer;
    respond.data(request, await completer.future);
  }

  void complete<T>(Request<T> request, T value) =>
      (_pending.remove(request.key)! as Completer<T>).complete(value);
}

String label<T>(AsyncState<T> state) => switch (state) {
  Idle() => 'idle',
  Loading() => 'loading',
  Data(:final value) => '$value',
  Failure(:final error) => 'error: $error',
};

/// A [MuxBuilder] that renders [label] and reports each build.
Widget muxText<T>(Request<T> request, {VoidCallback? onBuild}) => MuxBuilder<T>(
  request: request,
  builder: (context, state) {
    onBuild?.call();
    return Text(label(state));
  },
);
