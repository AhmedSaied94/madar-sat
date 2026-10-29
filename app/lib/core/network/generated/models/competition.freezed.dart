// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'competition.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Competition {

 int get id; String? get logo; String get name; int? get priority; Sport get sport;
/// Create a copy of Competition
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompetitionCopyWith<Competition> get copyWith => _$CompetitionCopyWithImpl<Competition>(this as Competition, _$identity);

  /// Serializes this Competition to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Competition;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Competition&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.logo, _this.logo) || other.logo == _this.logo)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.priority, _this.priority) || other.priority == _this.priority)&&(identical(other.sport, _this.sport) || other.sport == _this.sport));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Competition;
  return Object.hash(runtimeType,_this.id,_this.logo,_this.name,_this.priority,_this.sport);
}

@override
String toString() {
  final _this = this as Competition;
  return 'Competition(id: ${_this.id}, logo: ${_this.logo}, name: ${_this.name}, priority: ${_this.priority}, sport: ${_this.sport})';
}


}

/// @nodoc
abstract mixin class $CompetitionCopyWith<$Res>  {
  factory $CompetitionCopyWith(Competition value, $Res Function(Competition) _then) = _$CompetitionCopyWithImpl;
@useResult
$Res call({
 int id, String? logo, String name, int? priority, Sport sport
});




}
/// @nodoc
class _$CompetitionCopyWithImpl<$Res>
    implements $CompetitionCopyWith<$Res> {
  _$CompetitionCopyWithImpl(this._self, this._then);

  final Competition _self;
  final $Res Function(Competition) _then;

/// Create a copy of Competition
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? logo = freezed,Object? name = null,Object? priority = freezed,Object? sport = null,}) {
  return _then(Competition(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,priority: freezed == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int?,sport: null == sport ? _self.sport : sport // ignore: cast_nullable_to_non_nullable
as Sport,
  ));
}

}


/// Adds pattern-matching-related methods to [Competition].
extension CompetitionPatterns on Competition {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Competition value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Competition() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Competition value)  $default,){
final _that = this;
switch (_that) {
case _Competition():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Competition value)?  $default,){
final _that = this;
switch (_that) {
case _Competition() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String? logo,  String name,  int? priority,  Sport sport)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Competition() when $default != null:
return $default(_that.id,_that.logo,_that.name,_that.priority,_that.sport);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String? logo,  String name,  int? priority,  Sport sport)  $default,) {final _that = this;
switch (_that) {
case _Competition():
return $default(_that.id,_that.logo,_that.name,_that.priority,_that.sport);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String? logo,  String name,  int? priority,  Sport sport)?  $default,) {final _that = this;
switch (_that) {
case _Competition() when $default != null:
return $default(_that.id,_that.logo,_that.name,_that.priority,_that.sport);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Competition implements Competition {
  const _Competition({required this.id, required this.logo, required this.name, required this.priority, required this.sport});
  factory _Competition.fromJson(Map<String, dynamic> json) => _$CompetitionFromJson(json);

@override final  int id;
@override final  String? logo;
@override final  String name;
@override final  int? priority;
@override final  Sport sport;

/// Create a copy of Competition
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompetitionCopyWith<_Competition> get copyWith => __$CompetitionCopyWithImpl<_Competition>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CompetitionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Competition&&(identical(other.id, id) || other.id == id)&&(identical(other.logo, logo) || other.logo == logo)&&(identical(other.name, name) || other.name == name)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.sport, sport) || other.sport == sport));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,logo,name,priority,sport);
}

@override
String toString() {
    return 'Competition(id: $id, logo: $logo, name: $name, priority: $priority, sport: $sport)';
}


}

/// @nodoc
abstract mixin class _$CompetitionCopyWith<$Res> implements $CompetitionCopyWith<$Res> {
  factory _$CompetitionCopyWith(_Competition value, $Res Function(_Competition) _then) = __$CompetitionCopyWithImpl;
@override @useResult
$Res call({
 int id, String? logo, String name, int? priority, Sport sport
});




}
/// @nodoc
class __$CompetitionCopyWithImpl<$Res>
    implements _$CompetitionCopyWith<$Res> {
  __$CompetitionCopyWithImpl(this._self, this._then);

  final _Competition _self;
  final $Res Function(_Competition) _then;

/// Create a copy of Competition
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? logo = freezed,Object? name = null,Object? priority = freezed,Object? sport = null,}) {
  return _then(_Competition(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,priority: freezed == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int?,sport: null == sport ? _self.sport : sport // ignore: cast_nullable_to_non_nullable
as Sport,
  ));
}


}

// dart format on
