import 'package:flutter/material.dart';
import 'package:flutter_mux/flutter_mux.dart';

sealed class AppRequest<T> extends Request<T> {
  const AppRequest();
}

final class FetchGreeting extends AppRequest<String> {
  const FetchGreeting();

  @override
  Object get key => FetchGreeting;
}

final class GreetingService extends MuxService<AppRequest<Object?>> {
  const GreetingService();

  @override
  Future<void> handle(AppRequest<Object?> request, Responder respond) async {
    switch (request) {
      case FetchGreeting r:
        respond.loading(r);
        await Future<void>.delayed(const Duration(seconds: 1));
        respond.data(r, 'Hello from mux');
    }
  }
}

/// Without mux_generator, create and bind the channel yourself.
MuxChannel<Request<Object?>> createChannel() => MuxChannel<Request<Object?>>()
  ..bind(
    (request, respond) => switch (request) {
      final AppRequest<Object?> r => const GreetingService().handle(r, respond),
      _ => throw StateError('Unhandled ${request.runtimeType}'),
    },
  );

void main() => runApp(
  const MuxApp(
    create: createChannel,
    child: MaterialApp(home: GreetingPage()),
  ),
);

class GreetingPage extends StatefulWidget {
  const GreetingPage({super.key});

  @override
  State<GreetingPage> createState() => _GreetingPageState();
}

class _GreetingPageState extends State<GreetingPage> {
  @override
  void initState() {
    super.initState();
    context.send(const FetchGreeting());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: MuxBuilder<String>(
          request: const FetchGreeting(),
          builder: (context, state) => switch (state) {
            Idle() || Loading() => const CircularProgressIndicator(),
            Data(:final value) => Text(value),
            Failure(:final error) => Text('Failed: $error'),
          },
        ),
      ),
    );
  }
}
