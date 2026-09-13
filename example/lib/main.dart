import 'package:flutter/material.dart';
import 'package:flutter_mux/flutter_mux.dart';

import 'main.mux.dart';
import 'models.dart';
import 'users_screen.dart';

@MuxInit()
void main() => runApp(const MuxExample(create: $createMuxChannel));

class MuxExample extends StatelessWidget {
  const MuxExample({super.key, required this.create});

  /// Normally the generated `$createMuxChannel`; tests pass overrides.
  final MuxChannel<Request<Object?>> Function() create;

  @override
  Widget build(BuildContext context) {
    return MuxApp(
      create: create,
      child: MaterialApp(
        title: 'mux example',
        theme: ThemeData(colorSchemeSeed: Colors.indigo),
        home: const UsersScreen(initialFilter: UserFilter.all),
      ),
    );
  }
}
