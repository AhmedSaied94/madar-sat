import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every provider in `lib/` is generated with `@riverpod` (M-R1-16, constitution VIII):
/// no hand-written `Provider(`, `NotifierProvider(`, `StreamProvider(`, `FutureProvider(`,
/// `StateProvider(`, `StateNotifierProvider<A, B>(`, `ChangeNotifierProvider(` or
/// `AsyncNotifierProvider<A, B>(`, and none of their `.autoDispose` or `.family` forms.
///
/// It looks for the **constructor call**, not for a declaration, so a name without the
/// `Provider` suffix and a declaration split over two lines are caught as well, and it
/// accepts the `.autoDispose` and `.family` modifiers in either order, which are the usual
/// hand-written forms on Riverpod 3 (M-R3-1). This runs as part of `flutter test`.
void main() {
  /// A hand-written Riverpod provider being constructed: `Provider(…)`, `Provider<int>(…)`,
  /// `Provider.autoDispose(…)`, `Provider.family<A, B>(…)`,
  /// `Provider.autoDispose.family<A, B>(…)`. The Riverpod 2 `AutoDispose*` names stay in
  /// the list, so a project that pinned 2.x would be caught too.
  final constructor = RegExp(
    r'\b(Provider|NotifierProvider|AsyncNotifierProvider|StreamProvider|FutureProvider'
    r'|StateProvider|StateNotifierProvider|ChangeNotifierProvider'
    r'|AutoDisposeProvider|AutoDisposeNotifierProvider|AutoDisposeAsyncNotifierProvider'
    r'|AutoDisposeStreamProvider|AutoDisposeFutureProvider|AutoDisposeStateProvider'
    r'|AutoDisposeStateNotifierProvider|AutoDisposeChangeNotifierProvider)'
    r'(\.(autoDispose|family))*\s*(<|\()',
  );

  /// [source] without its comments: a comment naming a provider is not one.
  String code(String source) => source
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//[^\n]*'), '');

  bool handWritten(String source) => constructor.hasMatch(code(source));

  /// The files under [dir] that hand-write one. The generator's own output is skipped
  /// (`*.g.dart`, whose provider wrappers carry the class names above, and the generated
  /// client); anything else that hand-writes a provider is a mistake.
  List<String> offendersIn(String dir) {
    final offenders = <String>[];
    for (final entity in Directory(dir).listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll('\\', '/');
      if (!path.endsWith('.dart')) continue;
      if (path.endsWith('.g.dart') || path.startsWith('lib/core/network/generated/')) continue;
      if (handWritten(entity.readAsStringSync())) offenders.add(path);
    }
    return offenders;
  }

  test('the check catches each way a provider is hand-written', () {
    const offenders = <String>[
      'final counter = Provider((ref) => 0);',
      'final counterProvider = Provider<int>((ref) => 0);',
      'final state = NotifierProvider<A, int>(A.new);',
      'final state = StateNotifierProvider<A, int>((ref) => A());',
      'final model = ChangeNotifierProvider((ref) => A());',
      'final async = AsyncNotifierProvider<A, int>(A.new);',
      'final stream = StreamProvider<int>((ref) => const Stream<int>.empty());',
      'final future = FutureProvider((ref) async => 1);',
      'final state = StateProvider((ref) => 0);',
      // The declaration split over two lines, which a line-based pattern misses.
      'final counter =\n    Provider<int>((ref) => 0);',
      // Riverpod 3's modifiers, which a pattern needing `<` or `(` right after the class
      // name misses (M-R3-1).
      'final future = FutureProvider.autoDispose((ref) async => 1);',
      'final stream = StreamProvider.autoDispose((ref) => const Stream<int>.empty());',
      'final counter = Provider.family<int, String>((ref, id) => 0);',
      'final state = NotifierProvider.autoDispose<A, B>(A.new);',
      'final counter = Provider.autoDispose.family<int, String>((ref, id) => 0);',
      'final counter = Provider.family.autoDispose<int, String>((ref, id) => 0);',
    ];
    for (final source in offenders) {
      expect(handWritten(source), isTrue, reason: source);
    }

    const allowed = <String>[
      '@riverpod\nint counter(Ref ref) => 0;',
      '@riverpod\nclass Counter extends _\$Counter { @override int build() => 0; }',
      'final container = ProviderContainer();',
      'const scope = ProviderScope(child: SizedBox());',
      'ref.watch(counterProvider);',
      'overrides: [counterProvider.overrideWithValue(1)],',
      '// never write Provider( by hand',
      '/* a Provider( in a comment is not one */',
      '/* FutureProvider.autoDispose( is not one either */',
    ];
    for (final source in allowed) {
      expect(handWritten(source), isFalse, reason: source);
    }
  });

  test('lib/ holds no hand-written provider', () {
    expect(
      offendersIn('lib'),
      isEmpty,
      reason: 'write a @riverpod function or class and run build_runner',
    );
  });
}
