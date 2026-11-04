import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/models/access.dart';
import 'package:madar_sat/core/network/generated/models/frequency_change.dart';
import 'package:madar_sat/core/network/generated/models/polarization.dart';
import 'package:madar_sat/features/channel/domain/channel_sections.dart';

import '../../fixtures/sample_details.dart';
import '../../fixtures/sample_match_detail.dart';
import '../../fixtures/sample_models.dart';

/// S6's pure rules: the other carriages' order, the sheet's own carriage, and the frequency
/// history (contract app-screens §S6).
void main() {
  group('other carriages', () {
    final mineOnBadr = sampleOtherCarriage(
      id: 1,
      name: 'beIN SPORTS 1 HD',
      satellite: badrSatellite,
      access: Access.encrypted,
    );
    final mineFree = sampleOtherCarriage(
      id: 2,
      name: 'beIN Free',
      satellite: badrSatellite,
      access: Access.free,
    );
    final otherFree = sampleOtherCarriage(
      id: 3,
      name: 'Free On Eutel',
      satellite: eutelSatellite,
      access: Access.free,
    );
    final otherEncrypted = sampleOtherCarriage(
      id: 4,
      name: 'DAZN 1',
      satellite: hotbirdSatellite,
      access: Access.encrypted,
    );

    List<int> order(List<dynamic> carriages, {Set<int> mine = const {}}) => [
          for (final carriage in otherCarriages(
            sampleChannelDetail(otherCarriages: [...carriages.cast()]),
            mySatelliteIds: mine,
          ))
            carriage.id,
        ];

    test('my satellites come first, then the free ones, then the rest', () {
      expect(
        order(
          [otherEncrypted, otherFree, mineOnBadr, mineFree],
          mine: {badrSatellite.id},
        ),
        [2, 1, 3, 4],
      );
    });

    test('with none of them mine, the free one still comes first', () {
      expect(order([otherEncrypted, otherFree]), [3, 4]);
    });

    test('two carriages on the same satellite are ordered by name, then id', () {
      final a = sampleOtherCarriage(id: 9, name: 'Alpha', satellite: hotbirdSatellite);
      final b = sampleOtherCarriage(id: 8, name: 'Beta', satellite: hotbirdSatellite);

      expect(order([b, a]), [9, 8]);
    });

    test('a carriage with no satellite sorts last, never first', () {
      final terrestrial = sampleOtherCarriage(
        id: 7,
        name: 'Terrestrial',
        withSatellite: false,
      );

      expect(order([terrestrial, otherEncrypted]).last, 7);
    });
  });

  group('the sheet’s own carriage', () {
    test('takes the display name, the tuning, the access and the package', () {
      final view = ChannelCarriageView.of(sampleChannelDetail());

      expect(view.name, 'beIN SPORTS 1');
      expect(view.header, 'beIN SPORTS 1 HD');
      expect(view.satelliteNameAr, sampleSatellite.nameAr);
      expect(view.satelliteNameEn, sampleSatellite.nameEn);
      expect(view.frequency!.mhz, 11013);
      expect(view.access, Access.encrypted);
      expect(view.provider, 'beIN');
      expect(view.package, 'beIN Sports');
    });

    test('falls back to the name when there is no display name', () {
      expect(ChannelCarriageView.of(sampleChannelDetail(displayName: null)).name, 'beIN SPORTS 1 HD');
    });

    test('a terrestrial channel keeps its note instead of a tuning', () {
      final view = ChannelCarriageView.of(
        sampleChannelDetail(satellite: null, frequency: null, frequencyNote: 'UHF 32'),
      );

      expect(view.frequency, isNull);
      expect(view.frequencyNote, 'UHF 32');
      expect(view.satelliteNameAr, isNull);
    });
  });

  group('frequency history', () {
    FrequencyChange change({
      required String detectedAt,
      required int from,
      required int to,
      String polarization = 'H',
    }) =>
        FrequencyChange.fromJson(
          frequencyChangeJson(
            detectedAt: detectedAt,
            from: from,
            to: to,
            polarization: polarization,
          ),
        );

    test('is empty until D6 fills it', () {
      expect(frequencyHistory(const []), isEmpty);
    });

    test('reads the contract type, newest first', () {
      final changes = frequencyHistory([
        change(detectedAt: '2026-09-02T09:00:00Z', from: 11861, to: 11766),
        change(detectedAt: '2026-10-20T09:12:00Z', from: 11766, to: 11013),
      ]);

      expect(changes, hasLength(2));
      expect(changes.first.detectedAt, DateTime.utc(2026, 10, 20, 9, 12));
      expect(changes.first.before.mhz, 11766);
      expect(changes.first.after.mhz, 11013);
      expect(changes.first.after.pol, Polarization.h);
      expect(changes.first.after.sr, 27500);
    });

    test('keeps the polarization it was told', () {
      final changes = frequencyHistory([
        change(detectedAt: '2026-10-20T09:12:00Z', from: 11861, to: 11766, polarization: 'V'),
      ]);

      expect(changes.single.after.pol, Polarization.v);
    });

    test('lists at most three', () {
      final changes = frequencyHistory([
        for (var day = 1; day <= 5; day++)
          change(
            detectedAt: '2026-10-0${day}T09:00:00Z',
            from: 11700 + day,
            to: 11800 + day,
          ),
      ]);

      expect(changes, hasLength(3));
      expect(changes.first.after.mhz, 11805, reason: 'the newest change is kept first');
      expect(changes.last.after.mhz, 11803);
    });
  });

}
