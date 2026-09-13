// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// MuxInitGenerator
// **************************************************************************

// ignore_for_file: type=lint
import 'package:mux/mux.dart' as mux;
import 'package:mux_example/users_repo.dart' as i0;
import 'package:mux_example/users_service.dart' as i1;
import 'package:mux_example/requests.dart' as i2;

/// The app's single channel with every `@WithService` service bound.
mux.MuxChannel<mux.Request<Object?>> $createMuxChannel({
  i0.FakeUsersRepo? fakeUsersRepo,
}) {
  final $fakeUsersRepo = fakeUsersRepo ?? i0.FakeUsersRepo();
  final $usersService = i1.UsersService($fakeUsersRepo);

  return mux.MuxChannel<mux.Request<Object?>>()..bind(
    (request, respond) => switch (request) {
      final i2.AppRequest<Object?> r => $usersService.handle(r, respond),
      _ => throw StateError(
        'No @WithService service handles ${request.runtimeType}',
      ),
    },
  );
}
