# flutter_mux

A request-keyed state management workspace for Dart and Flutter. The UI sends
typed requests over one channel, services answer them, and widgets rebuild only
for the requests they read.

| Package | Description |
|---|---|
| [`mux`](packages/mux) | Pure-Dart core: channel, per-key cache, sequencing, eviction, annotations. |
| [`flutter_mux`](packages/flutter_mux) | Widgets: `MuxApp`, `MuxBuilder`, `context.send`. |
| [`mux_generator`](packages/mux_generator) | `build_runner` generator that wires `@WithService` services into the channel. |

[`example/`](example) is a paginated, filterable user list with pull-to-refresh
built on all three packages.

## Development

Requires Dart 3.10+ and [melos](https://melos.invertase.dev).

```bash
dart pub global activate melos
flutter pub get
melos run generate      # build_runner in packages using mux_generator
melos run test:dart     # mux, mux_generator
melos run test:flutter  # flutter_mux, example
```

## Releasing

The packages share one version (melos fixed mode). Commit messages follow
[Conventional Commits](https://www.conventionalcommits.org) (`feat:`, `fix:`, …),
which melos uses to pick the next version and write the changelogs.

```bash
melos version --prerelease   # e.g. 0.1.0-dev.1 -> 0.1.0-dev.2
melos version --graduate     # e.g. 0.1.0-dev.2 -> 0.1.0
melos publish                # dry run
melos publish --no-dry-run   # publish to pub.dev
```

## License

MIT. See [LICENSE](LICENSE).
