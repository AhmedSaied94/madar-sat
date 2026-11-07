import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:madar_sat/core/config/remote_config.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/features/match_detail/presentation/live_center/live_center.dart';

/// [match]'s live center with both flags on, on a phone-sized page.
Widget liveCenterGolden(MatchDetail match, {required Size size, Duration? age}) => ProviderScope(
      overrides: [
        remoteConfigProvider.overrideWithValue(
          const RemoteConfigValues(
            apiBaseUrl: 'https://api.test',
            mediaBaseUrl: 'https://media.test',
            minSupportedBuild: 0,
            latestBuild: 0,
            livePollIntervalSeconds: 30,
            features: AppFeatures(liveCenter: true, lineups: true),
          ),
        ),
      ],
      child: SizedBox.fromSize(
        size: size,
        child: CustomScrollView(slivers: [LiveCenterSliver(match: match, age: age)]),
      ),
    );
