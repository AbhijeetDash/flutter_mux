import 'package:flutter/widgets.dart';
import 'package:mux/mux.dart';

import 'mux_scope.dart';

typedef MuxWidgetBuilder<T> =
    Widget Function(BuildContext context, AsyncState<T> state);

/// Rebuilds [builder] whenever the cached state for [request]'s key changes.
///
/// Only reads: send [request] yourself, e.g. from `initState` or `onRefresh`.
/// The key is held while this widget is mounted and released on dispose.
class MuxBuilder<T> extends StatefulWidget {
  const MuxBuilder({super.key, required this.request, required this.builder});

  final Request<T> request;
  final MuxWidgetBuilder<T> builder;

  @override
  State<MuxBuilder<T>> createState() => _MuxBuilderState<T>();
}

class _MuxBuilderState<T> extends State<MuxBuilder<T>> {
  MuxLease<T>? _lease;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lease ??= _subscribe();
  }

  @override
  void didUpdateWidget(MuxBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.request.key == oldWidget.request.key) return;
    final next = _subscribe();
    _lease!.release();
    _lease = next;
  }

  @override
  void dispose() {
    _lease?.release();
    super.dispose();
  }

  MuxLease<T> _subscribe() =>
      MuxScope.storeOf(context).subscribe(widget.request)
        ..addListener(_onChange);

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) => widget.builder(context, _lease!.state);
}
