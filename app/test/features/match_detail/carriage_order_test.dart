import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/features/match_detail/domain/carriage_mapper.dart';
import 'package:madar_sat/features/match_detail/domain/carriage_order.dart';

import '../../fixtures/sample_match_detail.dart';
import '../../fixtures/sample_models.dart';

List<int> _ids(Iterable<CarriageEntry> entries) => [for (final e in entries) e.id];

/// FR-043: S3 puts my satellites first (the O10 default, Nilesat 7.0W and Badr, found by
/// slug), then the other satellites, then platforms. Inside a group a free channel comes
/// before an encrypted one, then the server's order. The API sends no hidden link, and
/// nothing here may invent one.
void main() {
  group('the three parts', () {
    final carriages = [
      sampleCarriageEntry(id: 1, satellite: hotbirdSatellite, access: Access.free),
      sampleCarriageEntry(id: 2, satellite: sampleSatellite),
      sampleCarriageEntry(id: 3, satellite: eutelSatellite),
      sampleCarriageEntry(id: 4, satellite: badrSatellite, access: Access.free),
      sampleCarriageEntry(id: 5, satellite: hotbirdSatellite),
    ];
    final platforms = [
      samplePlatformGroup('الشرق الأوسط', ['STC TV', 'Shasha']),
      samplePlatformGroup('أوروبا', ['DAZN']),
    ];

    test('my satellites come first, whatever order the server listed them in', () {
      final result = orderCarriages(carriages: carriages, platforms: platforms);

      expect(_ids(result.mine), [4, 2]);
    });

    test('the other satellites follow, one group each in the order they first appear', () {
      final result = orderCarriages(carriages: carriages, platforms: platforms);

      expect([for (final g in result.otherSatellites) g.satellite.slug], [
        'hotbird-13-0e',
        'eutel-16-0e',
      ]);
      expect(_ids(result.otherSatellites.first.carriages), [1, 5]);
      expect(_ids(result.otherSatellites.last.carriages), [3]);
    });

    test('platforms come last, by region, in the order the server sent them', () {
      final result = orderCarriages(carriages: carriages, platforms: platforms);

      expect([for (final g in result.platforms) g.region], ['الشرق الأوسط', 'أوروبا']);
      expect([for (final item in result.platforms.first.items) item.name], ['STC TV', 'Shasha']);
    });

    test('a link with no satellite is its own group, never one of my satellites', () {
      final result = orderCarriages(
        carriages: [
          sampleCarriageEntry(
            id: 8,
            satellite: null,
            frequency: null,
            kind: Kind.terrestrial,
            frequencyNote: 'UHF 32',
          ),
          sampleCarriageEntry(id: 9),
        ],
        platforms: const [],
      );

      expect(_ids(result.withoutSatellite), [8]);
      expect(_ids(result.mine), [9]);
      expect(result.otherSatellites, isEmpty);
    });

    test('mine is decided by the injected predicate, so D3 can swap in the user\'s choice', () {
      final result = orderCarriages(
        carriages: carriages,
        platforms: const [],
        isMine: (satellite) => satellite?.slug == 'eutel-16-0e',
      );

      expect(_ids(result.mine), [3]);
      // Hotbird (free first), then Nilesat, then Badr: the order the satellites first appear.
      expect(_ids(result.otherSatellites.expand((g) => g.carriages)), [1, 5, 2, 4]);
    });

    test('counts add up across the parts', () {
      final result = orderCarriages(carriages: carriages, platforms: platforms);

      expect(result.carriageCount, 5);
      expect(result.platformCount, 3);
      expect(result.total, 8);
      expect(result.isEmpty, isFalse);
      expect(orderCarriages(carriages: const [], platforms: const []).isEmpty, isTrue);
    });
  });

  group('inside a group', () {
    test('free comes before encrypted, then the server\'s order', () {
      final result = orderCarriages(
        carriages: [
          sampleCarriageEntry(id: 10, satellite: hotbirdSatellite),
          sampleCarriageEntry(id: 11, satellite: hotbirdSatellite, access: Access.free),
          sampleCarriageEntry(id: 12, satellite: hotbirdSatellite),
          sampleCarriageEntry(id: 13, satellite: hotbirdSatellite, access: Access.free),
        ],
        platforms: const [],
      );

      // Free: 11, 13 in the order sent; then encrypted: 10, 12 in the order sent.
      expect(_ids(result.otherSatellites.single.carriages), [11, 13, 10, 12]);
    });

    test('a link of unknown access sorts with the encrypted ones, after the free ones', () {
      final result = orderCarriages(
        carriages: [
          sampleCarriageEntry(id: 20, satellite: hotbirdSatellite, access: null),
          sampleCarriageEntry(id: 21, satellite: hotbirdSatellite, access: Access.free),
        ],
        platforms: const [],
      );

      expect(_ids(result.otherSatellites.single.carriages), [21, 20]);
    });

    test('my two satellites interleave by access, then by server order', () {
      final result = orderCarriages(
        carriages: [
          sampleCarriageEntry(id: 30, satellite: sampleSatellite),
          sampleCarriageEntry(id: 31, satellite: badrSatellite, access: Access.free),
          sampleCarriageEntry(id: 32, satellite: sampleSatellite, access: Access.free),
        ],
        platforms: const [],
      );

      expect(_ids(result.mine), [31, 32, 30]);
    });

    test('two rows with the same id are both kept, never merged', () {
      final result = orderCarriages(
        carriages: [
          sampleCarriageEntry(id: 40, satellite: hotbirdSatellite),
          sampleCarriageEntry(id: 40, satellite: hotbirdSatellite),
        ],
        platforms: const [],
      );

      expect(result.otherSatellites.single.carriages, hasLength(2));
    });
  });

  group('hidden links', () {
    test('only what the server sent comes back: nothing added, nothing dropped', () {
      final input = [
        for (var i = 1; i <= 40; i++)
          sampleCarriageEntry(
            id: i,
            satellite: i.isEven ? sampleSatellite : hotbirdSatellite,
            access: i % 3 == 0 ? Access.free : Access.encrypted,
          ),
      ];
      final platforms = [samplePlatformGroup('أوروبا', ['DAZN', 'Sky'])];

      final result = orderCarriages(carriages: input, platforms: platforms);

      final back = [
        ...result.mine,
        for (final group in result.otherSatellites) ...group.carriages,
        ...result.withoutSatellite,
      ];
      expect(back, hasLength(input.length));
      expect(_ids(back).toSet(), _ids(input).toSet());
      for (final entry in back) {
        expect(input.any((original) => identical(original, entry)), isTrue);
      }
      expect(result.platformCount, 2);
    });

    test('an empty input is empty, not padded with placeholders', () {
      final result = orderCarriages(carriages: const [], platforms: const []);

      expect(result.mine, isEmpty);
      expect(result.otherSatellites, isEmpty);
      expect(result.withoutSatellite, isEmpty);
      expect(result.platforms, isEmpty);
    });

    test('a platform group with no items is not shown', () {
      final result = orderCarriages(
        carriages: const [],
        platforms: [samplePlatformGroup('أوروبا', const [])],
      );

      expect(result.platforms, isEmpty);
    });
  });

  group('the toolbar filters', () {
    final carriages = [
      sampleCarriageEntry(id: 1, name: 'beIN SPORTS 1', satellite: sampleSatellite),
      sampleCarriageEntry(
        id: 2,
        name: 'ON Sport HD',
        satellite: sampleSatellite,
        access: Access.free,
        frequency: const Frequency(mhz: 11977, pol: Polarization.v, sr: 27500),
      ),
      sampleCarriageEntry(id: 3, name: 'DAZN 1', satellite: hotbirdSatellite),
      sampleCarriageEntry(id: 4, name: 'Eleven Sports', satellite: eutelSatellite, access: Access.free),
    ];
    final ordered = orderCarriages(
      carriages: carriages,
      platforms: [samplePlatformGroup('أوروبا', ['DAZN Platform'])],
    );

    test('free only keeps free carriages and drops platforms, whose access is unknown', () {
      final result = filterWhereToWatch(ordered, freeOnly: true);

      expect(_ids(result.mine), [2]);
      expect(_ids(result.otherSatellites.expand((g) => g.carriages)), [4]);
      expect(result.platforms, isEmpty);
    });

    test('a search matches a channel name without regard to case', () {
      final result = filterWhereToWatch(ordered, query: 'dazn');

      expect(result.mine, isEmpty);
      expect(_ids(result.otherSatellites.expand((g) => g.carriages)), [3]);
      expect([for (final item in result.platforms.expand((g) => g.items)) item.name], [
        'DAZN Platform',
      ]);
    });

    test('a search matches a satellite by its Arabic or English name', () {
      // Both Nilesat carriages, the free one first.
      expect(_ids(filterWhereToWatch(ordered, query: 'نايل').mine), [2, 1]);
      expect(
        _ids(filterWhereToWatch(ordered, query: 'Eutel').otherSatellites.expand((g) => g.carriages)),
        [4],
      );
    });

    test('a search matches frequency digits', () {
      final result = filterWhereToWatch(ordered, query: '11977');

      expect(_ids(result.mine), [2]);
      expect(result.otherSatellites, isEmpty);
    });

    test('groups left empty disappear, and no filter returns the input as it was', () {
      final result = filterWhereToWatch(ordered, query: 'Eleven');

      expect(result.mine, isEmpty);
      expect(result.otherSatellites, hasLength(1));
      expect(identical(filterWhereToWatch(ordered), ordered), isTrue);
      expect(filterWhereToWatch(ordered, query: '   ').total, ordered.total);
    });

    test('a search that matches nothing is empty', () {
      expect(filterWhereToWatch(ordered, query: 'zzzz').isEmpty, isTrue);
    });
  });

  group('CarriageEntry to ChannelCarriage', () {
    test('every field CarriageRow draws is carried over', () {
      final entry = sampleCarriageEntry(
        id: 7,
        name: 'beIN SPORTS 1 HD',
        displayName: 'beIN SPORTS 1',
        provider: 'beIN',
        access: Access.encrypted,
        changedAt: DateTime.utc(2026, 10, 20),
        country: 'قطر',
        commentators: const [sampleCommentator],
      );

      final carriage = carriageOf(entry);

      expect(carriage.id, 7);
      expect(carriage.name, 'beIN SPORTS 1 HD');
      expect(carriage.displayName, 'beIN SPORTS 1');
      expect(carriage.provider, 'beIN');
      expect(carriage.access, Access.encrypted);
      expect(carriage.satellite, sampleSatellite);
      expect(carriage.frequency, sampleFrequency);
      expect(carriage.kind, Kind.satellite);
      expect(carriage.category, Category.sports);
      expect(carriage.country, 'قطر');
      expect(carriage.frequencyChangedAt, DateTime.utc(2026, 10, 20));
    });
  });
}
