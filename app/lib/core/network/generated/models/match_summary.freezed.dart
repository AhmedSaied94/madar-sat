// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'match_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MatchSummary {

 TeamRef get away; Broadcast get broadcast; CommentatorRef? get commentator; CompetitionRef get competition; bool get estimated; TeamRef get home; int get id;@JsonKey(name: 'kickoff_at') DateTime? get kickoffAt;@JsonKey(name: 'match_date') DateTime get matchDate; String? get minute; Period? get period; Score? get score; Sport get sport; Status get status;@JsonKey(name: 'status_label') String? get statusLabel;@JsonKey(name: 'time_tbd') bool get timeTbd;@JsonKey(name: 'updated_at') DateTime get updatedAt;
/// Create a copy of MatchSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MatchSummaryCopyWith<MatchSummary> get copyWith => _$MatchSummaryCopyWithImpl<MatchSummary>(this as MatchSummary, _$identity);

  /// Serializes this MatchSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MatchSummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MatchSummary&&(identical(other.away, _this.away) || other.away == _this.away)&&(identical(other.broadcast, _this.broadcast) || other.broadcast == _this.broadcast)&&(identical(other.commentator, _this.commentator) || other.commentator == _this.commentator)&&(identical(other.competition, _this.competition) || other.competition == _this.competition)&&(identical(other.estimated, _this.estimated) || other.estimated == _this.estimated)&&(identical(other.home, _this.home) || other.home == _this.home)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.kickoffAt, _this.kickoffAt) || other.kickoffAt == _this.kickoffAt)&&(identical(other.matchDate, _this.matchDate) || other.matchDate == _this.matchDate)&&(identical(other.minute, _this.minute) || other.minute == _this.minute)&&(identical(other.period, _this.period) || other.period == _this.period)&&(identical(other.score, _this.score) || other.score == _this.score)&&(identical(other.sport, _this.sport) || other.sport == _this.sport)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.statusLabel, _this.statusLabel) || other.statusLabel == _this.statusLabel)&&(identical(other.timeTbd, _this.timeTbd) || other.timeTbd == _this.timeTbd)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MatchSummary;
  return Object.hash(runtimeType,_this.away,_this.broadcast,_this.commentator,_this.competition,_this.estimated,_this.home,_this.id,_this.kickoffAt,_this.matchDate,_this.minute,_this.period,_this.score,_this.sport,_this.status,_this.statusLabel,_this.timeTbd,_this.updatedAt);
}

