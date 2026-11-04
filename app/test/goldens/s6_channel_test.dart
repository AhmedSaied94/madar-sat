import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/theme/madar_tokens.dart';
import 'package:madar_sat/features/channel/domain/channel_sections.dart';
import 'package:madar_sat/features/channel/presentation/channel_sections.dart';

import '../fixtures/sample_details.dart';
import '../fixtures/sample_match_detail.dart';
import '../fixtures/sample_models.dart';
import 'golden_harness.dart';

/// S6's sheet as the board draws it, in RTL × {light, dark} × {1.0, 1.3} (T081, FR-044).
///
/// The sections are composed without the router: the page around them is the sheet chrome,
/// which the widget tests cover. Nothing here is live, so no dot animates.
void main() {
  testWidgets('S6 channel sheet golden variants', (tester) async {
    final detail = sampleChannelDetail();
    final other = otherCarriages(
      sampleChannelDetail(
        otherCarriages: [
          sampleOtherCarriage(id: 2, satellite: badrSatellite),
          sampleOtherCarriage(
            id: 3,
            satellite: hotbirdSatellite,
            access: Access.free,
          ),
        ],
      ),
      mySatelliteIds: {badrSatellite.id},
    );
    final history = frequencyHistory([
      frequencyChangeJson(detectedAt: '2026-10-20T09:12:00Z', from: 11766, to: 11013),
      frequencyChangeJson(detectedAt: '2026-09-02T09:00:00Z', from: 11861, to: 11766),
    ]);

    await goldenVariants(
      tester,
      's6_channel',
      (context) => Padding(
        padding: const EdgeInsetsDirectional.all(MadarSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ChannelSheetHeader(
              detail: const ChannelSheetHeaderData(
                logo: null,
                category: Category.sports,
                country: 'قطر',
              ),
              name: 'beIN SPORTS 1',
              onShare: () {},
            ),
            const SizedBox(height: MadarSpace.s3),
            CarriageCard(
              carriage: ChannelCarriageView.of(detail),
              isMine: true,
              onCopy: () {},
            ),
            const SizedBox(height: MadarSpace.s3),
            FollowChannelButton(following: false, onPressed: () {}),
            OtherCarriagesSection(carriages: other),
            ChannelUpcomingSection(
              matches: [
                sampleTeamMatch(id: 101, kickoff: sampleKickoffAt(hour: 16)),
                sampleTeamMatch(
                  id: 102,
                  kickoff: DateTime(2026, 10, 29, 17).toUtc(),
                  home: 'ليفربول',
                  away: 'تشيلسي',
                ),
              ],
              now: sampleNow(),
              onOpen: (_) {},
            ),
            FrequencyHistorySection(changes: history),
          ],
        ),
      ),
      size: const Size(360, 1000),
    );
  });
}
