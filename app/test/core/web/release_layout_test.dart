import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `tool/stage_web_release.sh` turns a Flutter web build into the hashed release layout
/// (research R11, `contracts/web-release.md`): the shell at the root, everything else under
/// `r/<hash>/`, `release.json` with the hash and the mirror, and `.br`/`.gz` beside every
/// release file. The same input must always give the same hash.
void main() {
  /// What `flutter build web` leaves at the root and what the app loads before Flutter
  /// starts. These stay at the root.
  const buildShell = [
    'index.html',
    'flutter_bootstrap.js',
    'manifest.json',
    'favicon.png',
    'sw.js',
    'sw_core.mjs',
    'firebase-messaging-sw.js',
    'firebase-config.js',
    'privacy.html',
    'icons/Icon-192.png',
  ];

  /// The payload: everything Flutter loads at runtime, drift's two WebAssembly pieces
  /// included, plus the real drift worker that the shim replaces at the root.
  const payload = [
    'main.dart.js',
    'canvaskit/canvaskit.wasm',
    'assets/AssetManifest.json',
    'version.json',
    'sqlite3.wasm',
    'drift_worker.js',
  ];

  /// The files this script writes at the root.
  const generatedShell = ['release.json', 'drift_worker.js'];

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('madar-stage-');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// A Flutter web build as `flutter build web` leaves it.
  String fixture({Map<String, String> overrides = const {}, Set<String> skip = const {}}) {
    final input = Directory('${tmp.path}/web')..createSync(recursive: true);
    for (final path in [...buildShell, ...payload]) {
      if (skip.contains(path)) continue;
      final file = File('${input.path}/$path')..createSync(recursive: true);
      // The two files the script stamps carry its placeholders, as web/ does.
      final content = const ['flutter_bootstrap.js', 'sw.js'].contains(path)
          ? 'const RELEASE = { hash: "__RELEASE_HASH__", mirror: "__MIRROR_BASE__" };'
          : overrides[path] ?? 'content of $path';
      file.writeAsStringSync(content);
    }
    File('${tmp.path}/env.json').writeAsStringSync(
      jsonEncode({'MIRROR_BASE_URL': 'https://app.198.51.100.7.sslip.io'}),
    );
    return input.path;
  }

  Future<ProcessResult> stage(String input, {String out = 'release'}) => Process.run(
        'bash',
        [
          'tool/stage_web_release.sh',
          '${tmp.path}/env.json',
          '${tmp.path}/$out',
          input,
        ],
        workingDirectory: Directory.current.path,
      );

  List<String> rootEntries(String out) => [
        for (final entity in Directory(out).listSync())
          entity.uri.pathSegments.where((part) => part.isNotEmpty).last,
      ];

  Map<String, Object?> readRelease(String out) =>
      jsonDecode(File('$out/release.json').readAsStringSync()) as Map<String, Object?>;

  test('only the shell stays at the root, everything else moves under r/<hash>/', () async {
    final result = await stage(fixture());

    expect(result.exitCode, 0, reason: '${result.stderr}');
    final out = '${tmp.path}/release';
    final releaseHash = readRelease(out)['hash']! as String;
    expect(releaseHash, matches(RegExp(r'^[0-9a-f]{16}$')));

    expect(
      rootEntries(out).toSet(),
      {
        for (final path in buildShell) path.split('/').first,
        ...generatedShell,
        'r',
      },
      reason: 'the shell, the two files the script writes, and the release folder',
    );
    for (final path in payload) {
      expect(
        File('$out/r/$releaseHash/$path').existsSync(),
        isTrue,
        reason: '$path belongs to the release folder',
      );
      // The real drift worker moves too, but its same-origin shim stands in at the root.
      if (path == 'drift_worker.js') continue;
      expect(
        File('$out/$path').existsSync(),
        isFalse,
        reason: '$path must not stay at the root',
      );
    }
  });

  test('release.json names the hash and the mirror in the env file', () async {
    final result = await stage(fixture());
    expect(result.exitCode, 0, reason: '${result.stderr}');

    final out = '${tmp.path}/release';
    final release = readRelease(out);
    expect(release['hash'], matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(release['mirror'], 'https://app.198.51.100.7.sslip.io');
    expect(
      DateTime.parse(release['built_at']! as String).isUtc,
      isTrue,
      reason: 'ISO-8601 UTC, as data-model.md asks',
    );
    expect(
      (result.stdout as String).trim().split('\n').last,
      'RELEASE_HASH=${release['hash']}',
      reason: 'the workflow reads the hash from the last line',
    );
  });

  test('an empty mirror base is allowed: a preview build serves its own files', () async {
    final input = fixture();
    File('${tmp.path}/env.json').writeAsStringSync(jsonEncode({'MIRROR_BASE_URL': ''}));

    final result = await stage(input);

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(readRelease('${tmp.path}/release')['mirror'], '');
    expect(
      File('${tmp.path}/release/drift_worker.js').readAsStringSync(),
      contains("importScripts('/r/"),
      reason: 'the shim falls back to the same origin, with no host to name it',
    );
  });

  test('a mirror with a path or no https fails the staging', () async {
    final input = fixture();
    File('${tmp.path}/env.json').writeAsStringSync(
      jsonEncode({'MIRROR_BASE_URL': 'http://app.example.test/mirror'}),
    );

    final result = await stage(input);

    expect(result.exitCode, isNot(0));
    expect('${result.stderr}', contains('MIRROR_BASE_URL'));
  });

  test('the hash is the same for the same input, and differs for different content', () async {
    final first = await stage(fixture(), out: 'release-a');
    expect(first.exitCode, 0, reason: '${first.stderr}');
    final second = await stage(fixture(), out: 'release-b');
    expect(second.exitCode, 0, reason: '${second.stderr}');

    final a = readRelease('${tmp.path}/release-a')['hash'];
    final b = readRelease('${tmp.path}/release-b')['hash'];
    expect(a, b, reason: 'the build time is not part of the hash');

    final changed = await stage(
      fixture(overrides: {'main.dart.js': 'a different main.dart.js'}),
      out: 'release-c',
    );
    expect(changed.exitCode, 0, reason: '${changed.stderr}');
    expect(readRelease('${tmp.path}/release-c')['hash'], isNot(a));
  });

  test('every release file has its .br and .gz', () async {
    final result = await stage(fixture());
    expect(result.exitCode, 0, reason: '${result.stderr}');

    final out = '${tmp.path}/release';
    final releaseHash = readRelease(out)['hash']! as String;
    final releaseDir = Directory('$out/r/$releaseHash');
    var checked = 0;
    for (final entity in releaseDir.listSync(recursive: true)) {
      if (entity is! File) continue;
      // The compressed copies are files too; they are not themselves compressed.
      if (entity.path.endsWith('.br') || entity.path.endsWith('.gz')) continue;
      checked += 1;
      expect(File('${entity.path}.br').existsSync(), isTrue, reason: '${entity.path}.br');
      expect(File('${entity.path}.gz').existsSync(), isTrue, reason: '${entity.path}.gz');
    }
    expect(checked, greaterThanOrEqualTo(payload.length));
  });

  test('the shell is stamped with the hash and the mirror', () async {
    final result = await stage(fixture());
    expect(result.exitCode, 0, reason: '${result.stderr}');

    final out = '${tmp.path}/release';
    final releaseHash = readRelease(out)['hash']! as String;
    for (final path in ['flutter_bootstrap.js', 'sw.js', 'drift_worker.js']) {
      final text = File('$out/$path').readAsStringSync();
      expect(text, contains(releaseHash), reason: '$path carries the hash');
      expect(
        text,
        contains('https://app.198.51.100.7.sslip.io'),
        reason: '$path carries the mirror',
      );
      expect(text, isNot(contains('__RELEASE_HASH__')), reason: '$path lost the placeholder');
    }
  });

  test('a shell file that is missing fails the staging', () async {
    final result = await stage(fixture(skip: {'manifest.json'}));

    expect(result.exitCode, isNot(0));
    expect('${result.stderr}', contains('manifest.json'));
  });

  test('a stray root file cannot be staged into a release folder that already has one', () async {
    final out = Directory('${tmp.path}/release')..createSync();
    File('${out.path}/leftover.txt').writeAsStringSync('from an older run');

    final result = await stage(fixture());

    expect(result.exitCode, isNot(0));
    expect('${result.stderr}', contains('fresh directory'));
  });

  test('a build without the WebAssembly pieces fails before a layout is made', () async {
    final result = await stage(fixture(skip: {'sqlite3.wasm'}));

    expect(result.exitCode, isNot(0));
    expect('${result.stderr}', contains('sqlite3.wasm'));
  });
}
