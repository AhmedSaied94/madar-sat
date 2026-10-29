// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'match_detail.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MatchDetail {

 TeamRef get away; Broadcast get broadcast; List<BroadcastEntry> get broadcasts; List<CarriageEntry> get carriages; CommentatorRef? get commentator; CompetitionRef get competition; bool get estimated; List<dynamic> get events;@JsonKey(name: 'feed_id') int? get feedId; TeamRef get home; int get id;@JsonKey(name: 'kickoff_at') DateTime? get kickoffAt; dynamic get lineups;@JsonKey(name: 'local_broadcaster_eg') String? get localBroadcasterEg;@JsonKey(name: 'match_date') DateTime get matchDate; String? get minute; Period? get period; List<PlatformGroup> get platforms; Score? get score; Sport get sport; String? get stadium; Status get status;@JsonKey(name: 'status_label') String? get statusLabel;@JsonKey(name: 'time_tbd') bool get timeTbd;@JsonKey(name: 'updated_at') DateTime get updatedAt;
/// Create a copy of MatchDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MatchDetailCopyWith<MatchDetail> get copyWith => _$MatchDetailCopyWithImpl<MatchDetail>(this as MatchDetail, _$identity);

  /// Serializes this MatchDetail to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MatchDetail;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MatchDetail&&(identical(other.away, _this.away) || other.away == _this.away)&&(identical(other.broadcast, _this.broadcast) || other.broadcast == _this.broadcast)&&const DeepCollectionEquality().equals(other.broadcasts, _this.broadcasts)&&const DeepCollectionEquality().equals(other.carriages, _this.carriages)&&(identical(other.commentator, _this.commentator) || other.commentator == _this.commentator)&&(identical(other.competition, _this.competition) || other.competition == _this.competition)&&(identical(other.estimated, _this.estimated) || other.estimated == _this.estimated)&&const DeepCollectionEquality().equals(other.events, _this.events)&&(identical(other.feedId, _this.feedId) || other.feedId == _this.feedId)&&(identical(other.home, _this.home) || other.home == _this.home)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.kickoffAt, _this.kickoffAt) || other.kickoffAt == _this.kickoffAt)&&const DeepCollectionEquality().equals(other.lineups, _this.lineups)&&(identical(other.localBroadcasterEg, _this.localBroadcasterEg) || other.localBroadcasterEg == _this.localBroadcasterEg)&&(identical(other.matchDate, _this.matchDate) || other.matchDate == _this.matchDate)&&(identical(other.minute, _this.minute) || other.minute == _this.minute)&&(identical(other.period, _this.period) || other.period == _this.period)&&const DeepCollectionEquality().equals(other.platforms, _this.platforms)&&(identical(other.score, _this.score) || other.score == _this.score)&&(identical(other.sport, _this.sport) || other.sport == _this.sport)&&(identical(other.stadium, _this.stadium) || other.stadium == _this.stadium)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.statusLabel, _this.statusLabel) || other.statusLabel == _this.statusLabel)&&(identical(other.timeTbd, _this.timeTbd) || other.timeTbd == _this.timeTbd)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MatchDetail;
  return Object.hashAll([runtimeType,_this.away,_this.broadcast,const DeepCollectionEquality().hash(_this.broadcasts),const DeepCollectionEquality().hash(_this.carriages),_this.commentator,_this.competition,_this.estimated,const DeepCollectionEquality().hash(_this.events),_this.feedId,_this.home,_this.id,_this.kickoffAt,const DeepCollectionEquality().hash(_this.lineups),_this.localBroadcasterEg,_this.matchDate,_this.minute,_this.period,const DeepCollectionEquality().hash(_this.platforms),_this.score,_this.sport,_this.stadium,_this.status,_this.statusLabel,_this.timeTbd,_this.updatedAt]);
}

