import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `tool/write_env.sh` turns the `APP_ENV_PROD` secret into `env/prod.json` (docs/runbooks/
/// secrets.md). The template lists the keys; the release workflows need an exact match, and a
/// pull request's checks tolerate a key the template has and the secret does not yet, so the
/// change that introduces a key can run its checks before the owner updates the secret.
///
/// The script is copied into a throwaway tree with its own `env/example.json`, so the test does
/// not depend on the checkout's template (the test box syncs without git-ignored files).
void main() {
  const template = {'API_BASE_URL': '', 'MIRROR_BASE_URL': '', 'SHARE_URL': ''};

  late Directory tmp;
  late String root;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('madar-env-');
    root = '${tmp.path}/repo';
    File('$root/env/example.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(template));
    File('$root/tool/write_env.sh')
      ..createSync(recursive: true)
      ..writeAsStringSync(File('tool/write_env.sh').readAsStringSync());
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<ProcessResult> write(Map<String, Object?>? secret, {bool orExample = false}) {
    final env = {...Platform.environment}..remove('APP_ENV_JSON');
    if (secret != null) env['APP_ENV_JSON'] = jsonEncode(secret);
    return Process.run(
      'bash',
      ['tool/write_env.sh', 'env/prod.json', if (orExample) '--or-example'],
      workingDirectory: root,
      environment: env,
    );
  }

  Map<String, Object?> written() =>
      jsonDecode(File('$root/env/prod.json').readAsStringSync()) as Map<String, Object?>;

  test('a complete secret is written as it came', () async {
    final result = await write({
      'API_BASE_URL': 'https://api.test',
      'MIRROR_BASE_URL': 'https://app.test',
      'SHARE_URL': 'https://madar-sat.web.app',
    });

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(written()['API_BASE_URL'], 'https://api.test');
    expect(written().keys.toSet(), template.keys.toSet());
  });

  test('a missing key fails a release build', () async {
    final result = await write({'API_BASE_URL': 'https://api.test', 'SHARE_URL': 'x'});

    expect(result.exitCode, isNot(0));
    expect('${result.stderr}', contains('MIRROR_BASE_URL'));
  });

  test('a missing key only warns when the run already tolerates a missing secret', () async {
    final result = await write(
      {'API_BASE_URL': 'https://api.test', 'SHARE_URL': 'x'},
      orExample: true,
    );

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(written()['MIRROR_BASE_URL'], '');
    expect(written().keys.toSet(), template.keys.toSet());
    // An annotation is read from either stream; the script prints this one with the summary.
    expect(
      '${result.stdout}${result.stderr}',
      contains('::warning'),
      reason: 'the job summary names the gap',
    );
  });

  test('a key the template does not list fails in both modes', () async {
    final values = {
      'API_BASE_URL': 'x',
      'MIRROR_BASE_URL': 'x',
      'SHARE_URL': 'x',
      'UNKNOWN_KEY': 'y',
    };

    for (final orExample in [false, true]) {
      final result = await write(values, orExample: orExample);
      expect(result.exitCode, isNot(0), reason: 'orExample=$orExample');
      expect('${result.stderr}', contains('UNKNOWN_KEY'), reason: 'orExample=$orExample');
    }
  });

  test('a non-string value fails in both modes', () async {
    final values = <String, Object?>{
      'API_BASE_URL': 'x',
      'MIRROR_BASE_URL': 'x',
      'SHARE_URL': 1,
    };

    for (final orExample in [false, true]) {
      final result = await write(values, orExample: orExample);
      expect(result.exitCode, isNot(0), reason: 'orExample=$orExample');
      expect('${result.stderr}', contains('SHARE_URL'), reason: 'orExample=$orExample');
    }
  });

  test('an empty secret falls back to the template only when asked', () async {
    final tolerated = await write(null, orExample: true);
    expect(tolerated.exitCode, 0, reason: '${tolerated.stderr}');
    expect(written(), template);

    final refused = await write(null);
    expect(refused.exitCode, isNot(0));
    expect('${refused.stderr}', contains('APP_ENV_JSON'));
  });

  test('the checkout template lists the mirror base', () {
    final file = File('env/example.json');
    if (!file.existsSync()) {
      markTestSkipped('env/example.json is not synced to this checkout; CI has it');
      return;
    }
    expect(
      (jsonDecode(file.readAsStringSync()) as Map).containsKey('MIRROR_BASE_URL'),
      isTrue,
      reason: 'T065: the stage script reads it, and the owner adds it to APP_ENV_PROD',
    );
  });
}
