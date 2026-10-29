// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'competition_ref.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CompetitionRef {

 int? get id; String? get logo; String get name; int? get priority; String? get stage;
/// Create a copy of CompetitionRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompetitionRefCopyWith<CompetitionRef> get copyWith => _$CompetitionRefCopyWithImpl<CompetitionRef>(this as CompetitionRef, _$identity);

  /// Serializes this CompetitionRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CompetitionRef;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CompetitionRef&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.logo, _this.logo) || other.logo == _this.logo)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.priority, _this.priority) || other.priority == _this.priority)&&(identical(other.stage, _this.stage) || other.stage == _this.stage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CompetitionRef;
  return Object.hash(runtimeType,_this.id,_this.logo,_this.name,_this.priority,_this.stage);
}

@override
String toString() {
  final _this = this as CompetitionRef;
  return 'CompetitionRef(id: ${_this.id}, logo: ${_this.logo}, name: ${_this.name}, priority: ${_this.priority}, stage: ${_this.stage})';
}


}

/// @nodoc
abstract mixin class $CompetitionRefCopyWith<$Res>  {
  factory $CompetitionRefCopyWith(CompetitionRef value, $Res Function(CompetitionRef) _then) = _$CompetitionRefCopyWithImpl;
@useResult
$Res call({
 int? id, String? logo, String name, int? priority, String? stage
});




}
/// @nodoc
class _$CompetitionRefCopyWithImpl<$Res>
    implements $CompetitionRefCopyWith<$Res> {
  _$CompetitionRefCopyWithImpl(this._self, this._then);

  final CompetitionRef _self;
  final $Res Function(CompetitionRef) _then;

/// Create a copy of CompetitionRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? logo = freezed,Object? name = null,Object? priority = freezed,Object? stage = freezed,}) {
  return _then(CompetitionRef(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,priority: freezed == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int?,stage: freezed == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CompetitionRef].
extension CompetitionRefPatterns on CompetitionRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CompetitionRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CompetitionRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CompetitionRef value)  $default,){
final _that = this;
switch (_that) {
case _CompetitionRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CompetitionRef value)?  $default,){
final _that = this;
switch (_that) {
case _CompetitionRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id,  String? logo,  String name,  int? priority,  String? stage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CompetitionRef() when $default != null:
return $default(_that.id,_that.logo,_that.name,_that.priority,_that.stage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id,  String? logo,  String name,  int? priority,  String? stage)  $default,) {final _that = this;
switch (_that) {
case _CompetitionRef():
return $default(_that.id,_that.logo,_that.name,_that.priority,_that.stage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id,  String? logo,  String name,  int? priority,  String? stage)?  $default,) {final _that = this;
switch (_that) {
case _CompetitionRef() when $default != null:
return $default(_that.id,_that.logo,_that.name,_that.priority,_that.stage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CompetitionRef implements CompetitionRef {
  const _CompetitionRef({required this.id, required this.logo, required this.name, required this.priority, required this.stage});
  factory _CompetitionRef.fromJson(Map<String, dynamic> json) => _$CompetitionRefFromJson(json);

@override final  int? id;
@override final  String? logo;
@override final  String name;
@override final  int? priority;
@override final  String? stage;

/// Create a copy of CompetitionRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompetitionRefCopyWith<_CompetitionRef> get copyWith => __$CompetitionRefCopyWithImpl<_CompetitionRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CompetitionRefToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CompetitionRef&&(identical(other.id, id) || other.id == id)&&(identical(other.logo, logo) || other.logo == logo)&&(identical(other.name, name) || other.name == name)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.stage, stage) || other.stage == stage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,logo,name,priority,stage);
}

@override
String toString() {
    return 'CompetitionRef(id: $id, logo: $logo, name: $name, priority: $priority, stage: $stage)';
}


}

/// @nodoc
abstract mixin class _$CompetitionRefCopyWith<$Res> implements $CompetitionRefCopyWith<$Res> {
  factory _$CompetitionRefCopyWith(_CompetitionRef value, $Res Function(_CompetitionRef) _then) = __$CompetitionRefCopyWithImpl;
@override @useResult
$Res call({
 int? id, String? logo, String name, int? priority, String? stage
});




}
/// @nodoc
class __$CompetitionRefCopyWithImpl<$Res>
    implements _$CompetitionRefCopyWith<$Res> {
  __$CompetitionRefCopyWithImpl(this._self, this._then);

  final _CompetitionRef _self;
  final $Res Function(_CompetitionRef) _then;

/// Create a copy of CompetitionRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? logo = freezed,Object? name = null,Object? priority = freezed,Object? stage = freezed,}) {
  return _then(_CompetitionRef(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,priority: freezed == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int?,stage: freezed == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