@override
String toString() {
  final _this = this as MatchSummary;
  return 'MatchSummary(away: ${_this.away}, broadcast: ${_this.broadcast}, commentator: ${_this.commentator}, competition: ${_this.competition}, estimated: ${_this.estimated}, home: ${_this.home}, id: ${_this.id}, kickoffAt: ${_this.kickoffAt}, matchDate: ${_this.matchDate}, minute: ${_this.minute}, period: ${_this.period}, score: ${_this.score}, sport: ${_this.sport}, status: ${_this.status}, statusLabel: ${_this.statusLabel}, timeTbd: ${_this.timeTbd}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $MatchSummaryCopyWith<$Res>  {
  factory $MatchSummaryCopyWith(MatchSummary value, $Res Function(MatchSummary) _then) = _$MatchSummaryCopyWithImpl;
@useResult
$Res call({
 TeamRef away, Broadcast broadcast, CommentatorRef? commentator, CompetitionRef competition, bool estimated, TeamRef home, int id,@JsonKey(name: 'kickoff_at') DateTime? kickoffAt,@JsonKey(name: 'match_date') DateTime matchDate, String? minute, Period? period, Score? score, Sport sport, Status status,@JsonKey(name: 'status_label') String? statusLabel,@JsonKey(name: 'time_tbd') bool timeTbd,@JsonKey(name: 'updated_at') DateTime updatedAt
});


$TeamRefCopyWith<$Res> get away;$BroadcastCopyWith<$Res> get broadcast;$CommentatorRefCopyWith<$Res>? get commentator;$CompetitionRefCopyWith<$Res> get competition;$TeamRefCopyWith<$Res> get home;$ScoreCopyWith<$Res>? get score;

}
/// @nodoc
class _$MatchSummaryCopyWithImpl<$Res>
    implements $MatchSummaryCopyWith<$Res> {
  _$MatchSummaryCopyWithImpl(this._self, this._then);

  final MatchSummary _self;
  final $Res Function(MatchSummary) _then;

/// Create a copy of MatchSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? away = null,Object? broadcast = null,Object? commentator = freezed,Object? competition = null,Object? estimated = null,Object? home = null,Object? id = null,Object? kickoffAt = freezed,Object? matchDate = null,Object? minute = freezed,Object? period = freezed,Object? score = freezed,Object? sport = null,Object? status = null,Object? statusLabel = freezed,Object? timeTbd = null,Object? updatedAt = null,}) {
  return _then(MatchSummary(
away: null == away ? _self.away : away // ignore: cast_nullable_to_non_nullable
as TeamRef,broadcast: null == broadcast ? _self.broadcast : broadcast // ignore: cast_nullable_to_non_nullable
as Broadcast,commentator: freezed == commentator ? _self.commentator : commentator // ignore: cast_nullable_to_non_nullable
as CommentatorRef?,competition: null == competition ? _self.competition : competition // ignore: cast_nullable_to_non_nullable
as CompetitionRef,estimated: null == estimated ? _self.estimated : estimated // ignore: cast_nullable_to_non_nullable
as bool,home: null == home ? _self.home : home // ignore: cast_nullable_to_non_nullable
as TeamRef,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,kickoffAt: freezed == kickoffAt ? _self.kickoffAt : kickoffAt // ignore: cast_nullable_to_non_nullable
as DateTime?,matchDate: null == matchDate ? _self.matchDate : matchDate // ignore: cast_nullable_to_non_nullable
as DateTime,minute: freezed == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as String?,period: freezed == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as Period?,score: freezed == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as Score?,sport: null == sport ? _self.sport : sport // ignore: cast_nullable_to_non_nullable
as Sport,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as Status,statusLabel: freezed == statusLabel ? _self.statusLabel : statusLabel // ignore: cast_nullable_to_non_nullable
as String?,timeTbd: null == timeTbd ? _self.timeTbd : timeTbd // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of MatchSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamRefCopyWith<$Res> get away {
  
  return $TeamRefCopyWith<$Res>(_self.away, (value) {
    return _then(_self.copyWith(away: value));
  });
}/// Create a copy of MatchSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BroadcastCopyWith<$Res> get broadcast {
  
  return $BroadcastCopyWith<$Res>(_self.broadcast, (value) {
    return _then(_self.copyWith(broadcast: value));
  });
}/// Create a copy of MatchSummary
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
}/// Create a copy of MatchSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CompetitionRefCopyWith<$Res> get competition {
  
  return $CompetitionRefCopyWith<$Res>(_self.competition, (value) {
    return _then(_self.copyWith(competition: value));
  });
}/// Create a copy of MatchSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamRefCopyWith<$Res> get home {
  
  return $TeamRefCopyWith<$Res>(_self.home, (value) {
    return _then(_self.copyWith(home: value));
  });
}/// Create a copy of MatchSummary
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


