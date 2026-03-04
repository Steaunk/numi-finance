// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'account.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Account _$AccountFromJson(Map<String, dynamic> json) {
  return _Account.fromJson(json);
}

/// @nodoc
mixin _$Account {
  int get id => throw _privateConstructorUsedError;
  int? get remoteId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get currency => throw _privateConstructorUsedError;
  double get balance => throw _privateConstructorUsedError;
  bool get includeInTotal => throw _privateConstructorUsedError;
  String get notes => throw _privateConstructorUsedError;
  String? get apiUrl => throw _privateConstructorUsedError;
  String? get apiValuePath => throw _privateConstructorUsedError;
  String? get apiAuth => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;
  bool get synced =>
      throw _privateConstructorUsedError; // Display fields (not stored)
  double get convertedBalance => throw _privateConstructorUsedError;

  /// Serializes this Account to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AccountCopyWith<Account> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AccountCopyWith<$Res> {
  factory $AccountCopyWith(Account value, $Res Function(Account) then) =
      _$AccountCopyWithImpl<$Res, Account>;
  @useResult
  $Res call(
      {int id,
      int? remoteId,
      String name,
      String currency,
      double balance,
      bool includeInTotal,
      String notes,
      String? apiUrl,
      String? apiValuePath,
      String? apiAuth,
      DateTime? createdAt,
      DateTime? updatedAt,
      bool synced,
      double convertedBalance});
}

/// @nodoc
class _$AccountCopyWithImpl<$Res, $Val extends Account>
    implements $AccountCopyWith<$Res> {
  _$AccountCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? remoteId = freezed,
    Object? name = null,
    Object? currency = null,
    Object? balance = null,
    Object? includeInTotal = null,
    Object? notes = null,
    Object? apiUrl = freezed,
    Object? apiValuePath = freezed,
    Object? apiAuth = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? synced = null,
    Object? convertedBalance = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      remoteId: freezed == remoteId
          ? _value.remoteId
          : remoteId // ignore: cast_nullable_to_non_nullable
              as int?,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      currency: null == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      balance: null == balance
          ? _value.balance
          : balance // ignore: cast_nullable_to_non_nullable
              as double,
      includeInTotal: null == includeInTotal
          ? _value.includeInTotal
          : includeInTotal // ignore: cast_nullable_to_non_nullable
              as bool,
      notes: null == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String,
      apiUrl: freezed == apiUrl
          ? _value.apiUrl
          : apiUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      apiValuePath: freezed == apiValuePath
          ? _value.apiValuePath
          : apiValuePath // ignore: cast_nullable_to_non_nullable
              as String?,
      apiAuth: freezed == apiAuth
          ? _value.apiAuth
          : apiAuth // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      synced: null == synced
          ? _value.synced
          : synced // ignore: cast_nullable_to_non_nullable
              as bool,
      convertedBalance: null == convertedBalance
          ? _value.convertedBalance
          : convertedBalance // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AccountImplCopyWith<$Res> implements $AccountCopyWith<$Res> {
  factory _$$AccountImplCopyWith(
          _$AccountImpl value, $Res Function(_$AccountImpl) then) =
      __$$AccountImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      int? remoteId,
      String name,
      String currency,
      double balance,
      bool includeInTotal,
      String notes,
      String? apiUrl,
      String? apiValuePath,
      String? apiAuth,
      DateTime? createdAt,
      DateTime? updatedAt,
      bool synced,
      double convertedBalance});
}

