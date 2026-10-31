import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/features/frequencies/domain/channel_filter.dart';
import 'package:madar_sat/features/frequencies/domain/orbital_position.dart';
import 'package:madar_sat/features/frequencies/domain/satellite_filter.dart';
import 'package:madar_sat/features/frequencies/domain/search_normalize.dart';

import '../../fixtures/sample_satellites.dart';

List<int> _ids(Iterable<ChannelCarriage> channels) => [for (final c in channels) c.id];

/// The pure parts of S5: what a search matches, which tab a channel is in, how a satellite
/// position reads. The widgets are covered in `frequencies_test.dart`.
void main() {
  group('normalizeSearch', () {
    test('Latin is case-insensitive and accent-insensitive', () {
      expect(normalizeSearch('beIN SPORTS'), normalizeSearch('bein sports'));
      expect(normalizeSearch('Café'), 'cafe');
      expect(normalizeSearch('Ünal'), 'unal');
    });

    test('Arabic ignores diacritics and the letter variants a keyboard mixes up', () {
      expect(normalizeSearch('الأهلي'), normalizeSearch('الاهلي'));
      expect(normalizeSearch('مَدار'), normalizeSearch('مدار'));
      expect(normalizeSearch('قناة'), normalizeSearch('قناه'));
      expect(normalizeSearch('علي'), normalizeSearch('على'));
    });

    test('Arabic-Indic digits read as Western digits', () {
      expect(normalizeSearch('١١٨٤٣'), '11843');
    });

    test('punctuation becomes one space and the ends are trimmed', () {
      expect(normalizeSearch('  7.0W!  '), '7 0w');
      expect(normalizeSearch(null), '');
    });
  });

  group('filterChannels', () {
    final channels = [
      channelEntry(id: 1, name: 'beIN SPORTS 1 HD', displayName: 'beIN SPORTS 1', mhz: 11013),
      channelEntry(id: 2, name: 'ON Sport HD', access: Access.free, mhz: 11977, pol: Polarization.v),
      channelEntry(id: 3, name: 'Rotana Cinema', category: Category.entertainment, mhz: 11843),
      channelEntry(id: 4, name: 'MBC 4', category: Category.entertainment, mhz: 12188),
      channelEntry(id: 5, name: 'Sports Plus', category: Category.sports, mhz: 11843),
      channelEntry(id: 6, name: 'No Category', category: null, mhz: 10890),
      channelEntry(id: 7, name: 'UHF Local', mhz: null, frequencyNote: 'UHF 32'),
    ];

    test('keeps the tab and the server order', () {
      expect(_ids(filterChannels(channels, category: Category.sports)), [1, 2, 5, 7]);
      expect(_ids(filterChannels(channels, category: Category.entertainment)), [3, 4, 6]);
    });

    test('a channel with no category is listed with the entertainment ones, not lost', () {
      final all = {
        ..._ids(filterChannels(channels, category: Category.sports)),
        ..._ids(filterChannels(channels, category: Category.entertainment)),
      };

      expect(all, {for (final c in channels) c.id});
    });

    test('a number matches the start of a frequency in MHz', () {
      expect(_ids(filterChannels(channels, category: Category.sports, query: '11843')), [5]);
      expect(_ids(filterChannels(channels, category: Category.entertainment, query: '11843')), [3]);
      expect(_ids(filterChannels(channels, category: Category.sports, query: '119')), [2]);
    });

    test('a number is not matched inside a frequency', () {
      expect(filterChannels(channels, category: Category.sports, query: '843'), isEmpty);
    });

    test('a number also matches a name that holds it', () {
      // «MBC 4»: the server searches names and frequencies together, so a digit in a name
      // counts even though no frequency here starts with 4.
      expect(_ids(filterChannels(channels, category: Category.entertainment, query: '4')), [4]);
    });

    test('a name matches by its channel name or its display name, in any case', () {
      expect(_ids(filterChannels(channels, category: Category.sports, query: 'bein')), [1]);
      expect(_ids(filterChannels(channels, category: Category.sports, query: 'SPORTS 1')), [1]);
      expect(_ids(filterChannels(channels, category: Category.sports, query: 'plus')), [5]);
    });

    test('Arabic-Indic digits search like Western ones', () {
      expect(_ids(filterChannels(channels, category: Category.sports, query: '١١٨٤٣')), [5]);
    });

    test('a blank query lists the whole tab', () {
      expect(_ids(filterChannels(channels, category: Category.sports, query: '   ')), [1, 2, 5, 7]);
    });

    test('a query that matches nothing lists nothing', () {
      expect(filterChannels(channels, category: Category.sports, query: 'zzz'), isEmpty);
    });
  });

  group('channelCounts', () {
    test('counts each tab from the whole list', () {
      final counts = channelCounts([
        channelEntry(id: 1, name: 'a'),
        channelEntry(id: 2, name: 'b'),
        channelEntry(id: 3, name: 'c', category: Category.entertainment),
        channelEntry(id: 4, name: 'd', category: null),
      ]);

      expect(counts.sports, 2);
      expect(counts.entertainment, 2);
    });
  });

  group('satellites', () {
    final all = sampleSatellites();

    test('my satellites are pinned first and the rest keep the server order', () {
      final groups = partitionSatellites(all, isMine: (s) => {'nilesat-7-0w', 'badr-26-0e'}.contains(s.slug));

      expect([for (final s in groups.mine) s.id], [2, 5]);
      expect([for (final s in groups.others) s.id], [7]);
    });

    test('search matches the Arabic name, the English name and the position', () {
      expect([for (final s in filterSatellites(all, 'نايل')) s.id], [2]);
      expect([for (final s in filterSatellites(all, 'hotbird')) s.id], [7]);
      expect([for (final s in filterSatellites(all, '26')) s.id], [5]);
      expect([for (final s in filterSatellites(all, '7.0')) s.id], [2]);
      expect(filterSatellites(all, 'nothing like it'), isEmpty);
      expect(filterSatellites(all, ' '), hasLength(3));
    });
  });

  group('orbital position', () {
    test('west is negative, east is positive, one decimal', () {
      expect(OrbitalPosition.label(-7), '7.0W');
      expect(OrbitalPosition.label(26), '26.0E');
      expect(OrbitalPosition.label(0.8), '0.8E');
      expect(OrbitalPosition.label(-0.8), '0.8W');
    });

    test('the header form carries the degree sign', () {
      expect(OrbitalPosition.degrees(-7), '7.0°W');
      expect(OrbitalPosition.degrees(13), '13.0°E');
    });

    test('a satellite without a position has no label', () {
      expect(OrbitalPosition.label(null), isNull);
      expect(OrbitalPosition.degrees(null), isNull);
    });
  });
}
