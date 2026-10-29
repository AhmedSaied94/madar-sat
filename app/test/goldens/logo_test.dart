import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/theme/madar_tokens.dart';
import 'package:madar_sat/design/components/logo.dart';

import '../fixtures/test_app.dart';
import 'golden_harness.dart';

void main() {
  Widget states(BuildContext context) => const Column(
        children: [
          Wrap(
            spacing: MadarSpace.s3,
            runSpacing: MadarSpace.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              BrandMark(size: BrandMarkSize.s28),
              BrandMark(size: BrandMarkSize.m40),
              BrandMark(size: BrandMarkSize.l64),
              BrandMark(size: BrandMarkSize.m40, tone: BrandMarkTone.bare),
              BrandMark(size: BrandMarkSize.m40, tone: BrandMarkTone.mono),
            ],
          ),
          SizedBox(height: MadarSpace.s3),
          MadarWordmark(wordmark: 'مدار'),
          SizedBox(height: MadarSpace.s3),
          Wrap(
            spacing: MadarSpace.s3,
            runSpacing: MadarSpace.s2,
            children: [
              TeamCrest(name: 'الأهلي'),
              TeamCrest(name: null),
              LogoTile(kind: LogoTileKind.team, fallbackText: 'Ahly'),
              LogoTile(kind: LogoTileKind.competition),
              LogoTile(kind: LogoTileKind.channel, fallbackText: 'ON Sport'),
              LogoTile(kind: LogoTileKind.satellite),
              LogoTile(kind: LogoTileKind.commentator, fallbackText: 'عماد'),
            ],
          ),
        ],
      );

  testWidgets('Logo golden variants', (tester) async {
    await goldenVariants(tester, 'logo', states);
  });

  testWidgets('a logo sits in the same neutral frame, from an image not the network', (tester) async {
    final image = MemoryImage(_transparentPng);
    await tester.pumpWidget(
      testApp(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TeamCrest(name: 'الأهلي', logo: image),
            LogoTile(kind: LogoTileKind.channel, logo: image, fallbackText: 'ON'),
          ],
        ),
      ),
    );
    expect(find.byType(Image), findsNWidgets(2));
  });

  testWidgets('the wordmark stays «مدار» whatever the product name is', (tester) async {
    await tester.pumpWidget(testApp(const MadarWordmark(wordmark: 'مدار')));
    expect(find.text('مدار'), findsOneWidget);
    expect(find.text('مدار سات'), findsNothing);
  });
}

/// A 1×1 transparent PNG: a test asset, so no widget test touches the network.
final Uint8List _transparentPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);