/// @nodoc
class __$$AccountImplCopyWithImpl<$Res>
    extends _$AccountCopyWithImpl<$Res, _$AccountImpl>
    implements _$$AccountImplCopyWith<$Res> {
  __$$AccountImplCopyWithImpl(
      _$AccountImpl _value, $Res Function(_$AccountImpl) _then)
      : super(_value, _then);

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? remoteId = freezed,
    Object? name = null,
    Object? currency = null,
    Object? balance = null,
    Object? includeInTotal = null,
    Object? notes = null,
    Object? apiUrl = freezed,
    Object? apiValuePath = freezed,
    Object? apiAuth = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? synced = null,
    Object? convertedBalance = null,
  }) {
    return _then(_$AccountImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      remoteId: freezed == remoteId
          ? _value.remoteId
          : remoteId // ignore: cast_nullable_to_non_nullable
              as int?,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      currency: null == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      balance: null == balance
          ? _value.balance
          : balance // ignore: cast_nullable_to_non_nullable
              as double,
      includeInTotal: null == includeInTotal
          ? _value.includeInTotal
          : includeInTotal // ignore: cast_nullable_to_non_nullable
              as bool,
      notes: null == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String,
      apiUrl: freezed == apiUrl
          ? _value.apiUrl
          : apiUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      apiValuePath: freezed == apiValuePath
          ? _value.apiValuePath
          : apiValuePath // ignore: cast_nullable_to_non_nullable
              as String?,
      apiAuth: freezed == apiAuth
          ? _value.apiAuth
          : apiAuth // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      synced: null == synced
          ? _value.synced
          : synced // ignore: cast_nullable_to_non_nullable
              as bool,
      convertedBalance: null == convertedBalance
          ? _value.convertedBalance
          : convertedBalance // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AccountImpl implements _Account {
  const _$AccountImpl(
      {required this.id,
      this.remoteId,
      required this.name,
      required this.currency,
      this.balance = 0,
      this.includeInTotal = true,
      this.notes = '',
      this.apiUrl,
      this.apiValuePath,
      this.apiAuth,
      this.createdAt,
      this.updatedAt,
      this.synced = false,
      this.convertedBalance = 0});

  factory _$AccountImpl.fromJson(Map<String, dynamic> json) =>
      _$$AccountImplFromJson(json);

  @override
  final int id;
  @override
  final int? remoteId;
  @override
  final String name;
  @override
  final String currency;
  @override
  @JsonKey()
  final double balance;
  @override
  @JsonKey()
  final bool includeInTotal;
  @override
  @JsonKey()
  final String notes;
  @override
  final String? apiUrl;
  @override
  final String? apiValuePath;
  @override
  final String? apiAuth;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;
  @override
  @JsonKey()
  final bool synced;
// Display fields (not stored)
  @override
  @JsonKey()
  final double convertedBalance;

  @override
  String toString() {
    return 'Account(id: $id, remoteId: $remoteId, name: $name, currency: $currency, balance: $balance, includeInTotal: $includeInTotal, notes: $notes, apiUrl: $apiUrl, apiValuePath: $apiValuePath, apiAuth: $apiAuth, createdAt: $createdAt, updatedAt: $updatedAt, synced: $synced, convertedBalance: $convertedBalance)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AccountImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.remoteId, remoteId) ||
                other.remoteId == remoteId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.balance, balance) || other.balance == balance) &&
            (identical(other.includeInTotal, includeInTotal) ||
                other.includeInTotal == includeInTotal) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.apiUrl, apiUrl) || other.apiUrl == apiUrl) &&
            (identical(other.apiValuePath, apiValuePath) ||
                other.apiValuePath == apiValuePath) &&
            (identical(other.apiAuth, apiAuth) || other.apiAuth == apiAuth) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.synced, synced) || other.synced == synced) &&
            (identical(other.convertedBalance, convertedBalance) ||
                other.convertedBalance == convertedBalance));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      remoteId,
      name,
      currency,
      balance,
      includeInTotal,
      notes,
      apiUrl,
      apiValuePath,
      apiAuth,
      createdAt,
      updatedAt,
      synced,
      convertedBalance);

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AccountImplCopyWith<_$AccountImpl> get copyWith =>
      __$$AccountImplCopyWithImpl<_$AccountImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AccountImplToJson(
      this,
    );
  }
}

abstract class _Account implements Account {
  const factory _Account(
      {required final int id,
      final int? remoteId,
      required final String name,
      required final String currency,
      final double balance,
      final bool includeInTotal,
      final String notes,
      final String? apiUrl,
      final String? apiValuePath,
      final String? apiAuth,
      final DateTime? createdAt,
      final DateTime? updatedAt,
      final bool synced,
      final double convertedBalance}) = _$AccountImpl;

  factory _Account.fromJson(Map<String, dynamic> json) = _$AccountImpl.fromJson;

  @override
  int get id;
  @override
  int? get remoteId;
  @override
  String get name;
  @override
  String get currency;
  @override
  double get balance;
  @override
  bool get includeInTotal;
  @override
  String get notes;
  @override
  String? get apiUrl;
  @override
  String? get apiValuePath;
  @override
  String? get apiAuth;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;
  @override
  bool get synced; // Display fields (not stored)
  @override
  double get convertedBalance;

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AccountImplCopyWith<_$AccountImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
