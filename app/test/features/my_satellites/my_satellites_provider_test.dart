import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/network/swr_repository.dart';
import 'package:madar_sat/features/my_satellites/data/my_satellites_provider.dart';

import '../../fixtures/sample_models.dart';

Satellite _satellite(int id, String slug) => Satellite(
      id: id,
      slug: slug,
      kind: Kind.satellite,
      nameAr: 'قمر $id',
      nameEn: slug,
      orbitalPosition: null,
      logo: null,
      channelCount: 10,
      bestFrequency: null,
      worstFrequency: null,
      receptionUrl: null,
    );

ProviderContainer _container(List<Satellite>? satellites) => ProviderContainer(
      overrides: [
        satellitesProvider.overrideWith(
          (ref) => satellites == null
              ? const Stream<SwrSnapshot<List<Satellite>>>.empty()
              : Stream.value(SwrSnapshot(data: satellites)),
        ),
      ],
    );

/// Holds a listener, as a screen would: Riverpod 3 pauses a provider nobody listens to.
Future<void> _loaded(ProviderContainer container) async {
  container.listen(satellitesProvider, (previous, next) {});
  await container.read(satellitesProvider.future);
}

void main() {
  test('my satellites default to Nilesat 7.0W and Badr, found by slug', () async {
    final container = _container([
      _satellite(7, 'hotbird-13-0e'),
      _satellite(2, 'nilesat-7-0w'),
      _satellite(5, 'badr-26-0e'),
    ]);
    addTearDown(container.dispose);

    await _loaded(container);

    expect(container.read(mySatelliteIdsProvider), {2, 5});
  });

  test('is empty until the satellite list has loaded, never a guess', () {
    final container = _container(null);
    addTearDown(container.dispose);

    expect(container.read(mySatelliteIdsProvider), isEmpty);
  });

  test('is empty when the server lists neither default', () async {
    final container = _container([_satellite(7, 'hotbird-13-0e')]);
    addTearDown(container.dispose);

    await _loaded(container);

    expect(container.read(mySatelliteIdsProvider), isEmpty);
  });

  test('a carriage is mine when its satellite slug is a default', () {
    expect(MySatellites.isMine(sampleSatellite), isTrue);
    expect(MySatellites.isMine(null), isFalse);
    expect(
      MySatellites.isMine(
        const SatelliteRef(
          id: 9,
          slug: 'hotbird-13-0e',
          nameAr: 'هوت بيرد',
          nameEn: 'Hot Bird',
          orbitalPosition: 13,
        ),
      ),
      isFalse,
    );
  });
}