/// Adds pattern-matching-related methods to [MatchSummary].
extension MatchSummaryPatterns on MatchSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MatchSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MatchSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MatchSummary value)  $default,){
final _that = this;
switch (_that) {
case _MatchSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MatchSummary value)?  $default,){
final _that = this;
switch (_that) {
case _MatchSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TeamRef away,  Broadcast broadcast,  CommentatorRef? commentator,  CompetitionRef competition,  bool estimated,  TeamRef home,  int id, @JsonKey(name: 'kickoff_at')  DateTime? kickoffAt, @JsonKey(name: 'match_date')  DateTime matchDate,  String? minute,  Period? period,  Score? score,  Sport sport,  Status status, @JsonKey(name: 'status_label')  String? statusLabel, @JsonKey(name: 'time_tbd')  bool timeTbd, @JsonKey(name: 'updated_at')  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MatchSummary() when $default != null:
return $default(_that.away,_that.broadcast,_that.commentator,_that.competition,_that.estimated,_that.home,_that.id,_that.kickoffAt,_that.matchDate,_that.minute,_that.period,_that.score,_that.sport,_that.status,_that.statusLabel,_that.timeTbd,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TeamRef away,  Broadcast broadcast,  CommentatorRef? commentator,  CompetitionRef competition,  bool estimated,  TeamRef home,  int id, @JsonKey(name: 'kickoff_at')  DateTime? kickoffAt, @JsonKey(name: 'match_date')  DateTime matchDate,  String? minute,  Period? period,  Score? score,  Sport sport,  Status status, @JsonKey(name: 'status_label')  String? statusLabel, @JsonKey(name: 'time_tbd')  bool timeTbd, @JsonKey(name: 'updated_at')  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _MatchSummary():
return $default(_that.away,_that.broadcast,_that.commentator,_that.competition,_that.estimated,_that.home,_that.id,_that.kickoffAt,_that.matchDate,_that.minute,_that.period,_that.score,_that.sport,_that.status,_that.statusLabel,_that.timeTbd,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TeamRef away,  Broadcast broadcast,  CommentatorRef? commentator,  CompetitionRef competition,  bool estimated,  TeamRef home,  int id, @JsonKey(name: 'kickoff_at')  DateTime? kickoffAt, @JsonKey(name: 'match_date')  DateTime matchDate,  String? minute,  Period? period,  Score? score,  Sport sport,  Status status, @JsonKey(name: 'status_label')  String? statusLabel, @JsonKey(name: 'time_tbd')  bool timeTbd, @JsonKey(name: 'updated_at')  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _MatchSummary() when $default != null:
return $default(_that.away,_that.broadcast,_that.commentator,_that.competition,_that.estimated,_that.home,_that.id,_that.kickoffAt,_that.matchDate,_that.minute,_that.period,_that.score,_that.sport,_that.status,_that.statusLabel,_that.timeTbd,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MatchSummary implements MatchSummary {
  const _MatchSummary({required this.away, required this.broadcast, required this.commentator, required this.competition, required this.estimated, required this.home, required this.id, @JsonKey(name: 'kickoff_at') required this.kickoffAt, @JsonKey(name: 'match_date') required this.matchDate, required this.minute, required this.period, required this.score, required this.sport, required this.status, @JsonKey(name: 'status_label') required this.statusLabel, @JsonKey(name: 'time_tbd') required this.timeTbd, @JsonKey(name: 'updated_at') required this.updatedAt});
  factory _MatchSummary.fromJson(Map<String, dynamic> json) => _$MatchSummaryFromJson(json);

@override final  TeamRef away;
@override final  Broadcast broadcast;
@override final  CommentatorRef? commentator;
@override final  CompetitionRef competition;
@override final  bool estimated;
@override final  TeamRef home;
@override final  int id;
@override@JsonKey(name: 'kickoff_at') final  DateTime? kickoffAt;
@override@JsonKey(name: 'match_date') final  DateTime matchDate;
@override final  String? minute;
@override final  Period? period;
@override final  Score? score;
@override final  Sport sport;
@override final  Status status;
@override@JsonKey(name: 'status_label') final  String? statusLabel;
@override@JsonKey(name: 'time_tbd') final  bool timeTbd;
@override@JsonKey(name: 'updated_at') final  DateTime updatedAt;

/// Create a copy of MatchSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MatchSummaryCopyWith<_MatchSummary> get copyWith => __$MatchSummaryCopyWithImpl<_MatchSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MatchSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MatchSummary&&(identical(other.away, away) || other.away == away)&&(identical(other.broadcast, broadcast) || other.broadcast == broadcast)&&(identical(other.commentator, commentator) || other.commentator == commentator)&&(identical(other.competition, competition) || other.competition == competition)&&(identical(other.estimated, estimated) || other.estimated == estimated)&&(identical(other.home, home) || other.home == home)&&(identical(other.id, id) || other.id == id)&&(identical(other.kickoffAt, kickoffAt) || other.kickoffAt == kickoffAt)&&(identical(other.matchDate, matchDate) || other.matchDate == matchDate)&&(identical(other.minute, minute) || other.minute == minute)&&(identical(other.period, period) || other.period == period)&&(identical(other.score, score) || other.score == score)&&(identical(other.sport, sport) || other.sport == sport)&&(identical(other.status, status) || other.status == status)&&(identical(other.statusLabel, statusLabel) || other.statusLabel == statusLabel)&&(identical(other.timeTbd, timeTbd) || other.timeTbd == timeTbd)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,away,broadcast,commentator,competition,estimated,home,id,kickoffAt,matchDate,minute,period,score,sport,status,statusLabel,timeTbd,updatedAt);
}

@override
String toString() {
    return 'MatchSummary(away: $away, broadcast: $broadcast, commentator: $commentator, competition: $competition, estimated: $estimated, home: $home, id: $id, kickoffAt: $kickoffAt, matchDate: $matchDate, minute: $minute, period: $period, score: $score, sport: $sport, status: $status, statusLabel: $statusLabel, timeTbd: $timeTbd, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$MatchSummaryCopyWith<$Res> implements $MatchSummaryCopyWith<$Res> {
  factory _$MatchSummaryCopyWith(_MatchSummary value, $Res Function(_MatchSummary) _then) = __$MatchSummaryCopyWithImpl;
@override @useResult
$Res call({
 TeamRef away, Broadcast broadcast, CommentatorRef? commentator, CompetitionRef competition, bool estimated, TeamRef home, int id,@JsonKey(name: 'kickoff_at') DateTime? kickoffAt,@JsonKey(name: 'match_date') DateTime matchDate, String? minute, Period? period, Score? score, Sport sport, Status status,@JsonKey(name: 'status_label') String? statusLabel,@JsonKey(name: 'time_tbd') bool timeTbd,@JsonKey(name: 'updated_at') DateTime updatedAt
});


@override $TeamRefCopyWith<$Res> get away;@override $BroadcastCopyWith<$Res> get broadcast;@override $CommentatorRefCopyWith<$Res>? get commentator;@override $CompetitionRefCopyWith<$Res> get competition;@override $TeamRefCopyWith<$Res> get home;@override $ScoreCopyWith<$Res>? get score;

}
/// @nodoc
class __$MatchSummaryCopyWithImpl<$Res>
    implements _$MatchSummaryCopyWith<$Res> {
  __$MatchSummaryCopyWithImpl(this._self, this._then);

  final _MatchSummary _self;
  final $Res Function(_MatchSummary) _then;

/// Create a copy of MatchSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? away = null,Object? broadcast = null,Object? commentator = freezed,Object? competition = null,Object? estimated = null,Object? home = null,Object? id = null,Object? kickoffAt = freezed,Object? matchDate = null,Object? minute = freezed,Object? period = freezed,Object? score = freezed,Object? sport = null,Object? status = null,Object? statusLabel = freezed,Object? timeTbd = null,Object? updatedAt = null,}) {
  return _then(_MatchSummary(
away: null == away ? _self.away : away // ignore: cast_nullable_to_non_nullable
as TeamRef,broadcast: null == broadcast ? _self.broadcast : broadcast // ignore: cast_nullable_to_non_nullable
as Broadcast,commentator: freezed == commentator ? _self.commentator : commentator // ignore: cast_nullable_to_non_nullable
as CommentatorRef?,competition: null == competition ? _self.competition : competition // ignore: cast_nullable_to_non_nullable
as CompetitionRef,estimated: null == estimated ? _self.estimated : estimated // ignore: cast_nullable_to_non_nullable
as bool,home: null == home ? _self.home : home // ignore: cast_nullable_to_non_nullable
as TeamRef,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,kickoffAt: freezed == kickoffAt ? _self.kickoffAt : kickoffAt // ignore: cast_nullable_to_non_nullable
as DateTime?,matchDate: null == matchDate ? _self.matchDate : matchDate // ignore: cast_nullable_to_non_nullable
as DateTime,minute: freezed == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as String?,period: freezed == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as Period?,score: freezed == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as Score?,sport: null == sport ? _self.sport : sport // ignore: cast_nullable_to_non_nullable
as Sport,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as Status,statusLabel: freezed == statusLabel ? _self.statusLabel : statusLabel // ignore: cast_nullable_to_non_nullable
as String?,timeTbd: null == timeTbd ? _self.timeTbd : timeTbd // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of MatchSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamRefCopyWith<$Res> get away {
  
  return $TeamRefCopyWith<$Res>(_self.away, (value) {
    return _then(_self.copyWith(away: value));
  });
}/// Create a copy of MatchSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BroadcastCopyWith<$Res> get broadcast {
  
  return $BroadcastCopyWith<$Res>(_self.broadcast, (value) {
    return _then(_self.copyWith(broadcast: value));
  });
}/// Create a copy of MatchSummary
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
}/// Create a copy of MatchSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CompetitionRefCopyWith<$Res> get competition {
  
  return $CompetitionRefCopyWith<$Res>(_self.competition, (value) {
    return _then(_self.copyWith(competition: value));
  });
}/// Create a copy of MatchSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamRefCopyWith<$Res> get home {
  
  return $TeamRefCopyWith<$Res>(_self.home, (value) {
    return _then(_self.copyWith(home: value));
  });
}/// Create a copy of MatchSummary
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
