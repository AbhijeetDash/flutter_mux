import 'dart:convert';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:mux_generator/builder.dart';
import 'package:mux_generator/src/model.dart';
import 'package:test/test.dart';

/// Minimal stand-in for `package:mux`; the builders match by name and package.
const _muxSource = '''
abstract class Request<T> {}
class Responder {}
abstract class MuxService<R extends Request<Object?>> {
  void handle(R request, Responder respond);
}
class WithService {
  const WithService(this.service);
  final Type service;
}
class MuxProvide {
  const MuxProvide();
}
class MuxInit {
  const MuxInit();
}
''';

const _app = 'package:app/app.dart';

void main() {
  group('mux_collect', () {
    Future<List<String>> collect(
      String source, {
      void Function(Map<String, Object?> json)? onJson,
    }) async {
      final logs = <String>[];
      await testBuilder(
        muxCollectBuilder(BuilderOptions.empty),
        {'mux|lib/mux.dart': _muxSource, 'app|lib/app.dart': source},
        rootPackage: 'app',
        outputs: onJson == null
            ? null
            : {
                'app|lib/app.mux.json': decodedMatches(
                  predicate<String>((json) {
                    onJson(jsonDecode(json) as Map<String, Object?>);
                    return true;
                  }),
                ),
              },
        onLog: (log) => logs.add('${log.message} ${log.error ?? ''}'),
      );
      return logs;
    }

    test('records services with their family and injected params', () async {
      late Map<String, Object?> json;
      await collect('''
import 'package:mux/mux.dart';

sealed class AppRequest<T> extends Request<T> {}

@MuxProvide()
class Repo {}

class UsersService extends MuxService<AppRequest<Object?>> {
  UsersService(this.repo, {required Repo backup, int retries = 3});
  final Repo repo;
  @override
  void handle(AppRequest<Object?> request, Responder respond) {}
}

@WithService(UsersService)
class UsersScreen {}
''', onJson: (decoded) => json = decoded);

      final [service as Map<String, Object?>] =
          json['services']! as List<Object?>;
      final node = Node.fromJson(service);
      expect(node.type.key, '$_app#UsersService');
      expect(
        [for (final p in node.params) (p.name, p.type.key, p.named)],
        [('repo', '$_app#Repo', false), ('backup', '$_app#Repo', true)],
      );
      expect(node.family!.type.key, '$_app#AppRequest');
      expect(node.family!.typeArgs, 1);
      expect(node.family!.supertypes, contains('package:mux/mux.dart#Request'));

      final [provider as Map<String, Object?>] =
          json['providers']! as List<Object?>;
      expect(Node.fromJson(provider).type.key, '$_app#Repo');
    });

    test('rejects a @WithService class that is not a MuxService', () async {
      final logs = await collect('''
import 'package:mux/mux.dart';

class NotAService {}

@WithService(NotAService)
class Screen {}
''');

      expect(logs, contains(contains('does not extend MuxService')));
    });
  });

  group('mux_init', () {
    ClassRef ref(String name) => ClassRef(name, _app);

    List<Param> params(List<String> deps) => [
      for (final dep in deps) Param(dep.toLowerCase(), ref(dep), named: false),
    ];

    Node provider(String name, [List<String> deps = const []]) =>
        Node(ref(name), params(deps));

    Node service(
      String name,
      String family, {
      List<String> deps = const [],
      List<String> familySupertypes = const [],
    }) => Node(
      ref(name),
      params(deps),
      family: Family(ref(family), 1, familySupertypes),
    );

    Future<List<String>> generate({
      List<Node> services = const [],
      List<Node> providers = const [],
      bool init = true,
      Map<String, Object>? outputs,
    }) async {
      final logs = <String>[];
      await testBuilder(
        muxInitBuilder(BuilderOptions.empty),
        {
          'mux|lib/mux.dart': _muxSource,
          'app|lib/main.dart': init
              ? "import 'package:mux/mux.dart';\n@MuxInit()\nvoid main() {}\n"
              : 'void main() {}\n',
          'app|lib/app.mux.json': jsonEncode({
            'services': [for (final node in services) node.toJson()],
            'providers': [for (final node in providers) node.toJson()],
          }),
        },
        rootPackage: 'app',
        outputs: outputs,
        onLog: (log) => logs.add('${log.message} ${log.error ?? ''}'),
      );
      return logs;
    }

    test(
      'creates providers before services, with overrides and routing',
      () async {
        await generate(
          services: [
            service('UsersService', 'AppRequest', deps: ['Repo']),
          ],
          providers: [provider('Repo')],
          outputs: {
            'app|lib/main.mux.dart': decodedMatches(
              allOf(
                contains(r'$createMuxChannel({'),
                contains('i0.Repo? repo'),
                contains(r'final $repo = repo ?? i0.Repo();'),
                contains(r'final $usersService = i0.UsersService($repo);'),
                contains(
                  r'final i0.AppRequest<Object?> r => $usersService.handle(r, respond),',
                ),
              ),
            ),
          },
        );
      },
    );

    test('writes nothing without @MuxInit', () async {
      await generate(
        services: [service('UsersService', 'AppRequest')],
        init: false,
        outputs: {},
      );
    });

    test('reports a dependency nobody provides', () async {
      final logs = await generate(
        services: [
          service('UsersService', 'AppRequest', deps: ['Repo']),
        ],
      );

      expect(logs, contains(contains('UsersService needs Repo')));
    });

    test('reports a dependency cycle', () async {
      final logs = await generate(
        services: [
          service('UsersService', 'AppRequest', deps: ['A']),
        ],
        providers: [
          provider('A', ['B']),
          provider('B', ['A']),
        ],
      );

      expect(logs, contains(contains('Dependency cycle')));
    });

    test('reports services with overlapping request families', () async {
      final logs = await generate(
        services: [
          service('AppService', 'AppRequest'),
          service(
            'UsersService',
            'UserRequest',
            familySupertypes: ['$_app#AppRequest'],
          ),
        ],
      );

      expect(logs, contains(contains('handle overlapping requests')));
    });
  });
}
