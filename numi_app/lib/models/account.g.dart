// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AccountImpl _$$AccountImplFromJson(Map<String, dynamic> json) =>
    _$AccountImpl(
      id: (json['id'] as num).toInt(),
      remoteId: (json['remoteId'] as num?)?.toInt(),
      name: json['name'] as String,
      currency: json['currency'] as String,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      includeInTotal: json['includeInTotal'] as bool? ?? true,
      notes: json['notes'] as String? ?? '',
      apiUrl: json['apiUrl'] as String?,
      apiValuePath: json['apiValuePath'] as String?,
      apiAuth: json['apiAuth'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      synced: json['synced'] as bool? ?? false,
      convertedBalance: (json['convertedBalance'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$$AccountImplToJson(_$AccountImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'remoteId': instance.remoteId,
      'name': instance.name,
      'currency': instance.currency,
      'balance': instance.balance,
      'includeInTotal': instance.includeInTotal,
      'notes': instance.notes,
      'apiUrl': instance.apiUrl,
      'apiValuePath': instance.apiValuePath,
      'apiAuth': instance.apiAuth,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'synced': instance.synced,
      'convertedBalance': instance.convertedBalance,
    };
