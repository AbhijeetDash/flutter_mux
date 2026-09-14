import 'package:flutter/widgets.dart';
import 'package:mux/mux.dart';

import 'mux_scope.dart';

/// Creates the app's single channel with [create] and provides it to [child].
///
/// Pass the generated `$createMuxChannel`. The channel is created once and
/// closed when this widget is disposed.
class MuxApp extends StatefulWidget {
  const MuxApp({super.key, required this.create, required this.child});

  final MuxChannel<Request<Object?>> Function() create;
  final Widget child;

  @override
  State<MuxApp> createState() => _MuxAppState();
}

class _MuxAppState extends State<MuxApp> {
  late final MuxChannel<Request<Object?>> _channel = widget.create();

  @override
  void dispose() {
    _channel.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      MuxScope(channel: _channel, child: widget.child);
}
