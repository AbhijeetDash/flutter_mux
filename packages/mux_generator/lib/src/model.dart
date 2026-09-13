/// A class reference that survives the JSON hop between the two builders.
final class ClassRef {
  const ClassRef(this.name, this.import);

  factory ClassRef.fromJson(Map<String, Object?> json) =>
      ClassRef(json['name']! as String, json['import']! as String);

  final String name;

  /// Library URI declaring the class, e.g. `package:app/users_repo.dart`.
  final String import;

  String get key => '$import#$name';

  Map<String, Object?> toJson() => {'name': name, 'import': import};
}

/// A required constructor parameter, injected by its class type.
final class Param {
  const Param(this.name, this.type, {required this.named});

  factory Param.fromJson(Map<String, Object?> json) => Param(
    json['name']! as String,
    ClassRef.fromJson(json['type']! as Map<String, Object?>),
    named: json['named']! as bool,
  );

  final String name;
  final ClassRef type;
  final bool named;

  Map<String, Object?> toJson() => {
    'name': name,
    'type': type.toJson(),
    'named': named,
  };
}

/// The request family a service handles: `R` in `MuxService<R>`.
final class Family {
  const Family(this.type, this.typeArgs, this.supertypes);

  factory Family.fromJson(Map<String, Object?> json) => Family(
    ClassRef.fromJson(json['type']! as Map<String, Object?>),
    json['typeArgs']! as int,
    [for (final key in json['supertypes']! as List<Object?>) key! as String],
  );

  final ClassRef type;
  final int typeArgs;

  /// [ClassRef.key]s of every supertype, to detect overlapping families.
  final List<String> supertypes;

  Map<String, Object?> toJson() => {
    'type': type.toJson(),
    'typeArgs': typeArgs,
    'supertypes': supertypes,
  };
}

/// A class mux constructs: a service (with a [family]) or a provider.
final class Node {
  const Node(this.type, this.params, {this.family});

  factory Node.fromJson(Map<String, Object?> json) => Node(
    ClassRef.fromJson(json['type']! as Map<String, Object?>),
    [
      for (final param in json['params']! as List<Object?>)
        Param.fromJson(param! as Map<String, Object?>),
    ],
    family: json['family'] == null
        ? null
        : Family.fromJson(json['family']! as Map<String, Object?>),
  );

  final ClassRef type;
  final List<Param> params;
  final Family? family;

  Map<String, Object?> toJson() => {
    'type': type.toJson(),
    'params': [for (final param in params) param.toJson()],
    if (family != null) 'family': family!.toJson(),
  };
}
