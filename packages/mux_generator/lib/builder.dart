/// build_runner entry points for mux code generation.
library;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/collect_builder.dart';
import 'src/init_generator.dart';

Builder muxCollectBuilder(BuilderOptions options) => MuxCollectBuilder();

Builder muxInitBuilder(BuilderOptions options) =>
    LibraryBuilder(MuxInitGenerator(), generatedExtension: '.mux.dart');
