// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/category.dart';
import '../models/device_register.dart';
import '../models/device_update.dart';
import '../models/envelope_channel_detail.dart';
import '../models/envelope_commentator_detail.dart';
import '../models/envelope_competition_detail.dart';
import '../models/envelope_device.dart';
import '../models/envelope_device_registered.dart';
import '../models/envelope_follow_set.dart';
import '../models/envelope_health_status.dart';
import '../models/envelope_list_channel_carriage.dart';
import '../models/envelope_list_competition.dart';
import '../models/envelope_list_live_state.dart';
import '../models/envelope_list_match_summary.dart';
import '../models/envelope_list_rights_holder.dart';
import '../models/envelope_list_satellite.dart';
import '../models/envelope_list_team_search_item.dart';
import '../models/envelope_match_detail.dart';
import '../models/envelope_rights_holder_detail.dart';
import '../models/envelope_team_detail.dart';
import '../models/follow_set.dart';
import '../models/sport.dart';
import '../models/status.dart';

part 'madar_api_client.g.dart';

@RestApi()
abstract class MadarApiClient {
  factory MadarApiClient(Dio dio, {String? baseUrl}) = _MadarApiClient;

  /// Health Endpoint
  @GET('/healthz')
  Future<HttpResponse<EnvelopeHealthStatus>> healthEndpointHealthzGet();

  /// Get Channel
  @GET('/v1/channels/{channel_id}')
  Future<HttpResponse<EnvelopeChannelDetail>> getChannelV1ChannelsChannelIdGet({
    @Path('channel_id') required int channelId,
  });

  /// Get Commentator
  @GET('/v1/commentators/{commentator_id}')
  Future<HttpResponse<EnvelopeCommentatorDetail>> getCommentatorV1CommentatorsCommentatorIdGet({
    @Path('commentator_id') required int commentatorId,
  });

  /// List Competitions
  @GET('/v1/competitions')
  Future<HttpResponse<EnvelopeListCompetition>> listCompetitionsV1CompetitionsGet();

  /// Get Competition
  @GET('/v1/competitions/{competition_id}')
  Future<HttpResponse<EnvelopeCompetitionDetail>> getCompetitionV1CompetitionsCompetitionIdGet({
    @Path('competition_id') required int competitionId,
  });

  /// Register an install id, or rotate its token
  @POST('/v1/devices')
  Future<HttpResponse<EnvelopeDeviceRegistered>> registerDeviceV1DevicesPost({
    @Body() required DeviceRegister body,
  });

  /// Delete this device and its follows
  @DELETE('/v1/devices/me')
  Future<HttpResponse<void>> deleteDeviceV1DevicesMeDelete();

  /// Update this device's push token, app version, locale, time zone, satellites or prefs
  @PUT('/v1/devices/me')
  Future<HttpResponse<EnvelopeDevice>> updateDeviceV1DevicesMePut({
    @Body() required DeviceUpdate body,
  });

  /// Replace this device's whole follow set (atomic; ≤ 500 ids)
  @PUT('/v1/devices/me/follows')
  Future<HttpResponse<EnvelopeFollowSet>> replaceFollowsV1DevicesMeFollowsPut({
    @Body() required FollowSet body,
  });

  /// Get Live
  @GET('/v1/live')
  Future<HttpResponse<EnvelopeListLiveState>> getLiveV1LiveGet();

  /// List Matches
  @GET('/v1/matches')
  Future<HttpResponse<EnvelopeListMatchSummary>> listMatchesV1MatchesGet({
    @Query('from') required DateTime from,
    @Query('to') required DateTime to,
    @Query('sport') Sport? sport,
    @Query('competition_id') int? competitionId,
    @Query('team_id') int? teamId,
    @Query('satellite_ids') String? satelliteIds,
    @Query('my_satellite_ids') String? mySatelliteIds,
    @Query('status') Status? status,
  });

  /// Get Match
  @GET('/v1/matches/{match_id}')
  Future<HttpResponse<EnvelopeMatchDetail>> getMatchV1MatchesMatchIdGet({
    @Path('match_id') required int matchId,
  });

  /// List Rights Holders
  @GET('/v1/rights-holders')
  Future<HttpResponse<EnvelopeListRightsHolder>> listRightsHoldersV1RightsHoldersGet({
    @Query('satellite_id') int? satelliteId,
    @Query('competition_id') int? competitionId,
  });

  /// Get Rights Holder
  @GET('/v1/rights-holders/{rights_holder_id}')
  Future<HttpResponse<EnvelopeRightsHolderDetail>> getRightsHolderV1RightsHoldersRightsHolderIdGet({
    @Path('rights_holder_id') required int rightsHolderId,
  });

  /// List Satellites
  @GET('/v1/satellites')
  Future<HttpResponse<EnvelopeListSatellite>> listSatellitesV1SatellitesGet();

  /// List Satellite Channels
  @GET('/v1/satellites/{satellite_id}/channels')
  Future<HttpResponse<EnvelopeListChannelCarriage>> listSatelliteChannelsV1SatellitesSatelliteIdChannelsGet({
    @Path('satellite_id') required int satelliteId,
    @Query('category') Category? category,
    @Query('q') String? q,
  });

  /// Search Teams
  @GET('/v1/teams')
  Future<HttpResponse<EnvelopeListTeamSearchItem>> searchTeamsV1TeamsGet({
    @Query('q') required String q,
    @Query('cursor') String? cursor,
    @Query('limit') int? limit = 20,
  });

  /// Get Team
  @GET('/v1/teams/{team_id}')
  Future<HttpResponse<EnvelopeTeamDetail>> getTeamV1TeamsTeamIdGet({
    @Path('team_id') required int teamId,
  });
}
