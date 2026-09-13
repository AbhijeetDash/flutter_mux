import 'dart:convert';

import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';

import 'model.dart';

final _muxInit = TypeChecker.typeNamedLiterally('MuxInit', inPackage: 'mux');

/// Generates `$createMuxChannel` for the `@MuxInit` library: every
/// `@WithService` service created with its dependencies and routed its
/// request family.
final class MuxInitGenerator extends Generator {
  @override
  Future<String?> generate(LibraryReader library, BuildStep buildStep) async {
    if (library.annotatedWith(_muxInit).isEmpty) return null;

    final services = <String, Node>{};
    final providers = <String, Node>{};
    await for (final id in buildStep.findAssets(Glob('lib/**.mux.json'))) {
      final json =
          jsonDecode(await buildStep.readAsString(id)) as Map<String, Object?>;
      for (final service in json['services']! as List<Object?>) {
        final node = Node.fromJson(service! as Map<String, Object?>);
        services[node.type.key] = node;
      }
      for (final provider in json['providers']! as List<Object?>) {
        final node = Node.fromJson(provider! as Map<String, Object?>);
        providers[node.type.key] = node;
      }
    }

    _checkOverlap(services.values.toList());
    return _ChannelWriter(services, providers).write();
  }
}

void _checkOverlap(List<Node> services) {
  for (var i = 0; i < services.length; i++) {
    for (var j = i + 1; j < services.length; j++) {
      final a = services[i].family!;
      final b = services[j].family!;
      if (a.type.key == b.type.key ||
          a.supertypes.contains(b.type.key) ||
          b.supertypes.contains(a.type.key)) {
        throw InvalidGenerationSourceError(
          '${services[i].type.name} (${a.type.name}) and '
          '${services[j].type.name} (${b.type.name}) handle overlapping '
          'requests; each request family needs exactly one service.',
        );
      }
    }
  }
}

final class _ChannelWriter {
  _ChannelWriter(this.services, this.providers);

  final Map<String, Node> services;
  final Map<String, Node> providers;

  final _prefixes = <String, String>{};
  final _locals = <String, String>{};
  final _params = <String, String>{};
  final _body = StringBuffer();

  String write() {
    final keys = services.keys.toList()..sort();
    for (final key in keys) {
      _create(key, const []);
    }
    final cases = [for (final key in keys) _case(services[key]!)];
    final overrides = [
      for (final MapEntry(:key, :value) in _params.entries)
        '${_type(providers[key]!.type)}? $value',
    ];
    final imports = [
      for (final MapEntry(:key, :value) in _prefixes.entries)
        "import '$key' as $value;",
    ];

    return '''
// ignore_for_file: type=lint
import 'package:mux/mux.dart' as mux;
${imports.join('\n')}

/// The app's single channel with every `@WithService` service bound.
mux.MuxChannel<mux.Request<Object?>> \$createMuxChannel(${overrides.isEmpty ? '' : '{${overrides.join(', ')},}'}) {
$_body
  return mux.MuxChannel<mux.Request<Object?>>()
    ..bind((request, respond) => switch (request) {
      ${cases.join('\n      ')}
      _ => throw StateError('No @WithService service handles \${request.runtimeType}'),
    });
}
''';
  }

  /// Emits the local for [key] after its dependencies, depth first.
  void _create(String key, List<String> chain) {
    if (_locals.containsKey(key)) return;
    if (chain.contains(key)) {
      throw InvalidGenerationSourceError(
        'Dependency cycle: ${[...chain, key].map(_nameOf).join(' -> ')}.',
      );
    }
    final node = providers[key] ?? services[key]!;
    for (final param in node.params) {
      final dependency = param.type.key;
      if (!providers.containsKey(dependency) &&
          !services.containsKey(dependency)) {
        throw InvalidGenerationSourceError(
          '${node.type.name} needs ${param.type.name} (parameter '
          '`${param.name}`), but no @MuxProvide class or @WithService service '
          'provides it.',
        );
      }
      _create(dependency, [...chain, key]);
    }

    final args = [
      for (final param in node.params)
        param.named
            ? '${param.name}: ${_locals[param.type.key]}'
            : _locals[param.type.key]!,
    ].join(', ');
    final construct = '${_type(node.type)}($args)';
    final local = _unique(_locals, key, '\$${_lowerFirst(node.type.name)}');
    if (providers.containsKey(key)) {
      final param = _unique(_params, key, _lowerFirst(node.type.name));
      _body.writeln('  final $local = $param ?? $construct;');
    } else {
      _body.writeln('  final $local = $construct;');
    }
  }

  String _case(Node service) {
    final family = service.family!;
    final args = family.typeArgs == 0
        ? ''
        : '<${List.filled(family.typeArgs, 'Object?').join(', ')}>';
    return 'final ${_type(family.type)}$args r => '
        '${_locals[service.type.key]}.handle(r, respond),';
  }

  String _type(ClassRef ref) =>
      '${_prefixes.putIfAbsent(ref.import, () => 'i${_prefixes.length}')}'
      '.${ref.name}';

  String _nameOf(String key) => (providers[key] ?? services[key])!.type.name;
}

String _unique(Map<String, String> names, String key, String base) {
  var candidate = base;
  for (var n = 2; names.containsValue(candidate); n++) {
    candidate = '$base$n';
  }
  return names[key] = candidate;
}

String _lowerFirst(String name) =>
    name.isEmpty ? name : name[0].toLowerCase() + name.substring(1);
