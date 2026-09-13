import 'package:flutter/widgets.dart';
import 'package:mux/mux.dart';

/// Exposes the app's [MuxChannel] to the widget tree. Usually created by
/// `MuxApp`.
///
/// The channel must stay the same for the life of the scope. Lookups register
/// no dependency, so nothing below ever rebuilds from here; per-key
/// `MuxBuilder`s drive rebuilds instead.
class MuxScope extends InheritedWidget {
  const MuxScope({super.key, required this.channel, required super.child});

  final MuxChannel<Request<Object?>> channel;

  /// The store of the nearest [MuxScope].
  static MuxStore storeOf(BuildContext context) => _of(context).channel.store;

  static MuxScope _of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<MuxScope>();
    if (scope == null) {
      throw FlutterError('No MuxScope found above this ${context.widget}.');
    }
    return scope;
  }

  @override
  bool updateShouldNotify(MuxScope oldWidget) {
    assert(
      identical(channel, oldWidget.channel),
      'MuxScope.channel must not change',
    );
    return false;
  }
}

/// Sends requests from any widget below a [MuxScope].
extension MuxContext on BuildContext {
  /// Sends [request] on the nearest [MuxScope]'s channel.
  void send(Request<Object?> request) =>
      MuxScope._of(this).channel.send(request);
}
