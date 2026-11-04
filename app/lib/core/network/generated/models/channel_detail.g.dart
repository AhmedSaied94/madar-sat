// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channel_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChannelDetail _$ChannelDetailFromJson(Map<String, dynamic> json) =>
    _ChannelDetail(
      access: json['access'] == null
          ? null
          : Access.fromJson(json['access'] as String),
      beam: json['beam'] == null ? null : Beam.fromJson(json['beam'] as String),
      category: json['category'] == null
          ? null
          : Category.fromJson(json['category'] as String),
      country: json['country'] as String?,
      displayName: json['display_name'] as String?,
      frequency: json['frequency'] == null
          ? null
          : Frequency.fromJson(json['frequency'] as Map<String, dynamic>),
      frequencyChangedAt: json['frequency_changed_at'] == null
          ? null
          : DateTime.parse(json['frequency_changed_at'] as String),
      frequencyNote: json['frequency_note'] as String?,
      id: (json['id'] as num).toInt(),
      kind: Kind.fromJson(json['kind'] as String),
      logo: json['logo'] as String?,
      name: json['name'] as String,
      otherCarriages: (json['other_carriages'] as List<dynamic>)
          .map((e) => ChannelCarriage.fromJson(e as Map<String, dynamic>))
          .toList(),
      package: json['package'] as String?,
      provider: json['provider'] as String?,
      recentFrequencyChanges:
          (json['recent_frequency_changes'] as List<dynamic>)
              .map((e) => FrequencyChange.fromJson(e as Map<String, dynamic>))
              .toList(),
      satellite: json['satellite'] == null
          ? null
          : SatelliteRef.fromJson(json['satellite'] as Map<String, dynamic>),
      upcomingMatches: (json['upcoming_matches'] as List<dynamic>)
          .map((e) => MatchSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ChannelDetailToJson(_ChannelDetail instance) =>
    <String, dynamic>{
      'access': ?_$AccessEnumMap[instance.access],
      'beam': ?_$BeamEnumMap[instance.beam],
      'category': ?_$CategoryEnumMap[instance.category],
      'country': ?instance.country,
      'display_name': ?instance.displayName,
      'frequency': ?instance.frequency,
      'frequency_changed_at': ?instance.frequencyChangedAt?.toIso8601String(),
      'frequency_note': ?instance.frequencyNote,
      'id': instance.id,
      'kind': _$KindEnumMap[instance.kind]!,
      'logo': ?instance.logo,
      'name': instance.name,
      'other_carriages': instance.otherCarriages,
      'package': ?instance.package,
      'provider': ?instance.provider,
      'recent_frequency_changes': instance.recentFrequencyChanges,
      'satellite': ?instance.satellite,
      'upcoming_matches': instance.upcomingMatches,
    };

const _$AccessEnumMap = {
  Access.free: 'free',
  Access.encrypted: 'encrypted',
  Access.$unknown: r'$unknown',
};

const _$BeamEnumMap = {
  Beam.wide: 'wide',
  Beam.narrow: 'narrow',
  Beam.$unknown: r'$unknown',
};

const _$CategoryEnumMap = {
  Category.sports: 'sports',
  Category.entertainment: 'entertainment',
  Category.$unknown: r'$unknown',
};

const _$KindEnumMap = {
  Kind.satellite: 'satellite',
  Kind.terrestrial: 'terrestrial',
  Kind.platform: 'platform',
  Kind.$unknown: r'$unknown',
};
