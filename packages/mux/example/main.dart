import 'package:mux/mux.dart';

sealed class AppRequest<T> extends Request<T> {
  const AppRequest();
}

final class FetchUser extends AppRequest<String> {
  const FetchUser(this.id);

  final int id;

  @override
  Object get key => (FetchUser, id);
}

final class UserService extends MuxService<AppRequest<Object?>> {
  @override
  Future<void> handle(AppRequest<Object?> request, Responder respond) async {
    switch (request) {
      case FetchUser r:
        respond.loading(r);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        respond.data(r, 'user ${r.id}');
    }
  }
}

Future<void> main() async {
  final channel = MuxChannel<AppRequest<Object?>>()..bind(UserService().handle);

  final lease = channel.store.subscribe(const FetchUser(1));
  lease.addListener(
    () => print(switch (lease.state) {
      Idle() => 'idle',
      Loading() => 'loading',
      Data(:final value) => 'data: $value',
      Failure(:final error) => 'failed: $error',
    }),
  );

  channel.send(const FetchUser(1)); // prints "loading", then "data: user 1"
  await Future<void>.delayed(const Duration(milliseconds: 200));

  lease.release();
  await channel.close();
}