@override
String toString() {
  final _this = this as MatchDetail;
  return 'MatchDetail(away: ${_this.away}, broadcast: ${_this.broadcast}, broadcasts: ${_this.broadcasts}, carriages: ${_this.carriages}, commentator: ${_this.commentator}, competition: ${_this.competition}, estimated: ${_this.estimated}, events: ${_this.events}, feedId: ${_this.feedId}, home: ${_this.home}, id: ${_this.id}, kickoffAt: ${_this.kickoffAt}, lineups: ${_this.lineups}, localBroadcasterEg: ${_this.localBroadcasterEg}, matchDate: ${_this.matchDate}, minute: ${_this.minute}, period: ${_this.period}, platforms: ${_this.platforms}, score: ${_this.score}, sport: ${_this.sport}, stadium: ${_this.stadium}, status: ${_this.status}, statusLabel: ${_this.statusLabel}, timeTbd: ${_this.timeTbd}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $MatchDetailCopyWith<$Res>  {
  factory $MatchDetailCopyWith(MatchDetail value, $Res Function(MatchDetail) _then) = _$MatchDetailCopyWithImpl;
@useResult
$Res call({
 TeamRef away, Broadcast broadcast, List<BroadcastEntry> broadcasts, List<CarriageEntry> carriages, CommentatorRef? commentator, CompetitionRef competition, bool estimated, List<dynamic> events,@JsonKey(name: 'feed_id') int? feedId, TeamRef home, int id,@JsonKey(name: 'kickoff_at') DateTime? kickoffAt, dynamic lineups,@JsonKey(name: 'local_broadcaster_eg') String? localBroadcasterEg,@JsonKey(name: 'match_date') DateTime matchDate, String? minute, Period? period, List<PlatformGroup> platforms, Score? score, Sport sport, String? stadium, Status status,@JsonKey(name: 'status_label') String? statusLabel,@JsonKey(name: 'time_tbd') bool timeTbd,@JsonKey(name: 'updated_at') DateTime updatedAt
});


$TeamRefCopyWith<$Res> get away;$BroadcastCopyWith<$Res> get broadcast;$CommentatorRefCopyWith<$Res>? get commentator;$CompetitionRefCopyWith<$Res> get competition;$TeamRefCopyWith<$Res> get home;$ScoreCopyWith<$Res>? get score;

}
/// @nodoc
class _$MatchDetailCopyWithImpl<$Res>
    implements $MatchDetailCopyWith<$Res> {
  _$MatchDetailCopyWithImpl(this._self, this._then);

  final MatchDetail _self;
  final $Res Function(MatchDetail) _then;

/// Create a copy of MatchDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? away = null,Object? broadcast = null,Object? broadcasts = null,Object? carriages = null,Object? commentator = freezed,Object? competition = null,Object? estimated = null,Object? events = null,Object? feedId = freezed,Object? home = null,Object? id = null,Object? kickoffAt = freezed,Object? lineups = freezed,Object? localBroadcasterEg = freezed,Object? matchDate = null,Object? minute = freezed,Object? period = freezed,Object? platforms = null,Object? score = freezed,Object? sport = null,Object? stadium = freezed,Object? status = null,Object? statusLabel = freezed,Object? timeTbd = null,Object? updatedAt = null,}) {
  return _then(MatchDetail(
away: null == away ? _self.away : away // ignore: cast_nullable_to_non_nullable
as TeamRef,broadcast: null == broadcast ? _self.broadcast : broadcast // ignore: cast_nullable_to_non_nullable
as Broadcast,broadcasts: null == broadcasts ? _self.broadcasts : broadcasts // ignore: cast_nullable_to_non_nullable
as List<BroadcastEntry>,carriages: null == carriages ? _self.carriages : carriages // ignore: cast_nullable_to_non_nullable
as List<CarriageEntry>,commentator: freezed == commentator ? _self.commentator : commentator // ignore: cast_nullable_to_non_nullable
as CommentatorRef?,competition: null == competition ? _self.competition : competition // ignore: cast_nullable_to_non_nullable
as CompetitionRef,estimated: null == estimated ? _self.estimated : estimated // ignore: cast_nullable_to_non_nullable
as bool,events: null == events ? _self.events : events // ignore: cast_nullable_to_non_nullable
as List<dynamic>,feedId: freezed == feedId ? _self.feedId : feedId // ignore: cast_nullable_to_non_nullable
as int?,home: null == home ? _self.home : home // ignore: cast_nullable_to_non_nullable
as TeamRef,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,kickoffAt: freezed == kickoffAt ? _self.kickoffAt : kickoffAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lineups: freezed == lineups ? _self.lineups : lineups // ignore: cast_nullable_to_non_nullable
as dynamic,localBroadcasterEg: freezed == localBroadcasterEg ? _self.localBroadcasterEg : localBroadcasterEg // ignore: cast_nullable_to_non_nullable
as String?,matchDate: null == matchDate ? _self.matchDate : matchDate // ignore: cast_nullable_to_non_nullable
as DateTime,minute: freezed == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as String?,period: freezed == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as Period?,platforms: null == platforms ? _self.platforms : platforms // ignore: cast_nullable_to_non_nullable
as List<PlatformGroup>,score: freezed == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as Score?,sport: null == sport ? _self.sport : sport // ignore: cast_nullable_to_non_nullable
as Sport,stadium: freezed == stadium ? _self.stadium : stadium // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as Status,statusLabel: freezed == statusLabel ? _self.statusLabel : statusLabel // ignore: cast_nullable_to_non_nullable
as String?,timeTbd: null == timeTbd ? _self.timeTbd : timeTbd // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of MatchDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamRefCopyWith<$Res> get away {
  
  return $TeamRefCopyWith<$Res>(_self.away, (value) {
    return _then(_self.copyWith(away: value));
  });
}/// Create a copy of MatchDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BroadcastCopyWith<$Res> get broadcast {
  
  return $BroadcastCopyWith<$Res>(_self.broadcast, (value) {
    return _then(_self.copyWith(broadcast: value));
  });
}/// Create a copy of MatchDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CommentatorRefCopyWith<$Res>? get commentator {
    if (_self.commentator == null) {
    return null;
  }

  return $CommentatorRefCopyWith<$Res>(_self.commentator!, (value) {
    return _then(_self.copyWith(commentator: value));
  });
}/// Create a copy of MatchDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CompetitionRefCopyWith<$Res> get competition {
  
  return $CompetitionRefCopyWith<$Res>(_self.competition, (value) {
    return _then(_self.copyWith(competition: value));
  });
}/// Create a copy of MatchDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamRefCopyWith<$Res> get home {
  
  return $TeamRefCopyWith<$Res>(_self.home, (value) {
    return _then(_self.copyWith(home: value));
  });
}/// Create a copy of MatchDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScoreCopyWith<$Res>? get score {
    if (_self.score == null) {
    return null;
  }

  return $ScoreCopyWith<$Res>(_self.score!, (value) {
    return _then(_self.copyWith(score: value));
  });
}
}


