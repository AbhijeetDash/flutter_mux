import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'model.dart';

final _withService = TypeChecker.typeNamedLiterally(
  'WithService',
  inPackage: 'mux',
);
final _provide = TypeChecker.typeNamedLiterally('MuxProvide', inPackage: 'mux');
final _muxService = TypeChecker.typeNamedLiterally(
  'MuxService',
  inPackage: 'mux',
);

/// Records one library's `@WithService` and `@MuxProvide` declarations as
/// JSON, for `MuxInitGenerator` to aggregate.
final class MuxCollectBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => const {
    '.dart': ['.mux.json'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final source = await buildStep.readAsString(buildStep.inputId);
    if (!source.contains('WithService') && !source.contains('MuxProvide')) {
      return;
    }
    if (!await buildStep.resolver.isLibrary(buildStep.inputId)) return;
    final library = LibraryReader(await buildStep.inputLibrary);

    final services = [
      for (final annotated in library.annotatedWith(_withService))
        _service(
          annotated.annotation.read('service').typeValue,
          annotated.element,
        ),
    ];
    final providers = [
      for (final annotated in library.annotatedWith(_provide))
        _provider(annotated.element),
    ];
    if (services.isEmpty && providers.isEmpty) return;

    await buildStep.writeAsString(
      buildStep.inputId.changeExtension('.mux.json'),
      jsonEncode({
        'services': [for (final service in services) service.toJson()],
        'providers': [for (final provider in providers) provider.toJson()],
      }),
    );
  }
}

Node _provider(Element element) {
  if (element is! ClassElement) {
    throw InvalidGenerationSourceError(
      '@MuxProvide must annotate a class.',
      element: element,
    );
  }
  return _node(element, element);
}

Node _service(DartType type, Element usedAt) {
  final cls = type is InterfaceType ? type.element : null;
  if (cls is! ClassElement) {
    throw InvalidGenerationSourceError(
      '@WithService needs a class, got ${type.getDisplayString()}.',
      element: usedAt,
    );
  }

  InterfaceType? base;
  for (final supertype in cls.allSupertypes) {
    if (_muxService.isExactlyType(supertype)) base = supertype;
  }
  if (base == null) {
    throw InvalidGenerationSourceError(
      '${cls.displayName} is used in @WithService but does not extend '
      'MuxService.',
      element: usedAt,
    );
  }

  final family = base.typeArguments.single;
  if (family is! InterfaceType ||
      !family.typeArguments.every(_isObjectOrDynamic)) {
    throw InvalidGenerationSourceError(
      '${cls.displayName} must handle a whole request family, e.g. '
      'MuxService<AppRequest<Object?>>; got ${family.getDisplayString()}.',
      element: usedAt,
    );
  }

  return _node(
    cls,
    usedAt,
    family: Family(_ref(family.element), family.typeArguments.length, [
      for (final supertype in family.allSupertypes) _ref(supertype.element).key,
    ]),
  );
}

Node _node(ClassElement cls, Element usedAt, {Family? family}) {
  final constructor = cls.unnamedConstructor;
  if (cls.isAbstract || constructor == null) {
    throw InvalidGenerationSourceError(
      '${cls.displayName} needs an unnamed constructor so mux can create it.',
      element: usedAt,
    );
  }
  return Node(_ref(cls), [
    for (final param in constructor.formalParameters)
      if (param.isRequiredPositional || param.isRequiredNamed)
        Param(
          param.displayName,
          _injectedType(param, cls, usedAt),
          named: param.isNamed,
        ),
  ], family: family);
}

ClassRef _injectedType(
  FormalParameterElement param,
  ClassElement owner,
  Element usedAt,
) {
  final type = param.type;
  if (type is! InterfaceType ||
      type.nullabilitySuffix == NullabilitySuffix.question) {
    throw InvalidGenerationSourceError(
      '${owner.displayName}.${param.displayName} must be a non-null class '
      'type to be injected.',
      element: usedAt,
    );
  }
  return _ref(type.element);
}

ClassRef _ref(InterfaceElement element) =>
    ClassRef(element.displayName, element.library.uri.toString());

bool _isObjectOrDynamic(DartType type) =>
    type is DynamicType ||
    (type.isDartCoreObject &&
        type.nullabilitySuffix == NullabilitySuffix.question);
