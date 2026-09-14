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

The packages share one version (melos fixed mode), and each package gets its own
tag, such as `mux-v0.1.0-dev.1`. Commit messages follow
[Conventional Commits](https://www.conventionalcommits.org) (`feat:`, `fix:`, …),
which melos uses to pick the next version and write the changelogs.

```bash
melos version --prerelease   # e.g. 0.1.0-dev.1 -> 0.1.0-dev.2 (commits and tags)
melos version --graduate     # e.g. 0.1.0-dev.2 -> 0.1.0
```

Pushing a package tag runs two workflows:

- [`release.yml`](.github/workflows/release.yml) creates a GitHub Release
  from that version's CHANGELOG section. `-dev` versions are marked as
  prereleases.
- `publish-<package>.yml` publishes the package to pub.dev through
  [automated publishing](https://dart.dev/tools/pub/automated-publishing).

Push the `mux-v…` tag first and wait for it to publish, because `flutter_mux`
and `mux_generator` depend on it.

The first version of each package has to be published by hand, `mux` first:
run `dart pub publish` in each package directory. Then, on each package's
pub.dev admin page, enable automated publishing for this repository with the tag
pattern `<package>-v{{version}}`.

## License

MIT. See [LICENSE](LICENSE).