/// Adds pattern-matching-related methods to [MatchDetail].
extension MatchDetailPatterns on MatchDetail {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MatchDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MatchDetail() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MatchDetail value)  $default,){
final _that = this;
switch (_that) {
case _MatchDetail():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MatchDetail value)?  $default,){
final _that = this;
switch (_that) {
case _MatchDetail() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TeamRef away,  Broadcast broadcast,  List<BroadcastEntry> broadcasts,  List<CarriageEntry> carriages,  CommentatorRef? commentator,  CompetitionRef competition,  bool estimated,  List<dynamic> events, @JsonKey(name: 'feed_id')  int? feedId,  TeamRef home,  int id, @JsonKey(name: 'kickoff_at')  DateTime? kickoffAt,  dynamic lineups, @JsonKey(name: 'local_broadcaster_eg')  String? localBroadcasterEg, @JsonKey(name: 'match_date')  DateTime matchDate,  String? minute,  Period? period,  List<PlatformGroup> platforms,  Score? score,  Sport sport,  String? stadium,  Status status, @JsonKey(name: 'status_label')  String? statusLabel, @JsonKey(name: 'time_tbd')  bool timeTbd, @JsonKey(name: 'updated_at')  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MatchDetail() when $default != null:
return $default(_that.away,_that.broadcast,_that.broadcasts,_that.carriages,_that.commentator,_that.competition,_that.estimated,_that.events,_that.feedId,_that.home,_that.id,_that.kickoffAt,_that.lineups,_that.localBroadcasterEg,_that.matchDate,_that.minute,_that.period,_that.platforms,_that.score,_that.sport,_that.stadium,_that.status,_that.statusLabel,_that.timeTbd,_that.updatedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TeamRef away,  Broadcast broadcast,  List<BroadcastEntry> broadcasts,  List<CarriageEntry> carriages,  CommentatorRef? commentator,  CompetitionRef competition,  bool estimated,  List<dynamic> events, @JsonKey(name: 'feed_id')  int? feedId,  TeamRef home,  int id, @JsonKey(name: 'kickoff_at')  DateTime? kickoffAt,  dynamic lineups, @JsonKey(name: 'local_broadcaster_eg')  String? localBroadcasterEg, @JsonKey(name: 'match_date')  DateTime matchDate,  String? minute,  Period? period,  List<PlatformGroup> platforms,  Score? score,  Sport sport,  String? stadium,  Status status, @JsonKey(name: 'status_label')  String? statusLabel, @JsonKey(name: 'time_tbd')  bool timeTbd, @JsonKey(name: 'updated_at')  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _MatchDetail():
return $default(_that.away,_that.broadcast,_that.broadcasts,_that.carriages,_that.commentator,_that.competition,_that.estimated,_that.events,_that.feedId,_that.home,_that.id,_that.kickoffAt,_that.lineups,_that.localBroadcasterEg,_that.matchDate,_that.minute,_that.period,_that.platforms,_that.score,_that.sport,_that.stadium,_that.status,_that.statusLabel,_that.timeTbd,_that.updatedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TeamRef away,  Broadcast broadcast,  List<BroadcastEntry> broadcasts,  List<CarriageEntry> carriages,  CommentatorRef? commentator,  CompetitionRef competition,  bool estimated,  List<dynamic> events, @JsonKey(name: 'feed_id')  int? feedId,  TeamRef home,  int id, @JsonKey(name: 'kickoff_at')  DateTime? kickoffAt,  dynamic lineups, @JsonKey(name: 'local_broadcaster_eg')  String? localBroadcasterEg, @JsonKey(name: 'match_date')  DateTime matchDate,  String? minute,  Period? period,  List<PlatformGroup> platforms,  Score? score,  Sport sport,  String? stadium,  Status status, @JsonKey(name: 'status_label')  String? statusLabel, @JsonKey(name: 'time_tbd')  bool timeTbd, @JsonKey(name: 'updated_at')  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _MatchDetail() when $default != null:
return $default(_that.away,_that.broadcast,_that.broadcasts,_that.carriages,_that.commentator,_that.competition,_that.estimated,_that.events,_that.feedId,_that.home,_that.id,_that.kickoffAt,_that.lineups,_that.localBroadcasterEg,_that.matchDate,_that.minute,_that.period,_that.platforms,_that.score,_that.sport,_that.stadium,_that.status,_that.statusLabel,_that.timeTbd,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MatchDetail implements MatchDetail {
  const _MatchDetail({required this.away, required this.broadcast, required  List<BroadcastEntry> broadcasts, required  List<CarriageEntry> carriages, required this.commentator, required this.competition, required this.estimated, required  List<dynamic> events, @JsonKey(name: 'feed_id') required this.feedId, required this.home, required this.id, @JsonKey(name: 'kickoff_at') required this.kickoffAt, required this.lineups, @JsonKey(name: 'local_broadcaster_eg') required this.localBroadcasterEg, @JsonKey(name: 'match_date') required this.matchDate, required this.minute, required this.period, required  List<PlatformGroup> platforms, required this.score, required this.sport, required this.stadium, required this.status, @JsonKey(name: 'status_label') required this.statusLabel, @JsonKey(name: 'time_tbd') required this.timeTbd, @JsonKey(name: 'updated_at') required this.updatedAt}): _broadcasts = broadcasts,_carriages = carriages,_events = events,_platforms = platforms;
  factory _MatchDetail.fromJson(Map<String, dynamic> json) => _$MatchDetailFromJson(json);

@override final  TeamRef away;
@override final  Broadcast broadcast;
 final  List<BroadcastEntry> _broadcasts;
@override List<BroadcastEntry> get broadcasts {
  if (_broadcasts is EqualUnmodifiableListView) return _broadcasts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_broadcasts);
}

 final  List<CarriageEntry> _carriages;
@override List<CarriageEntry> get carriages {
  if (_carriages is EqualUnmodifiableListView) return _carriages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_carriages);
}

@override final  CommentatorRef? commentator;
@override final  CompetitionRef competition;
@override final  bool estimated;
 final  List<dynamic> _events;
@override List<dynamic> get events {
  if (_events is EqualUnmodifiableListView) return _events;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_events);
}

@override@JsonKey(name: 'feed_id') final  int? feedId;
@override final  TeamRef home;
@override final  int id;
@override@JsonKey(name: 'kickoff_at') final  DateTime? kickoffAt;
@override final  dynamic lineups;
@override@JsonKey(name: 'local_broadcaster_eg') final  String? localBroadcasterEg;
@override@JsonKey(name: 'match_date') final  DateTime matchDate;
@override final  String? minute;
@override final  Period? period;
 final  List<PlatformGroup> _platforms;
@override List<PlatformGroup> get platforms {
  if (_platforms is EqualUnmodifiableListView) return _platforms;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_platforms);
}

@override final  Score? score;
@override final  Sport sport;
@override final  String? stadium;
@override final  Status status;
@override@JsonKey(name: 'status_label') final  String? statusLabel;
@override@JsonKey(name: 'time_tbd') final  bool timeTbd;
@override@JsonKey(name: 'updated_at') final  DateTime updatedAt;

/// Create a copy of MatchDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MatchDetailCopyWith<_MatchDetail> get copyWith => __$MatchDetailCopyWithImpl<_MatchDetail>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MatchDetailToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MatchDetail&&(identical(other.away, away) || other.away == away)&&(identical(other.broadcast, broadcast) || other.broadcast == broadcast)&&const DeepCollectionEquality().equals(other.broadcasts, _broadcasts)&&const DeepCollectionEquality().equals(other.carriages, _carriages)&&(identical(other.commentator, commentator) || other.commentator == commentator)&&(identical(other.competition, competition) || other.competition == competition)&&(identical(other.estimated, estimated) || other.estimated == estimated)&&const DeepCollectionEquality().equals(other.events, _events)&&(identical(other.feedId, feedId) || other.feedId == feedId)&&(identical(other.home, home) || other.home == home)&&(identical(other.id, id) || other.id == id)&&(identical(other.kickoffAt, kickoffAt) || other.kickoffAt == kickoffAt)&&const DeepCollectionEquality().equals(other.lineups, lineups)&&(identical(other.localBroadcasterEg, localBroadcasterEg) || other.localBroadcasterEg == localBroadcasterEg)&&(identical(other.matchDate, matchDate) || other.matchDate == matchDate)&&(identical(other.minute, minute) || other.minute == minute)&&(identical(other.period, period) || other.period == period)&&const DeepCollectionEquality().equals(other.platforms, _platforms)&&(identical(other.score, score) || other.score == score)&&(identical(other.sport, sport) || other.sport == sport)&&(identical(other.stadium, stadium) || other.stadium == stadium)&&(identical(other.status, status) || other.status == status)&&(identical(other.statusLabel, statusLabel) || other.statusLabel == statusLabel)&&(identical(other.timeTbd, timeTbd) || other.timeTbd == timeTbd)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,away,broadcast,const DeepCollectionEquality().hash(_broadcasts),const DeepCollectionEquality().hash(_carriages),commentator,competition,estimated,const DeepCollectionEquality().hash(_events),feedId,home,id,kickoffAt,const DeepCollectionEquality().hash(lineups),localBroadcasterEg,matchDate,minute,period,const DeepCollectionEquality().hash(_platforms),score,sport,stadium,status,statusLabel,timeTbd,updatedAt]);
}

@override
String toString() {
    return 'MatchDetail(away: $away, broadcast: $broadcast, broadcasts: $broadcasts, carriages: $carriages, commentator: $commentator, competition: $competition, estimated: $estimated, events: $events, feedId: $feedId, home: $home, id: $id, kickoffAt: $kickoffAt, lineups: $lineups, localBroadcasterEg: $localBroadcasterEg, matchDate: $matchDate, minute: $minute, period: $period, platforms: $platforms, score: $score, sport: $sport, stadium: $stadium, status: $status, statusLabel: $statusLabel, timeTbd: $timeTbd, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$MatchDetailCopyWith<$Res> implements $MatchDetailCopyWith<$Res> {
  factory _$MatchDetailCopyWith(_MatchDetail value, $Res Function(_MatchDetail) _then) = __$MatchDetailCopyWithImpl;
@override @useResult
$Res call({
 TeamRef away, Broadcast broadcast, List<BroadcastEntry> broadcasts, List<CarriageEntry> carriages, CommentatorRef? commentator, CompetitionRef competition, bool estimated, List<dynamic> events,@JsonKey(name: 'feed_id') int? feedId, TeamRef home, int id,@JsonKey(name: 'kickoff_at') DateTime? kickoffAt, dynamic lineups,@JsonKey(name: 'local_broadcaster_eg') String? localBroadcasterEg,@JsonKey(name: 'match_date') DateTime matchDate, String? minute, Period? period, List<PlatformGroup> platforms, Score? score, Sport sport, String? stadium, Status status,@JsonKey(name: 'status_label') String? statusLabel,@JsonKey(name: 'time_tbd') bool timeTbd,@JsonKey(name: 'updated_at') DateTime updatedAt
});


@override $TeamRefCopyWith<$Res> get away;@override $BroadcastCopyWith<$Res> get broadcast;@override $CommentatorRefCopyWith<$Res>? get commentator;@override $CompetitionRefCopyWith<$Res> get competition;@override $TeamRefCopyWith<$Res> get home;@override $ScoreCopyWith<$Res>? get score;

}
/// @nodoc
class __$MatchDetailCopyWithImpl<$Res>
    implements _$MatchDetailCopyWith<$Res> {
  __$MatchDetailCopyWithImpl(this._self, this._then);

  final _MatchDetail _self;
  final $Res Function(_MatchDetail) _then;

/// Create a copy of MatchDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? away = null,Object? broadcast = null,Object? broadcasts = null,Object? carriages = null,Object? commentator = freezed,Object? competition = null,Object? estimated = null,Object? events = null,Object? feedId = freezed,Object? home = null,Object? id = null,Object? kickoffAt = freezed,Object? lineups = freezed,Object? localBroadcasterEg = freezed,Object? matchDate = null,Object? minute = freezed,Object? period = freezed,Object? platforms = null,Object? score = freezed,Object? sport = null,Object? stadium = freezed,Object? status = null,Object? statusLabel = freezed,Object? timeTbd = null,Object? updatedAt = null,}) {
  return _then(_MatchDetail(
away: null == away ? _self.away : away // ignore: cast_nullable_to_non_nullable
as TeamRef,broadcast: null == broadcast ? _self.broadcast : broadcast // ignore: cast_nullable_to_non_nullable
as Broadcast,broadcasts: null == broadcasts ? _self._broadcasts : broadcasts // ignore: cast_nullable_to_non_nullable
as List<BroadcastEntry>,carriages: null == carriages ? _self._carriages : carriages // ignore: cast_nullable_to_non_nullable
as List<CarriageEntry>,commentator: freezed == commentator ? _self.commentator : commentator // ignore: cast_nullable_to_non_nullable
as CommentatorRef?,competition: null == competition ? _self.competition : competition // ignore: cast_nullable_to_non_nullable
as CompetitionRef,estimated: null == estimated ? _self.estimated : estimated // ignore: cast_nullable_to_non_nullable
as bool,events: null == events ? _self._events : events // ignore: cast_nullable_to_non_nullable
as List<dynamic>,feedId: freezed == feedId ? _self.feedId : feedId // ignore: cast_nullable_to_non_nullable
as int?,home: null == home ? _self.home : home // ignore: cast_nullable_to_non_nullable
as TeamRef,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,kickoffAt: freezed == kickoffAt ? _self.kickoffAt : kickoffAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lineups: freezed == lineups ? _self.lineups : lineups // ignore: cast_nullable_to_non_nullable
as dynamic,localBroadcasterEg: freezed == localBroadcasterEg ? _self.localBroadcasterEg : localBroadcasterEg // ignore: cast_nullable_to_non_nullable
as String?,matchDate: null == matchDate ? _self.matchDate : matchDate // ignore: cast_nullable_to_non_nullable
as DateTime,minute: freezed == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as String?,period: freezed == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as Period?,platforms: null == platforms ? _self._platforms : platforms // ignore: cast_nullable_to_non_nullable
as List<PlatformGroup>,score: freezed == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as Score?,sport: null == sport ? _self.sport : sport // ignore: cast_nullable_to_non_nullable
as Sport,stadium: freezed == stadium ? _self.stadium : stadium // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as Status,statusLabel: freezed == statusLabel ? _self.statusLabel : statusLabel // ignore: cast_nullable_to_non_nullable
as String?,timeTbd: null == timeTbd ? _self.timeTbd : timeTbd // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of MatchDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamRefCopyWith<$Res> get away {
  
  return $TeamRefCopyWith<$Res>(_self.away, (value) {
    return _then(_self.copyWith(away: value));
  });
}/// Create a copy of MatchDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BroadcastCopyWith<$Res> get broadcast {
  
  return $BroadcastCopyWith<$Res>(_self.broadcast, (value) {
    return _then(_self.copyWith(broadcast: value));
  });
}/// Create a copy of MatchDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CommentatorRefCopyWith<$Res>? get commentator {
    if (_self.commentator == null) {
    return null;
  }

  return $CommentatorRefCopyWith<$Res>(_self.commentator!, (value) {
    return _then(_self.copyWith(commentator: value));
  });
}/// Create a copy of MatchDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CompetitionRefCopyWith<$Res> get competition {
  
  return $CompetitionRefCopyWith<$Res>(_self.competition, (value) {
    return _then(_self.copyWith(competition: value));
  });
}/// Create a copy of MatchDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamRefCopyWith<$Res> get home {
  
  return $TeamRefCopyWith<$Res>(_self.home, (value) {
    return _then(_self.copyWith(home: value));
  });
}/// Create a copy of MatchDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScoreCopyWith<$Res>? get score {
    if (_self.score == null) {
    return null;
  }

  return $ScoreCopyWith<$Res>(_self.score!, (value) {
    return _then(_self.copyWith(score: value));
  });
}
}

// dart format on
