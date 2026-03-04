// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
mixin _$SyncQueueDaoMixin on DatabaseAccessor<AppDatabase> {
  $SyncQueueTable get syncQueue => attachedDatabase.syncQueue;
}
mixin _$ExpenseDaoMixin on DatabaseAccessor<AppDatabase> {
  $ExpensesTable get expenses => attachedDatabase.expenses;
}
mixin _$TripDaoMixin on DatabaseAccessor<AppDatabase> {
  $TripsTable get trips => attachedDatabase.trips;
  $TravelExpensesTable get travelExpenses => attachedDatabase.travelExpenses;
}
mixin _$AccountDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $BalanceSnapshotsTable get balanceSnapshots =>
      attachedDatabase.balanceSnapshots;
}
mixin _$ExchangeRateDaoMixin on DatabaseAccessor<AppDatabase> {
  $ExchangeRatesTable get exchangeRates => attachedDatabase.exchangeRates;
}

class $ExpensesTable extends Expenses
    with TableInfo<$ExpensesTable, DbExpense> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExpensesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<int> remoteId = GeneratedColumn<int>(
      'remote_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _amountUsdMeta =
      const VerificationMeta('amountUsd');
  @override
  late final GeneratedColumn<double> amountUsd = GeneratedColumn<double>(
      'amount_usd', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _amountCnyMeta =
      const VerificationMeta('amountCny');
  @override
  late final GeneratedColumn<double> amountCny = GeneratedColumn<double>(
      'amount_cny', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _amountHkdMeta =
      const VerificationMeta('amountHkd');
  @override
  late final GeneratedColumn<double> amountHkd = GeneratedColumn<double>(
      'amount_hkd', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _amountSgdMeta =
      const VerificationMeta('amountSgd');
  @override
  late final GeneratedColumn<double> amountSgd = GeneratedColumn<double>(
      'amount_sgd', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
      'synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        remoteId,
        amount,
        currency,
        date,
        category,
        name,
        notes,
        amountUsd,
        amountCny,
        amountHkd,
        amountSgd,
        createdAt,
        synced
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expenses';
  @override
  VerificationContext validateIntegrity(Insertable<DbExpense> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('amount_usd')) {
      context.handle(_amountUsdMeta,
          amountUsd.isAcceptableOrUnknown(data['amount_usd']!, _amountUsdMeta));
    }
    if (data.containsKey('amount_cny')) {
      context.handle(_amountCnyMeta,
          amountCny.isAcceptableOrUnknown(data['amount_cny']!, _amountCnyMeta));
    }
    if (data.containsKey('amount_hkd')) {
      context.handle(_amountHkdMeta,
          amountHkd.isAcceptableOrUnknown(data['amount_hkd']!, _amountHkdMeta));
    }
    if (data.containsKey('amount_sgd')) {
      context.handle(_amountSgdMeta,
          amountSgd.isAcceptableOrUnknown(data['amount_sgd']!, _amountSgdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('synced')) {
      context.handle(_syncedMeta,
          synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbExpense map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbExpense(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}remote_id']),
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
      amountUsd: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount_usd'])!,
      amountCny: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount_cny'])!,
      amountHkd: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount_hkd'])!,
      amountSgd: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount_sgd'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      synced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}synced'])!,
    );
  }

  @override
  $ExpensesTable createAlias(String alias) {
    return $ExpensesTable(attachedDatabase, alias);
  }
}

class DbExpense extends DataClass implements Insertable<DbExpense> {
  final int id;
  final int? remoteId;
  final double amount;
  final String currency;
  final DateTime date;
  final String category;
  final String name;
  final String notes;
  final double amountUsd;
  final double amountCny;
  final double amountHkd;
  final double amountSgd;
  final DateTime? createdAt;
  final bool synced;
  const DbExpense(
      {required this.id,
      this.remoteId,
      required this.amount,
      required this.currency,
      required this.date,
      required this.category,
      required this.name,
      required this.notes,
      required this.amountUsd,
      required this.amountCny,
      required this.amountHkd,
      required this.amountSgd,
      this.createdAt,
      required this.synced});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<int>(remoteId);
    }
    map['amount'] = Variable<double>(amount);
    map['currency'] = Variable<String>(currency);
    map['date'] = Variable<DateTime>(date);
    map['category'] = Variable<String>(category);
    map['name'] = Variable<String>(name);
    map['notes'] = Variable<String>(notes);
    map['amount_usd'] = Variable<double>(amountUsd);
    map['amount_cny'] = Variable<double>(amountCny);
    map['amount_hkd'] = Variable<double>(amountHkd);
    map['amount_sgd'] = Variable<double>(amountSgd);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  ExpensesCompanion toCompanion(bool nullToAbsent) {
    return ExpensesCompanion(
      id: Value(id),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      amount: Value(amount),
      currency: Value(currency),
      date: Value(date),
      category: Value(category),
      name: Value(name),
      notes: Value(notes),
      amountUsd: Value(amountUsd),
      amountCny: Value(amountCny),
      amountHkd: Value(amountHkd),
      amountSgd: Value(amountSgd),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      synced: Value(synced),
    );
  }

  factory DbExpense.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbExpense(
      id: serializer.fromJson<int>(json['id']),
      remoteId: serializer.fromJson<int?>(json['remoteId']),
      amount: serializer.fromJson<double>(json['amount']),
      currency: serializer.fromJson<String>(json['currency']),
      date: serializer.fromJson<DateTime>(json['date']),
      category: serializer.fromJson<String>(json['category']),
      name: serializer.fromJson<String>(json['name']),
      notes: serializer.fromJson<String>(json['notes']),
      amountUsd: serializer.fromJson<double>(json['amountUsd']),
      amountCny: serializer.fromJson<double>(json['amountCny']),
      amountHkd: serializer.fromJson<double>(json['amountHkd']),
      amountSgd: serializer.fromJson<double>(json['amountSgd']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'remoteId': serializer.toJson<int?>(remoteId),
      'amount': serializer.toJson<double>(amount),
      'currency': serializer.toJson<String>(currency),
      'date': serializer.toJson<DateTime>(date),
      'category': serializer.toJson<String>(category),
      'name': serializer.toJson<String>(name),
      'notes': serializer.toJson<String>(notes),
      'amountUsd': serializer.toJson<double>(amountUsd),
      'amountCny': serializer.toJson<double>(amountCny),
      'amountHkd': serializer.toJson<double>(amountHkd),
      'amountSgd': serializer.toJson<double>(amountSgd),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  DbExpense copyWith(
          {int? id,
          Value<int?> remoteId = const Value.absent(),
          double? amount,
          String? currency,
          DateTime? date,
          String? category,
          String? name,
          String? notes,
          double? amountUsd,
          double? amountCny,
          double? amountHkd,
          double? amountSgd,
          Value<DateTime?> createdAt = const Value.absent(),
          bool? synced}) =>
      DbExpense(
        id: id ?? this.id,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        date: date ?? this.date,
        category: category ?? this.category,
        name: name ?? this.name,
        notes: notes ?? this.notes,
        amountUsd: amountUsd ?? this.amountUsd,
        amountCny: amountCny ?? this.amountCny,
        amountHkd: amountHkd ?? this.amountHkd,
        amountSgd: amountSgd ?? this.amountSgd,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        synced: synced ?? this.synced,
      );
  DbExpense copyWithCompanion(ExpensesCompanion data) {
    return DbExpense(
      id: data.id.present ? data.id.value : this.id,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      amount: data.amount.present ? data.amount.value : this.amount,
      currency: data.currency.present ? data.currency.value : this.currency,
      date: data.date.present ? data.date.value : this.date,
      category: data.category.present ? data.category.value : this.category,
      name: data.name.present ? data.name.value : this.name,
      notes: data.notes.present ? data.notes.value : this.notes,
      amountUsd: data.amountUsd.present ? data.amountUsd.value : this.amountUsd,
      amountCny: data.amountCny.present ? data.amountCny.value : this.amountCny,
      amountHkd: data.amountHkd.present ? data.amountHkd.value : this.amountHkd,
      amountSgd: data.amountSgd.present ? data.amountSgd.value : this.amountSgd,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbExpense(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('date: $date, ')
          ..write('category: $category, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('amountUsd: $amountUsd, ')
          ..write('amountCny: $amountCny, ')
          ..write('amountHkd: $amountHkd, ')
          ..write('amountSgd: $amountSgd, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      remoteId,
      amount,
      currency,
      date,
      category,
      name,
      notes,
      amountUsd,
      amountCny,
      amountHkd,
      amountSgd,
      createdAt,
      synced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbExpense &&
          other.id == this.id &&
          other.remoteId == this.remoteId &&
          other.amount == this.amount &&
          other.currency == this.currency &&
          other.date == this.date &&
          other.category == this.category &&
          other.name == this.name &&
          other.notes == this.notes &&
          other.amountUsd == this.amountUsd &&
          other.amountCny == this.amountCny &&
          other.amountHkd == this.amountHkd &&
          other.amountSgd == this.amountSgd &&
          other.createdAt == this.createdAt &&
          other.synced == this.synced);
}

class ExpensesCompanion extends UpdateCompanion<DbExpense> {
  final Value<int> id;
  final Value<int?> remoteId;
  final Value<double> amount;
  final Value<String> currency;
  final Value<DateTime> date;
  final Value<String> category;
  final Value<String> name;
  final Value<String> notes;
  final Value<double> amountUsd;
  final Value<double> amountCny;
  final Value<double> amountHkd;
  final Value<double> amountSgd;
  final Value<DateTime?> createdAt;
  final Value<bool> synced;
  const ExpensesCompanion({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.amount = const Value.absent(),
    this.currency = const Value.absent(),
    this.date = const Value.absent(),
    this.category = const Value.absent(),
    this.name = const Value.absent(),
    this.notes = const Value.absent(),
    this.amountUsd = const Value.absent(),
    this.amountCny = const Value.absent(),
    this.amountHkd = const Value.absent(),
    this.amountSgd = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.synced = const Value.absent(),
  });
  ExpensesCompanion.insert({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    required double amount,
    required String currency,
    required DateTime date,
    required String category,
    required String name,
    this.notes = const Value.absent(),
    this.amountUsd = const Value.absent(),
    this.amountCny = const Value.absent(),
    this.amountHkd = const Value.absent(),
    this.amountSgd = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.synced = const Value.absent(),
  })  : amount = Value(amount),
        currency = Value(currency),
        date = Value(date),
        category = Value(category),
        name = Value(name);
  static Insertable<DbExpense> custom({
    Expression<int>? id,
    Expression<int>? remoteId,
    Expression<double>? amount,
    Expression<String>? currency,
    Expression<DateTime>? date,
    Expression<String>? category,
    Expression<String>? name,
    Expression<String>? notes,
    Expression<double>? amountUsd,
    Expression<double>? amountCny,
    Expression<double>? amountHkd,
    Expression<double>? amountSgd,
    Expression<DateTime>? createdAt,
    Expression<bool>? synced,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (remoteId != null) 'remote_id': remoteId,
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency,
      if (date != null) 'date': date,
      if (category != null) 'category': category,
      if (name != null) 'name': name,
      if (notes != null) 'notes': notes,
      if (amountUsd != null) 'amount_usd': amountUsd,
      if (amountCny != null) 'amount_cny': amountCny,
      if (amountHkd != null) 'amount_hkd': amountHkd,
      if (amountSgd != null) 'amount_sgd': amountSgd,
      if (createdAt != null) 'created_at': createdAt,
      if (synced != null) 'synced': synced,
    });
  }

  ExpensesCompanion copyWith(
      {Value<int>? id,
      Value<int?>? remoteId,
      Value<double>? amount,
      Value<String>? currency,
      Value<DateTime>? date,
      Value<String>? category,
      Value<String>? name,
      Value<String>? notes,
      Value<double>? amountUsd,
      Value<double>? amountCny,
      Value<double>? amountHkd,
      Value<double>? amountSgd,
      Value<DateTime?>? createdAt,
      Value<bool>? synced}) {
    return ExpensesCompanion(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      date: date ?? this.date,
      category: category ?? this.category,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      amountUsd: amountUsd ?? this.amountUsd,
      amountCny: amountCny ?? this.amountCny,
      amountHkd: amountHkd ?? this.amountHkd,
      amountSgd: amountSgd ?? this.amountSgd,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<int>(remoteId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (amountUsd.present) {
      map['amount_usd'] = Variable<double>(amountUsd.value);
    }
    if (amountCny.present) {
      map['amount_cny'] = Variable<double>(amountCny.value);
    }
    if (amountHkd.present) {
      map['amount_hkd'] = Variable<double>(amountHkd.value);
    }
    if (amountSgd.present) {
      map['amount_sgd'] = Variable<double>(amountSgd.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpensesCompanion(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('date: $date, ')
          ..write('category: $category, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('amountUsd: $amountUsd, ')
          ..write('amountCny: $amountCny, ')
          ..write('amountHkd: $amountHkd, ')
          ..write('amountSgd: $amountSgd, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }
}

class $TripsTable extends Trips with TableInfo<$TripsTable, DbTrip> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<int> remoteId = GeneratedColumn<int>(
      'remote_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _destinationMeta =
      const VerificationMeta('destination');
  @override
  late final GeneratedColumn<String> destination = GeneratedColumn<String>(
      'destination', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startDateMeta =
      const VerificationMeta('startDate');
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
      'start_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _endDateMeta =
      const VerificationMeta('endDate');
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
      'end_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
      'synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, remoteId, destination, startDate, endDate, notes, createdAt, synced];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trips';
  @override
  VerificationContext validateIntegrity(Insertable<DbTrip> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    }
    if (data.containsKey('destination')) {
      context.handle(
          _destinationMeta,
          destination.isAcceptableOrUnknown(
              data['destination']!, _destinationMeta));
    } else if (isInserting) {
      context.missing(_destinationMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(_startDateMeta,
          startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta));
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(_endDateMeta,
          endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta));
    } else if (isInserting) {
      context.missing(_endDateMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('synced')) {
      context.handle(_syncedMeta,
          synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbTrip map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbTrip(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}remote_id']),
      destination: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}destination'])!,
      startDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_date'])!,
      endDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}end_date'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      synced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}synced'])!,
    );
  }

  @override
  $TripsTable createAlias(String alias) {
    return $TripsTable(attachedDatabase, alias);
  }
}

class DbTrip extends DataClass implements Insertable<DbTrip> {
  final int id;
  final int? remoteId;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final String notes;
  final DateTime? createdAt;
  final bool synced;
  const DbTrip(
      {required this.id,
      this.remoteId,
      required this.destination,
      required this.startDate,
      required this.endDate,
      required this.notes,
      this.createdAt,
      required this.synced});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<int>(remoteId);
    }
    map['destination'] = Variable<String>(destination);
    map['start_date'] = Variable<DateTime>(startDate);
    map['end_date'] = Variable<DateTime>(endDate);
    map['notes'] = Variable<String>(notes);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  TripsCompanion toCompanion(bool nullToAbsent) {
    return TripsCompanion(
      id: Value(id),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      destination: Value(destination),
      startDate: Value(startDate),
      endDate: Value(endDate),
      notes: Value(notes),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      synced: Value(synced),
    );
  }

  factory DbTrip.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbTrip(
      id: serializer.fromJson<int>(json['id']),
      remoteId: serializer.fromJson<int?>(json['remoteId']),
      destination: serializer.fromJson<String>(json['destination']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime>(json['endDate']),
      notes: serializer.fromJson<String>(json['notes']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'remoteId': serializer.toJson<int?>(remoteId),
      'destination': serializer.toJson<String>(destination),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime>(endDate),
      'notes': serializer.toJson<String>(notes),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  DbTrip copyWith(
          {int? id,
          Value<int?> remoteId = const Value.absent(),
          String? destination,
          DateTime? startDate,
          DateTime? endDate,
          String? notes,
          Value<DateTime?> createdAt = const Value.absent(),
          bool? synced}) =>
      DbTrip(
        id: id ?? this.id,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        destination: destination ?? this.destination,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        notes: notes ?? this.notes,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        synced: synced ?? this.synced,
      );
  DbTrip copyWithCompanion(TripsCompanion data) {
    return DbTrip(
      id: data.id.present ? data.id.value : this.id,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      destination:
          data.destination.present ? data.destination.value : this.destination,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbTrip(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('destination: $destination, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, remoteId, destination, startDate, endDate, notes, createdAt, synced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbTrip &&
          other.id == this.id &&
          other.remoteId == this.remoteId &&
          other.destination == this.destination &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.synced == this.synced);
}

class TripsCompanion extends UpdateCompanion<DbTrip> {
  final Value<int> id;
  final Value<int?> remoteId;
  final Value<String> destination;
  final Value<DateTime> startDate;
  final Value<DateTime> endDate;
  final Value<String> notes;
  final Value<DateTime?> createdAt;
  final Value<bool> synced;
  const TripsCompanion({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.destination = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.synced = const Value.absent(),
  });
  TripsCompanion.insert({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.synced = const Value.absent(),
  })  : destination = Value(destination),
        startDate = Value(startDate),
        endDate = Value(endDate);
  static Insertable<DbTrip> custom({
    Expression<int>? id,
    Expression<int>? remoteId,
    Expression<String>? destination,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<bool>? synced,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (remoteId != null) 'remote_id': remoteId,
      if (destination != null) 'destination': destination,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (synced != null) 'synced': synced,
    });
  }

  TripsCompanion copyWith(
      {Value<int>? id,
      Value<int?>? remoteId,
      Value<String>? destination,
      Value<DateTime>? startDate,
      Value<DateTime>? endDate,
      Value<String>? notes,
      Value<DateTime?>? createdAt,
      Value<bool>? synced}) {
    return TripsCompanion(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      destination: destination ?? this.destination,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<int>(remoteId.value);
    }
    if (destination.present) {
      map['destination'] = Variable<String>(destination.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripsCompanion(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('destination: $destination, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }
}

class $TravelExpensesTable extends TravelExpenses
    with TableInfo<$TravelExpensesTable, DbTravelExpense> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TravelExpensesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<int> remoteId = GeneratedColumn<int>(
      'remote_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<int> tripId = GeneratedColumn<int>(
      'trip_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES trips (id)'));
  static const VerificationMeta _tripRemoteIdMeta =
      const VerificationMeta('tripRemoteId');
  @override
  late final GeneratedColumn<int> tripRemoteId = GeneratedColumn<int>(
      'trip_remote_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _amountUsdMeta =
      const VerificationMeta('amountUsd');
  @override
  late final GeneratedColumn<double> amountUsd = GeneratedColumn<double>(
      'amount_usd', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _amountCnyMeta =
      const VerificationMeta('amountCny');
  @override
  late final GeneratedColumn<double> amountCny = GeneratedColumn<double>(
      'amount_cny', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _amountHkdMeta =
      const VerificationMeta('amountHkd');
  @override
  late final GeneratedColumn<double> amountHkd = GeneratedColumn<double>(
      'amount_hkd', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _amountSgdMeta =
      const VerificationMeta('amountSgd');
  @override
  late final GeneratedColumn<double> amountSgd = GeneratedColumn<double>(
      'amount_sgd', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
      'synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        remoteId,
        tripId,
        tripRemoteId,
        amount,
        currency,
        date,
        category,
        name,
        notes,
        amountUsd,
        amountCny,
        amountHkd,
        amountSgd,
        createdAt,
        synced
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'travel_expenses';
  @override
  VerificationContext validateIntegrity(Insertable<DbTravelExpense> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    }
    if (data.containsKey('trip_id')) {
      context.handle(_tripIdMeta,
          tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta));
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('trip_remote_id')) {
      context.handle(
          _tripRemoteIdMeta,
          tripRemoteId.isAcceptableOrUnknown(
              data['trip_remote_id']!, _tripRemoteIdMeta));
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('amount_usd')) {
      context.handle(_amountUsdMeta,
          amountUsd.isAcceptableOrUnknown(data['amount_usd']!, _amountUsdMeta));
    }
    if (data.containsKey('amount_cny')) {
      context.handle(_amountCnyMeta,
          amountCny.isAcceptableOrUnknown(data['amount_cny']!, _amountCnyMeta));
    }
    if (data.containsKey('amount_hkd')) {
      context.handle(_amountHkdMeta,
          amountHkd.isAcceptableOrUnknown(data['amount_hkd']!, _amountHkdMeta));
    }
    if (data.containsKey('amount_sgd')) {
      context.handle(_amountSgdMeta,
          amountSgd.isAcceptableOrUnknown(data['amount_sgd']!, _amountSgdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('synced')) {
      context.handle(_syncedMeta,
          synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbTravelExpense map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbTravelExpense(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}remote_id']),
      tripId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trip_id'])!,
      tripRemoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trip_remote_id']),
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
      amountUsd: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount_usd'])!,
      amountCny: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount_cny'])!,
      amountHkd: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount_hkd'])!,
      amountSgd: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount_sgd'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      synced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}synced'])!,
    );
  }

  @override
  $TravelExpensesTable createAlias(String alias) {
    return $TravelExpensesTable(attachedDatabase, alias);
  }
}

class DbTravelExpense extends DataClass implements Insertable<DbTravelExpense> {
  final int id;
  final int? remoteId;
  final int tripId;
  final int? tripRemoteId;
  final double amount;
  final String currency;
  final DateTime date;
  final String category;
  final String name;
  final String notes;
  final double amountUsd;
  final double amountCny;
  final double amountHkd;
  final double amountSgd;
  final DateTime? createdAt;
  final bool synced;
  const DbTravelExpense(
      {required this.id,
      this.remoteId,
      required this.tripId,
      this.tripRemoteId,
      required this.amount,
      required this.currency,
      required this.date,
      required this.category,
      required this.name,
      required this.notes,
      required this.amountUsd,
      required this.amountCny,
      required this.amountHkd,
      required this.amountSgd,
      this.createdAt,
      required this.synced});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<int>(remoteId);
    }
    map['trip_id'] = Variable<int>(tripId);
    if (!nullToAbsent || tripRemoteId != null) {
      map['trip_remote_id'] = Variable<int>(tripRemoteId);
    }
    map['amount'] = Variable<double>(amount);
    map['currency'] = Variable<String>(currency);
    map['date'] = Variable<DateTime>(date);
    map['category'] = Variable<String>(category);
    map['name'] = Variable<String>(name);
    map['notes'] = Variable<String>(notes);
    map['amount_usd'] = Variable<double>(amountUsd);
    map['amount_cny'] = Variable<double>(amountCny);
    map['amount_hkd'] = Variable<double>(amountHkd);
    map['amount_sgd'] = Variable<double>(amountSgd);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  TravelExpensesCompanion toCompanion(bool nullToAbsent) {
    return TravelExpensesCompanion(
      id: Value(id),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      tripId: Value(tripId),
      tripRemoteId: tripRemoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(tripRemoteId),
      amount: Value(amount),
      currency: Value(currency),
      date: Value(date),
      category: Value(category),
      name: Value(name),
      notes: Value(notes),
      amountUsd: Value(amountUsd),
      amountCny: Value(amountCny),
      amountHkd: Value(amountHkd),
      amountSgd: Value(amountSgd),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      synced: Value(synced),
    );
  }

  factory DbTravelExpense.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbTravelExpense(
      id: serializer.fromJson<int>(json['id']),
      remoteId: serializer.fromJson<int?>(json['remoteId']),
      tripId: serializer.fromJson<int>(json['tripId']),
      tripRemoteId: serializer.fromJson<int?>(json['tripRemoteId']),
      amount: serializer.fromJson<double>(json['amount']),
      currency: serializer.fromJson<String>(json['currency']),
      date: serializer.fromJson<DateTime>(json['date']),
      category: serializer.fromJson<String>(json['category']),
      name: serializer.fromJson<String>(json['name']),
      notes: serializer.fromJson<String>(json['notes']),
      amountUsd: serializer.fromJson<double>(json['amountUsd']),
      amountCny: serializer.fromJson<double>(json['amountCny']),
      amountHkd: serializer.fromJson<double>(json['amountHkd']),
      amountSgd: serializer.fromJson<double>(json['amountSgd']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'remoteId': serializer.toJson<int?>(remoteId),
      'tripId': serializer.toJson<int>(tripId),
      'tripRemoteId': serializer.toJson<int?>(tripRemoteId),
      'amount': serializer.toJson<double>(amount),
      'currency': serializer.toJson<String>(currency),
      'date': serializer.toJson<DateTime>(date),
      'category': serializer.toJson<String>(category),
      'name': serializer.toJson<String>(name),
      'notes': serializer.toJson<String>(notes),
      'amountUsd': serializer.toJson<double>(amountUsd),
      'amountCny': serializer.toJson<double>(amountCny),
      'amountHkd': serializer.toJson<double>(amountHkd),
      'amountSgd': serializer.toJson<double>(amountSgd),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  DbTravelExpense copyWith(
          {int? id,
          Value<int?> remoteId = const Value.absent(),
          int? tripId,
          Value<int?> tripRemoteId = const Value.absent(),
          double? amount,
          String? currency,
          DateTime? date,
          String? category,
          String? name,
          String? notes,
          double? amountUsd,
          double? amountCny,
          double? amountHkd,
          double? amountSgd,
          Value<DateTime?> createdAt = const Value.absent(),
          bool? synced}) =>
      DbTravelExpense(
        id: id ?? this.id,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        tripId: tripId ?? this.tripId,
        tripRemoteId:
            tripRemoteId.present ? tripRemoteId.value : this.tripRemoteId,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        date: date ?? this.date,
        category: category ?? this.category,
        name: name ?? this.name,
        notes: notes ?? this.notes,
        amountUsd: amountUsd ?? this.amountUsd,
        amountCny: amountCny ?? this.amountCny,
        amountHkd: amountHkd ?? this.amountHkd,
        amountSgd: amountSgd ?? this.amountSgd,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        synced: synced ?? this.synced,
      );
  DbTravelExpense copyWithCompanion(TravelExpensesCompanion data) {
    return DbTravelExpense(
      id: data.id.present ? data.id.value : this.id,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      tripRemoteId: data.tripRemoteId.present
          ? data.tripRemoteId.value
          : this.tripRemoteId,
      amount: data.amount.present ? data.amount.value : this.amount,
      currency: data.currency.present ? data.currency.value : this.currency,
      date: data.date.present ? data.date.value : this.date,
      category: data.category.present ? data.category.value : this.category,
      name: data.name.present ? data.name.value : this.name,
      notes: data.notes.present ? data.notes.value : this.notes,
      amountUsd: data.amountUsd.present ? data.amountUsd.value : this.amountUsd,
      amountCny: data.amountCny.present ? data.amountCny.value : this.amountCny,
      amountHkd: data.amountHkd.present ? data.amountHkd.value : this.amountHkd,
      amountSgd: data.amountSgd.present ? data.amountSgd.value : this.amountSgd,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbTravelExpense(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('tripId: $tripId, ')
          ..write('tripRemoteId: $tripRemoteId, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('date: $date, ')
          ..write('category: $category, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('amountUsd: $amountUsd, ')
          ..write('amountCny: $amountCny, ')
          ..write('amountHkd: $amountHkd, ')
          ..write('amountSgd: $amountSgd, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      remoteId,
      tripId,
      tripRemoteId,
      amount,
      currency,
      date,
      category,
      name,
      notes,
      amountUsd,
      amountCny,
      amountHkd,
      amountSgd,
      createdAt,
      synced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbTravelExpense &&
          other.id == this.id &&
          other.remoteId == this.remoteId &&
          other.tripId == this.tripId &&
          other.tripRemoteId == this.tripRemoteId &&
          other.amount == this.amount &&
          other.currency == this.currency &&
          other.date == this.date &&
          other.category == this.category &&
          other.name == this.name &&
          other.notes == this.notes &&
          other.amountUsd == this.amountUsd &&
          other.amountCny == this.amountCny &&
          other.amountHkd == this.amountHkd &&
          other.amountSgd == this.amountSgd &&
          other.createdAt == this.createdAt &&
          other.synced == this.synced);
}

class TravelExpensesCompanion extends UpdateCompanion<DbTravelExpense> {
  final Value<int> id;
  final Value<int?> remoteId;
  final Value<int> tripId;
  final Value<int?> tripRemoteId;
  final Value<double> amount;
  final Value<String> currency;
  final Value<DateTime> date;
  final Value<String> category;
  final Value<String> name;
  final Value<String> notes;
  final Value<double> amountUsd;
  final Value<double> amountCny;
  final Value<double> amountHkd;
  final Value<double> amountSgd;
  final Value<DateTime?> createdAt;
  final Value<bool> synced;
  const TravelExpensesCompanion({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.tripId = const Value.absent(),
    this.tripRemoteId = const Value.absent(),
    this.amount = const Value.absent(),
    this.currency = const Value.absent(),
    this.date = const Value.absent(),
    this.category = const Value.absent(),
    this.name = const Value.absent(),
    this.notes = const Value.absent(),
    this.amountUsd = const Value.absent(),
    this.amountCny = const Value.absent(),
    this.amountHkd = const Value.absent(),
    this.amountSgd = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.synced = const Value.absent(),
  });
  TravelExpensesCompanion.insert({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    required int tripId,
    this.tripRemoteId = const Value.absent(),
    required double amount,
    required String currency,
    required DateTime date,
    required String category,
    required String name,
    this.notes = const Value.absent(),
    this.amountUsd = const Value.absent(),
    this.amountCny = const Value.absent(),
    this.amountHkd = const Value.absent(),
    this.amountSgd = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.synced = const Value.absent(),
  })  : tripId = Value(tripId),
        amount = Value(amount),
        currency = Value(currency),
        date = Value(date),
        category = Value(category),
        name = Value(name);
  static Insertable<DbTravelExpense> custom({
    Expression<int>? id,
    Expression<int>? remoteId,
    Expression<int>? tripId,
    Expression<int>? tripRemoteId,
    Expression<double>? amount,
    Expression<String>? currency,
    Expression<DateTime>? date,
    Expression<String>? category,
    Expression<String>? name,
    Expression<String>? notes,
    Expression<double>? amountUsd,
    Expression<double>? amountCny,
    Expression<double>? amountHkd,
    Expression<double>? amountSgd,
    Expression<DateTime>? createdAt,
    Expression<bool>? synced,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (remoteId != null) 'remote_id': remoteId,
      if (tripId != null) 'trip_id': tripId,
      if (tripRemoteId != null) 'trip_remote_id': tripRemoteId,
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency,
      if (date != null) 'date': date,
      if (category != null) 'category': category,
      if (name != null) 'name': name,
      if (notes != null) 'notes': notes,
      if (amountUsd != null) 'amount_usd': amountUsd,
      if (amountCny != null) 'amount_cny': amountCny,
      if (amountHkd != null) 'amount_hkd': amountHkd,
      if (amountSgd != null) 'amount_sgd': amountSgd,
      if (createdAt != null) 'created_at': createdAt,
      if (synced != null) 'synced': synced,
    });
  }

  TravelExpensesCompanion copyWith(
      {Value<int>? id,
      Value<int?>? remoteId,
      Value<int>? tripId,
      Value<int?>? tripRemoteId,
      Value<double>? amount,
      Value<String>? currency,
      Value<DateTime>? date,
      Value<String>? category,
      Value<String>? name,
      Value<String>? notes,
      Value<double>? amountUsd,
      Value<double>? amountCny,
      Value<double>? amountHkd,
      Value<double>? amountSgd,
      Value<DateTime?>? createdAt,
      Value<bool>? synced}) {
    return TravelExpensesCompanion(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      tripId: tripId ?? this.tripId,
      tripRemoteId: tripRemoteId ?? this.tripRemoteId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      date: date ?? this.date,
      category: category ?? this.category,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      amountUsd: amountUsd ?? this.amountUsd,
      amountCny: amountCny ?? this.amountCny,
      amountHkd: amountHkd ?? this.amountHkd,
      amountSgd: amountSgd ?? this.amountSgd,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<int>(remoteId.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<int>(tripId.value);
    }
    if (tripRemoteId.present) {
      map['trip_remote_id'] = Variable<int>(tripRemoteId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (amountUsd.present) {
      map['amount_usd'] = Variable<double>(amountUsd.value);
    }
    if (amountCny.present) {
      map['amount_cny'] = Variable<double>(amountCny.value);
    }
    if (amountHkd.present) {
      map['amount_hkd'] = Variable<double>(amountHkd.value);
    }
    if (amountSgd.present) {
      map['amount_sgd'] = Variable<double>(amountSgd.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TravelExpensesCompanion(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('tripId: $tripId, ')
          ..write('tripRemoteId: $tripRemoteId, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('date: $date, ')
          ..write('category: $category, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('amountUsd: $amountUsd, ')
          ..write('amountCny: $amountCny, ')
          ..write('amountHkd: $amountHkd, ')
          ..write('amountSgd: $amountSgd, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }
}

class $AccountsTable extends Accounts
    with TableInfo<$AccountsTable, DbAccount> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<int> remoteId = GeneratedColumn<int>(
      'remote_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _balanceMeta =
      const VerificationMeta('balance');
  @override
  late final GeneratedColumn<double> balance = GeneratedColumn<double>(
      'balance', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _includeInTotalMeta =
      const VerificationMeta('includeInTotal');
  @override
  late final GeneratedColumn<bool> includeInTotal = GeneratedColumn<bool>(
      'include_in_total', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("include_in_total" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _apiUrlMeta = const VerificationMeta('apiUrl');
  @override
  late final GeneratedColumn<String> apiUrl = GeneratedColumn<String>(
      'api_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _apiValuePathMeta =
      const VerificationMeta('apiValuePath');
  @override
  late final GeneratedColumn<String> apiValuePath = GeneratedColumn<String>(
      'api_value_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _apiAuthMeta =
      const VerificationMeta('apiAuth');
  @override
  late final GeneratedColumn<String> apiAuth = GeneratedColumn<String>(
      'api_auth', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
      'synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
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
        synced
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(Insertable<DbAccount> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('balance')) {
      context.handle(_balanceMeta,
          balance.isAcceptableOrUnknown(data['balance']!, _balanceMeta));
    }
    if (data.containsKey('include_in_total')) {
      context.handle(
          _includeInTotalMeta,
          includeInTotal.isAcceptableOrUnknown(
              data['include_in_total']!, _includeInTotalMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('api_url')) {
      context.handle(_apiUrlMeta,
          apiUrl.isAcceptableOrUnknown(data['api_url']!, _apiUrlMeta));
    }
    if (data.containsKey('api_value_path')) {
      context.handle(
          _apiValuePathMeta,
          apiValuePath.isAcceptableOrUnknown(
              data['api_value_path']!, _apiValuePathMeta));
    }
    if (data.containsKey('api_auth')) {
      context.handle(_apiAuthMeta,
          apiAuth.isAcceptableOrUnknown(data['api_auth']!, _apiAuthMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('synced')) {
      context.handle(_syncedMeta,
          synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbAccount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbAccount(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}remote_id']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      balance: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}balance'])!,
      includeInTotal: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}include_in_total'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
      apiUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}api_url']),
      apiValuePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}api_value_path']),
      apiAuth: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}api_auth']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
      synced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}synced'])!,
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class DbAccount extends DataClass implements Insertable<DbAccount> {
  final int id;
  final int? remoteId;
  final String name;
  final String currency;
  final double balance;
  final bool includeInTotal;
  final String notes;
  final String? apiUrl;
  final String? apiValuePath;
  final String? apiAuth;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool synced;
  const DbAccount(
      {required this.id,
      this.remoteId,
      required this.name,
      required this.currency,
      required this.balance,
      required this.includeInTotal,
      required this.notes,
      this.apiUrl,
      this.apiValuePath,
      this.apiAuth,
      this.createdAt,
      this.updatedAt,
      required this.synced});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<int>(remoteId);
    }
    map['name'] = Variable<String>(name);
    map['currency'] = Variable<String>(currency);
    map['balance'] = Variable<double>(balance);
    map['include_in_total'] = Variable<bool>(includeInTotal);
    map['notes'] = Variable<String>(notes);
    if (!nullToAbsent || apiUrl != null) {
      map['api_url'] = Variable<String>(apiUrl);
    }
    if (!nullToAbsent || apiValuePath != null) {
      map['api_value_path'] = Variable<String>(apiValuePath);
    }
    if (!nullToAbsent || apiAuth != null) {
      map['api_auth'] = Variable<String>(apiAuth);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      name: Value(name),
      currency: Value(currency),
      balance: Value(balance),
      includeInTotal: Value(includeInTotal),
      notes: Value(notes),
      apiUrl:
          apiUrl == null && nullToAbsent ? const Value.absent() : Value(apiUrl),
      apiValuePath: apiValuePath == null && nullToAbsent
          ? const Value.absent()
          : Value(apiValuePath),
      apiAuth: apiAuth == null && nullToAbsent
          ? const Value.absent()
          : Value(apiAuth),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      synced: Value(synced),
    );
  }

  factory DbAccount.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbAccount(
      id: serializer.fromJson<int>(json['id']),
      remoteId: serializer.fromJson<int?>(json['remoteId']),
      name: serializer.fromJson<String>(json['name']),
      currency: serializer.fromJson<String>(json['currency']),
      balance: serializer.fromJson<double>(json['balance']),
      includeInTotal: serializer.fromJson<bool>(json['includeInTotal']),
      notes: serializer.fromJson<String>(json['notes']),
      apiUrl: serializer.fromJson<String?>(json['apiUrl']),
      apiValuePath: serializer.fromJson<String?>(json['apiValuePath']),
      apiAuth: serializer.fromJson<String?>(json['apiAuth']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'remoteId': serializer.toJson<int?>(remoteId),
      'name': serializer.toJson<String>(name),
      'currency': serializer.toJson<String>(currency),
      'balance': serializer.toJson<double>(balance),
      'includeInTotal': serializer.toJson<bool>(includeInTotal),
      'notes': serializer.toJson<String>(notes),
      'apiUrl': serializer.toJson<String?>(apiUrl),
      'apiValuePath': serializer.toJson<String?>(apiValuePath),
      'apiAuth': serializer.toJson<String?>(apiAuth),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  DbAccount copyWith(
          {int? id,
          Value<int?> remoteId = const Value.absent(),
          String? name,
          String? currency,
          double? balance,
          bool? includeInTotal,
          String? notes,
          Value<String?> apiUrl = const Value.absent(),
          Value<String?> apiValuePath = const Value.absent(),
          Value<String?> apiAuth = const Value.absent(),
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent(),
          bool? synced}) =>
      DbAccount(
        id: id ?? this.id,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        name: name ?? this.name,
        currency: currency ?? this.currency,
        balance: balance ?? this.balance,
        includeInTotal: includeInTotal ?? this.includeInTotal,
        notes: notes ?? this.notes,
        apiUrl: apiUrl.present ? apiUrl.value : this.apiUrl,
        apiValuePath:
            apiValuePath.present ? apiValuePath.value : this.apiValuePath,
        apiAuth: apiAuth.present ? apiAuth.value : this.apiAuth,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
        synced: synced ?? this.synced,
      );
  DbAccount copyWithCompanion(AccountsCompanion data) {
    return DbAccount(
      id: data.id.present ? data.id.value : this.id,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      name: data.name.present ? data.name.value : this.name,
      currency: data.currency.present ? data.currency.value : this.currency,
      balance: data.balance.present ? data.balance.value : this.balance,
      includeInTotal: data.includeInTotal.present
          ? data.includeInTotal.value
          : this.includeInTotal,
      notes: data.notes.present ? data.notes.value : this.notes,
      apiUrl: data.apiUrl.present ? data.apiUrl.value : this.apiUrl,
      apiValuePath: data.apiValuePath.present
          ? data.apiValuePath.value
          : this.apiValuePath,
      apiAuth: data.apiAuth.present ? data.apiAuth.value : this.apiAuth,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbAccount(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('name: $name, ')
          ..write('currency: $currency, ')
          ..write('balance: $balance, ')
          ..write('includeInTotal: $includeInTotal, ')
          ..write('notes: $notes, ')
          ..write('apiUrl: $apiUrl, ')
          ..write('apiValuePath: $apiValuePath, ')
          ..write('apiAuth: $apiAuth, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
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
      synced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbAccount &&
          other.id == this.id &&
          other.remoteId == this.remoteId &&
          other.name == this.name &&
          other.currency == this.currency &&
          other.balance == this.balance &&
          other.includeInTotal == this.includeInTotal &&
          other.notes == this.notes &&
          other.apiUrl == this.apiUrl &&
          other.apiValuePath == this.apiValuePath &&
          other.apiAuth == this.apiAuth &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.synced == this.synced);
}

class AccountsCompanion extends UpdateCompanion<DbAccount> {
  final Value<int> id;
  final Value<int?> remoteId;
  final Value<String> name;
  final Value<String> currency;
  final Value<double> balance;
  final Value<bool> includeInTotal;
  final Value<String> notes;
  final Value<String?> apiUrl;
  final Value<String?> apiValuePath;
  final Value<String?> apiAuth;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<bool> synced;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.name = const Value.absent(),
    this.currency = const Value.absent(),
    this.balance = const Value.absent(),
    this.includeInTotal = const Value.absent(),
    this.notes = const Value.absent(),
    this.apiUrl = const Value.absent(),
    this.apiValuePath = const Value.absent(),
    this.apiAuth = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.synced = const Value.absent(),
  });
  AccountsCompanion.insert({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    required String name,
    required String currency,
    this.balance = const Value.absent(),
    this.includeInTotal = const Value.absent(),
    this.notes = const Value.absent(),
    this.apiUrl = const Value.absent(),
    this.apiValuePath = const Value.absent(),
    this.apiAuth = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.synced = const Value.absent(),
  })  : name = Value(name),
        currency = Value(currency);
  static Insertable<DbAccount> custom({
    Expression<int>? id,
    Expression<int>? remoteId,
    Expression<String>? name,
    Expression<String>? currency,
    Expression<double>? balance,
    Expression<bool>? includeInTotal,
    Expression<String>? notes,
    Expression<String>? apiUrl,
    Expression<String>? apiValuePath,
    Expression<String>? apiAuth,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? synced,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (remoteId != null) 'remote_id': remoteId,
      if (name != null) 'name': name,
      if (currency != null) 'currency': currency,
      if (balance != null) 'balance': balance,
      if (includeInTotal != null) 'include_in_total': includeInTotal,
      if (notes != null) 'notes': notes,
      if (apiUrl != null) 'api_url': apiUrl,
      if (apiValuePath != null) 'api_value_path': apiValuePath,
      if (apiAuth != null) 'api_auth': apiAuth,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (synced != null) 'synced': synced,
    });
  }

  AccountsCompanion copyWith(
      {Value<int>? id,
      Value<int?>? remoteId,
      Value<String>? name,
      Value<String>? currency,
      Value<double>? balance,
      Value<bool>? includeInTotal,
      Value<String>? notes,
      Value<String?>? apiUrl,
      Value<String?>? apiValuePath,
      Value<String?>? apiAuth,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt,
      Value<bool>? synced}) {
    return AccountsCompanion(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      balance: balance ?? this.balance,
      includeInTotal: includeInTotal ?? this.includeInTotal,
      notes: notes ?? this.notes,
      apiUrl: apiUrl ?? this.apiUrl,
      apiValuePath: apiValuePath ?? this.apiValuePath,
      apiAuth: apiAuth ?? this.apiAuth,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<int>(remoteId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (balance.present) {
      map['balance'] = Variable<double>(balance.value);
    }
    if (includeInTotal.present) {
      map['include_in_total'] = Variable<bool>(includeInTotal.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (apiUrl.present) {
      map['api_url'] = Variable<String>(apiUrl.value);
    }
    if (apiValuePath.present) {
      map['api_value_path'] = Variable<String>(apiValuePath.value);
    }
    if (apiAuth.present) {
      map['api_auth'] = Variable<String>(apiAuth.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('name: $name, ')
          ..write('currency: $currency, ')
          ..write('balance: $balance, ')
          ..write('includeInTotal: $includeInTotal, ')
          ..write('notes: $notes, ')
          ..write('apiUrl: $apiUrl, ')
          ..write('apiValuePath: $apiValuePath, ')
          ..write('apiAuth: $apiAuth, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }
}

class $BalanceSnapshotsTable extends BalanceSnapshots
    with TableInfo<$BalanceSnapshotsTable, DbBalanceSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BalanceSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
      'account_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES accounts (id)'));
  static const VerificationMeta _balanceMeta =
      const VerificationMeta('balance');
  @override
  late final GeneratedColumn<double> balance = GeneratedColumn<double>(
      'balance', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _changeMeta = const VerificationMeta('change');
  @override
  late final GeneratedColumn<double> change = GeneratedColumn<double>(
      'change', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _snapshotDateMeta =
      const VerificationMeta('snapshotDate');
  @override
  late final GeneratedColumn<DateTime> snapshotDate = GeneratedColumn<DateTime>(
      'snapshot_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _amountUsdMeta =
      const VerificationMeta('amountUsd');
  @override
  late final GeneratedColumn<double> amountUsd = GeneratedColumn<double>(
      'amount_usd', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _amountCnyMeta =
      const VerificationMeta('amountCny');
  @override
  late final GeneratedColumn<double> amountCny = GeneratedColumn<double>(
      'amount_cny', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _amountHkdMeta =
      const VerificationMeta('amountHkd');
  @override
  late final GeneratedColumn<double> amountHkd = GeneratedColumn<double>(
      'amount_hkd', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _amountSgdMeta =
      const VerificationMeta('amountSgd');
  @override
  late final GeneratedColumn<double> amountSgd = GeneratedColumn<double>(
      'amount_sgd', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        accountId,
        balance,
        change,
        snapshotDate,
        amountUsd,
        amountCny,
        amountHkd,
        amountSgd
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'balance_snapshots';
  @override
  VerificationContext validateIntegrity(Insertable<DbBalanceSnapshot> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('balance')) {
      context.handle(_balanceMeta,
          balance.isAcceptableOrUnknown(data['balance']!, _balanceMeta));
    } else if (isInserting) {
      context.missing(_balanceMeta);
    }
    if (data.containsKey('change')) {
      context.handle(_changeMeta,
          change.isAcceptableOrUnknown(data['change']!, _changeMeta));
    }
    if (data.containsKey('snapshot_date')) {
      context.handle(
          _snapshotDateMeta,
          snapshotDate.isAcceptableOrUnknown(
              data['snapshot_date']!, _snapshotDateMeta));
    } else if (isInserting) {
      context.missing(_snapshotDateMeta);
    }
    if (data.containsKey('amount_usd')) {
      context.handle(_amountUsdMeta,
          amountUsd.isAcceptableOrUnknown(data['amount_usd']!, _amountUsdMeta));
    }
    if (data.containsKey('amount_cny')) {
      context.handle(_amountCnyMeta,
          amountCny.isAcceptableOrUnknown(data['amount_cny']!, _amountCnyMeta));
    }
    if (data.containsKey('amount_hkd')) {
      context.handle(_amountHkdMeta,
          amountHkd.isAcceptableOrUnknown(data['amount_hkd']!, _amountHkdMeta));
    }
    if (data.containsKey('amount_sgd')) {
      context.handle(_amountSgdMeta,
          amountSgd.isAcceptableOrUnknown(data['amount_sgd']!, _amountSgdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbBalanceSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbBalanceSnapshot(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}account_id'])!,
      balance: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}balance'])!,
      change: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}change'])!,
      snapshotDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}snapshot_date'])!,
      amountUsd: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount_usd'])!,
      amountCny: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount_cny'])!,
      amountHkd: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount_hkd'])!,
      amountSgd: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount_sgd'])!,
    );
  }

  @override
  $BalanceSnapshotsTable createAlias(String alias) {
    return $BalanceSnapshotsTable(attachedDatabase, alias);
  }
}

class DbBalanceSnapshot extends DataClass
    implements Insertable<DbBalanceSnapshot> {
  final int id;
  final int accountId;
  final double balance;
  final double change;
  final DateTime snapshotDate;
  final double amountUsd;
  final double amountCny;
  final double amountHkd;
  final double amountSgd;
  const DbBalanceSnapshot(
      {required this.id,
      required this.accountId,
      required this.balance,
      required this.change,
      required this.snapshotDate,
      required this.amountUsd,
      required this.amountCny,
      required this.amountHkd,
      required this.amountSgd});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_id'] = Variable<int>(accountId);
    map['balance'] = Variable<double>(balance);
    map['change'] = Variable<double>(change);
    map['snapshot_date'] = Variable<DateTime>(snapshotDate);
    map['amount_usd'] = Variable<double>(amountUsd);
    map['amount_cny'] = Variable<double>(amountCny);
    map['amount_hkd'] = Variable<double>(amountHkd);
    map['amount_sgd'] = Variable<double>(amountSgd);
    return map;
  }

  BalanceSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return BalanceSnapshotsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      balance: Value(balance),
      change: Value(change),
      snapshotDate: Value(snapshotDate),
      amountUsd: Value(amountUsd),
      amountCny: Value(amountCny),
      amountHkd: Value(amountHkd),
      amountSgd: Value(amountSgd),
    );
  }

  factory DbBalanceSnapshot.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbBalanceSnapshot(
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<int>(json['accountId']),
      balance: serializer.fromJson<double>(json['balance']),
      change: serializer.fromJson<double>(json['change']),
      snapshotDate: serializer.fromJson<DateTime>(json['snapshotDate']),
      amountUsd: serializer.fromJson<double>(json['amountUsd']),
      amountCny: serializer.fromJson<double>(json['amountCny']),
      amountHkd: serializer.fromJson<double>(json['amountHkd']),
      amountSgd: serializer.fromJson<double>(json['amountSgd']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountId': serializer.toJson<int>(accountId),
      'balance': serializer.toJson<double>(balance),
      'change': serializer.toJson<double>(change),
      'snapshotDate': serializer.toJson<DateTime>(snapshotDate),
      'amountUsd': serializer.toJson<double>(amountUsd),
      'amountCny': serializer.toJson<double>(amountCny),
      'amountHkd': serializer.toJson<double>(amountHkd),
      'amountSgd': serializer.toJson<double>(amountSgd),
    };
  }

  DbBalanceSnapshot copyWith(
          {int? id,
          int? accountId,
          double? balance,
          double? change,
          DateTime? snapshotDate,
          double? amountUsd,
          double? amountCny,
          double? amountHkd,
          double? amountSgd}) =>
      DbBalanceSnapshot(
        id: id ?? this.id,
        accountId: accountId ?? this.accountId,
        balance: balance ?? this.balance,
        change: change ?? this.change,
        snapshotDate: snapshotDate ?? this.snapshotDate,
        amountUsd: amountUsd ?? this.amountUsd,
        amountCny: amountCny ?? this.amountCny,
        amountHkd: amountHkd ?? this.amountHkd,
        amountSgd: amountSgd ?? this.amountSgd,
      );
  DbBalanceSnapshot copyWithCompanion(BalanceSnapshotsCompanion data) {
    return DbBalanceSnapshot(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      balance: data.balance.present ? data.balance.value : this.balance,
      change: data.change.present ? data.change.value : this.change,
      snapshotDate: data.snapshotDate.present
          ? data.snapshotDate.value
          : this.snapshotDate,
      amountUsd: data.amountUsd.present ? data.amountUsd.value : this.amountUsd,
      amountCny: data.amountCny.present ? data.amountCny.value : this.amountCny,
      amountHkd: data.amountHkd.present ? data.amountHkd.value : this.amountHkd,
      amountSgd: data.amountSgd.present ? data.amountSgd.value : this.amountSgd,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbBalanceSnapshot(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('balance: $balance, ')
          ..write('change: $change, ')
          ..write('snapshotDate: $snapshotDate, ')
          ..write('amountUsd: $amountUsd, ')
          ..write('amountCny: $amountCny, ')
          ..write('amountHkd: $amountHkd, ')
          ..write('amountSgd: $amountSgd')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, accountId, balance, change, snapshotDate,
      amountUsd, amountCny, amountHkd, amountSgd);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbBalanceSnapshot &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.balance == this.balance &&
          other.change == this.change &&
          other.snapshotDate == this.snapshotDate &&
          other.amountUsd == this.amountUsd &&
          other.amountCny == this.amountCny &&
          other.amountHkd == this.amountHkd &&
          other.amountSgd == this.amountSgd);
}

class BalanceSnapshotsCompanion extends UpdateCompanion<DbBalanceSnapshot> {
  final Value<int> id;
  final Value<int> accountId;
  final Value<double> balance;
  final Value<double> change;
  final Value<DateTime> snapshotDate;
  final Value<double> amountUsd;
  final Value<double> amountCny;
  final Value<double> amountHkd;
  final Value<double> amountSgd;
  const BalanceSnapshotsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.balance = const Value.absent(),
    this.change = const Value.absent(),
    this.snapshotDate = const Value.absent(),
    this.amountUsd = const Value.absent(),
    this.amountCny = const Value.absent(),
    this.amountHkd = const Value.absent(),
    this.amountSgd = const Value.absent(),
  });
  BalanceSnapshotsCompanion.insert({
    this.id = const Value.absent(),
    required int accountId,
    required double balance,
    this.change = const Value.absent(),
    required DateTime snapshotDate,
    this.amountUsd = const Value.absent(),
    this.amountCny = const Value.absent(),
    this.amountHkd = const Value.absent(),
    this.amountSgd = const Value.absent(),
  })  : accountId = Value(accountId),
        balance = Value(balance),
        snapshotDate = Value(snapshotDate);
  static Insertable<DbBalanceSnapshot> custom({
    Expression<int>? id,
    Expression<int>? accountId,
    Expression<double>? balance,
    Expression<double>? change,
    Expression<DateTime>? snapshotDate,
    Expression<double>? amountUsd,
    Expression<double>? amountCny,
    Expression<double>? amountHkd,
    Expression<double>? amountSgd,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (balance != null) 'balance': balance,
      if (change != null) 'change': change,
      if (snapshotDate != null) 'snapshot_date': snapshotDate,
      if (amountUsd != null) 'amount_usd': amountUsd,
      if (amountCny != null) 'amount_cny': amountCny,
      if (amountHkd != null) 'amount_hkd': amountHkd,
      if (amountSgd != null) 'amount_sgd': amountSgd,
    });
  }

  BalanceSnapshotsCompanion copyWith(
      {Value<int>? id,
      Value<int>? accountId,
      Value<double>? balance,
      Value<double>? change,
      Value<DateTime>? snapshotDate,
      Value<double>? amountUsd,
      Value<double>? amountCny,
      Value<double>? amountHkd,
      Value<double>? amountSgd}) {
    return BalanceSnapshotsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      balance: balance ?? this.balance,
      change: change ?? this.change,
      snapshotDate: snapshotDate ?? this.snapshotDate,
      amountUsd: amountUsd ?? this.amountUsd,
      amountCny: amountCny ?? this.amountCny,
      amountHkd: amountHkd ?? this.amountHkd,
      amountSgd: amountSgd ?? this.amountSgd,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (balance.present) {
      map['balance'] = Variable<double>(balance.value);
    }
    if (change.present) {
      map['change'] = Variable<double>(change.value);
    }
    if (snapshotDate.present) {
      map['snapshot_date'] = Variable<DateTime>(snapshotDate.value);
    }
    if (amountUsd.present) {
      map['amount_usd'] = Variable<double>(amountUsd.value);
    }
    if (amountCny.present) {
      map['amount_cny'] = Variable<double>(amountCny.value);
    }
    if (amountHkd.present) {
      map['amount_hkd'] = Variable<double>(amountHkd.value);
    }
    if (amountSgd.present) {
      map['amount_sgd'] = Variable<double>(amountSgd.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BalanceSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('balance: $balance, ')
          ..write('change: $change, ')
          ..write('snapshotDate: $snapshotDate, ')
          ..write('amountUsd: $amountUsd, ')
          ..write('amountCny: $amountCny, ')
          ..write('amountHkd: $amountHkd, ')
          ..write('amountSgd: $amountSgd')
          ..write(')'))
        .toString();
  }
}

class $ExchangeRatesTable extends ExchangeRates
    with TableInfo<$ExchangeRatesTable, DbExchangeRate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExchangeRatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _rateDateMeta =
      const VerificationMeta('rateDate');
  @override
  late final GeneratedColumn<DateTime> rateDate = GeneratedColumn<DateTime>(
      'rate_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _cnyMeta = const VerificationMeta('cny');
  @override
  late final GeneratedColumn<double> cny = GeneratedColumn<double>(
      'cny', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _hkdMeta = const VerificationMeta('hkd');
  @override
  late final GeneratedColumn<double> hkd = GeneratedColumn<double>(
      'hkd', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _sgdMeta = const VerificationMeta('sgd');
  @override
  late final GeneratedColumn<double> sgd = GeneratedColumn<double>(
      'sgd', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _jpyMeta = const VerificationMeta('jpy');
  @override
  late final GeneratedColumn<double> jpy = GeneratedColumn<double>(
      'jpy', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, rateDate, cny, hkd, sgd, jpy];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exchange_rates';
  @override
  VerificationContext validateIntegrity(Insertable<DbExchangeRate> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('rate_date')) {
      context.handle(_rateDateMeta,
          rateDate.isAcceptableOrUnknown(data['rate_date']!, _rateDateMeta));
    } else if (isInserting) {
      context.missing(_rateDateMeta);
    }
    if (data.containsKey('cny')) {
      context.handle(
          _cnyMeta, cny.isAcceptableOrUnknown(data['cny']!, _cnyMeta));
    } else if (isInserting) {
      context.missing(_cnyMeta);
    }
    if (data.containsKey('hkd')) {
      context.handle(
          _hkdMeta, hkd.isAcceptableOrUnknown(data['hkd']!, _hkdMeta));
    } else if (isInserting) {
      context.missing(_hkdMeta);
    }
    if (data.containsKey('sgd')) {
      context.handle(
          _sgdMeta, sgd.isAcceptableOrUnknown(data['sgd']!, _sgdMeta));
    } else if (isInserting) {
      context.missing(_sgdMeta);
    }
    if (data.containsKey('jpy')) {
      context.handle(
          _jpyMeta, jpy.isAcceptableOrUnknown(data['jpy']!, _jpyMeta));
    } else if (isInserting) {
      context.missing(_jpyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbExchangeRate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbExchangeRate(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      rateDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}rate_date'])!,
      cny: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}cny'])!,
      hkd: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}hkd'])!,
      sgd: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}sgd'])!,
      jpy: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}jpy'])!,
    );
  }

  @override
  $ExchangeRatesTable createAlias(String alias) {
    return $ExchangeRatesTable(attachedDatabase, alias);
  }
}

class DbExchangeRate extends DataClass implements Insertable<DbExchangeRate> {
  final int id;
  final DateTime rateDate;
  final double cny;
  final double hkd;
  final double sgd;
  final double jpy;
  const DbExchangeRate(
      {required this.id,
      required this.rateDate,
      required this.cny,
      required this.hkd,
      required this.sgd,
      required this.jpy});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['rate_date'] = Variable<DateTime>(rateDate);
    map['cny'] = Variable<double>(cny);
    map['hkd'] = Variable<double>(hkd);
    map['sgd'] = Variable<double>(sgd);
    map['jpy'] = Variable<double>(jpy);
    return map;
  }

  ExchangeRatesCompanion toCompanion(bool nullToAbsent) {
    return ExchangeRatesCompanion(
      id: Value(id),
      rateDate: Value(rateDate),
      cny: Value(cny),
      hkd: Value(hkd),
      sgd: Value(sgd),
      jpy: Value(jpy),
    );
  }

  factory DbExchangeRate.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbExchangeRate(
      id: serializer.fromJson<int>(json['id']),
      rateDate: serializer.fromJson<DateTime>(json['rateDate']),
      cny: serializer.fromJson<double>(json['cny']),
      hkd: serializer.fromJson<double>(json['hkd']),
      sgd: serializer.fromJson<double>(json['sgd']),
      jpy: serializer.fromJson<double>(json['jpy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'rateDate': serializer.toJson<DateTime>(rateDate),
      'cny': serializer.toJson<double>(cny),
      'hkd': serializer.toJson<double>(hkd),
      'sgd': serializer.toJson<double>(sgd),
      'jpy': serializer.toJson<double>(jpy),
    };
  }

  DbExchangeRate copyWith(
          {int? id,
          DateTime? rateDate,
          double? cny,
          double? hkd,
          double? sgd,
          double? jpy}) =>
      DbExchangeRate(
        id: id ?? this.id,
        rateDate: rateDate ?? this.rateDate,
        cny: cny ?? this.cny,
        hkd: hkd ?? this.hkd,
        sgd: sgd ?? this.sgd,
        jpy: jpy ?? this.jpy,
      );
  DbExchangeRate copyWithCompanion(ExchangeRatesCompanion data) {
    return DbExchangeRate(
      id: data.id.present ? data.id.value : this.id,
      rateDate: data.rateDate.present ? data.rateDate.value : this.rateDate,
      cny: data.cny.present ? data.cny.value : this.cny,
      hkd: data.hkd.present ? data.hkd.value : this.hkd,
      sgd: data.sgd.present ? data.sgd.value : this.sgd,
      jpy: data.jpy.present ? data.jpy.value : this.jpy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbExchangeRate(')
          ..write('id: $id, ')
          ..write('rateDate: $rateDate, ')
          ..write('cny: $cny, ')
          ..write('hkd: $hkd, ')
          ..write('sgd: $sgd, ')
          ..write('jpy: $jpy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, rateDate, cny, hkd, sgd, jpy);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbExchangeRate &&
          other.id == this.id &&
          other.rateDate == this.rateDate &&
          other.cny == this.cny &&
          other.hkd == this.hkd &&
          other.sgd == this.sgd &&
          other.jpy == this.jpy);
}

class ExchangeRatesCompanion extends UpdateCompanion<DbExchangeRate> {
  final Value<int> id;
  final Value<DateTime> rateDate;
  final Value<double> cny;
  final Value<double> hkd;
  final Value<double> sgd;
  final Value<double> jpy;
  const ExchangeRatesCompanion({
    this.id = const Value.absent(),
    this.rateDate = const Value.absent(),
    this.cny = const Value.absent(),
    this.hkd = const Value.absent(),
    this.sgd = const Value.absent(),
    this.jpy = const Value.absent(),
  });
  ExchangeRatesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime rateDate,
    required double cny,
    required double hkd,
    required double sgd,
    required double jpy,
  })  : rateDate = Value(rateDate),
        cny = Value(cny),
        hkd = Value(hkd),
        sgd = Value(sgd),
        jpy = Value(jpy);
  static Insertable<DbExchangeRate> custom({
    Expression<int>? id,
    Expression<DateTime>? rateDate,
    Expression<double>? cny,
    Expression<double>? hkd,
    Expression<double>? sgd,
    Expression<double>? jpy,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rateDate != null) 'rate_date': rateDate,
      if (cny != null) 'cny': cny,
      if (hkd != null) 'hkd': hkd,
      if (sgd != null) 'sgd': sgd,
      if (jpy != null) 'jpy': jpy,
    });
  }

  ExchangeRatesCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? rateDate,
      Value<double>? cny,
      Value<double>? hkd,
      Value<double>? sgd,
      Value<double>? jpy}) {
    return ExchangeRatesCompanion(
      id: id ?? this.id,
      rateDate: rateDate ?? this.rateDate,
      cny: cny ?? this.cny,
      hkd: hkd ?? this.hkd,
      sgd: sgd ?? this.sgd,
      jpy: jpy ?? this.jpy,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (rateDate.present) {
      map['rate_date'] = Variable<DateTime>(rateDate.value);
    }
    if (cny.present) {
      map['cny'] = Variable<double>(cny.value);
    }
    if (hkd.present) {
      map['hkd'] = Variable<double>(hkd.value);
    }
    if (sgd.present) {
      map['sgd'] = Variable<double>(sgd.value);
    }
    if (jpy.present) {
      map['jpy'] = Variable<double>(jpy.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExchangeRatesCompanion(')
          ..write('id: $id, ')
          ..write('rateDate: $rateDate, ')
          ..write('cny: $cny, ')
          ..write('hkd: $hkd, ')
          ..write('sgd: $sgd, ')
          ..write('jpy: $jpy')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, DbSyncOperation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationMeta =
      const VerificationMeta('operation');
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
      'operation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _localIdMeta =
      const VerificationMeta('localId');
  @override
  late final GeneratedColumn<int> localId = GeneratedColumn<int>(
      'local_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _retryCountMeta =
      const VerificationMeta('retryCount');
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, entityType, operation, localId, payload, createdAt, retryCount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(Insertable<DbSyncOperation> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(_operationMeta,
          operation.isAcceptableOrUnknown(data['operation']!, _operationMeta));
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('local_id')) {
      context.handle(_localIdMeta,
          localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta));
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('retry_count')) {
      context.handle(
          _retryCountMeta,
          retryCount.isAcceptableOrUnknown(
              data['retry_count']!, _retryCountMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbSyncOperation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbSyncOperation(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type'])!,
      operation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation'])!,
      localId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}local_id'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      retryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retry_count'])!,
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class DbSyncOperation extends DataClass implements Insertable<DbSyncOperation> {
  final int id;
  final String entityType;
  final String operation;
  final int localId;
  final String payload;
  final DateTime? createdAt;
  final int retryCount;
  const DbSyncOperation(
      {required this.id,
      required this.entityType,
      required this.operation,
      required this.localId,
      required this.payload,
      this.createdAt,
      required this.retryCount});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['operation'] = Variable<String>(operation);
    map['local_id'] = Variable<int>(localId);
    map['payload'] = Variable<String>(payload);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['retry_count'] = Variable<int>(retryCount);
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      id: Value(id),
      entityType: Value(entityType),
      operation: Value(operation),
      localId: Value(localId),
      payload: Value(payload),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      retryCount: Value(retryCount),
    );
  }

  factory DbSyncOperation.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbSyncOperation(
      id: serializer.fromJson<int>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      operation: serializer.fromJson<String>(json['operation']),
      localId: serializer.fromJson<int>(json['localId']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityType': serializer.toJson<String>(entityType),
      'operation': serializer.toJson<String>(operation),
      'localId': serializer.toJson<int>(localId),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'retryCount': serializer.toJson<int>(retryCount),
    };
  }

  DbSyncOperation copyWith(
          {int? id,
          String? entityType,
          String? operation,
          int? localId,
          String? payload,
          Value<DateTime?> createdAt = const Value.absent(),
          int? retryCount}) =>
      DbSyncOperation(
        id: id ?? this.id,
        entityType: entityType ?? this.entityType,
        operation: operation ?? this.operation,
        localId: localId ?? this.localId,
        payload: payload ?? this.payload,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        retryCount: retryCount ?? this.retryCount,
      );
  DbSyncOperation copyWithCompanion(SyncQueueCompanion data) {
    return DbSyncOperation(
      id: data.id.present ? data.id.value : this.id,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      operation: data.operation.present ? data.operation.value : this.operation,
      localId: data.localId.present ? data.localId.value : this.localId,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      retryCount:
          data.retryCount.present ? data.retryCount.value : this.retryCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbSyncOperation(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('operation: $operation, ')
          ..write('localId: $localId, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, entityType, operation, localId, payload, createdAt, retryCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbSyncOperation &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.operation == this.operation &&
          other.localId == this.localId &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.retryCount == this.retryCount);
}

class SyncQueueCompanion extends UpdateCompanion<DbSyncOperation> {
  final Value<int> id;
  final Value<String> entityType;
  final Value<String> operation;
  final Value<int> localId;
  final Value<String> payload;
  final Value<DateTime?> createdAt;
  final Value<int> retryCount;
  const SyncQueueCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.operation = const Value.absent(),
    this.localId = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.retryCount = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    this.id = const Value.absent(),
    required String entityType,
    required String operation,
    required int localId,
    required String payload,
    this.createdAt = const Value.absent(),
    this.retryCount = const Value.absent(),
  })  : entityType = Value(entityType),
        operation = Value(operation),
        localId = Value(localId),
        payload = Value(payload);
  static Insertable<DbSyncOperation> custom({
    Expression<int>? id,
    Expression<String>? entityType,
    Expression<String>? operation,
    Expression<int>? localId,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<int>? retryCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (operation != null) 'operation': operation,
      if (localId != null) 'local_id': localId,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (retryCount != null) 'retry_count': retryCount,
    });
  }

  SyncQueueCompanion copyWith(
      {Value<int>? id,
      Value<String>? entityType,
      Value<String>? operation,
      Value<int>? localId,
      Value<String>? payload,
      Value<DateTime?>? createdAt,
      Value<int>? retryCount}) {
    return SyncQueueCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      operation: operation ?? this.operation,
      localId: localId ?? this.localId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (localId.present) {
      map['local_id'] = Variable<int>(localId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('operation: $operation, ')
          ..write('localId: $localId, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ExpensesTable expenses = $ExpensesTable(this);
  late final $TripsTable trips = $TripsTable(this);
  late final $TravelExpensesTable travelExpenses = $TravelExpensesTable(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $BalanceSnapshotsTable balanceSnapshots =
      $BalanceSnapshotsTable(this);
  late final $ExchangeRatesTable exchangeRates = $ExchangeRatesTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final SyncQueueDao syncQueueDao = SyncQueueDao(this as AppDatabase);
  late final ExpenseDao expenseDao = ExpenseDao(this as AppDatabase);
  late final TripDao tripDao = TripDao(this as AppDatabase);
  late final AccountDao accountDao = AccountDao(this as AppDatabase);
  late final ExchangeRateDao exchangeRateDao =
      ExchangeRateDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        expenses,
        trips,
        travelExpenses,
        accounts,
        balanceSnapshots,
        exchangeRates,
        syncQueue
      ];
}

typedef $$ExpensesTableCreateCompanionBuilder = ExpensesCompanion Function({
  Value<int> id,
  Value<int?> remoteId,
  required double amount,
  required String currency,
  required DateTime date,
  required String category,
  required String name,
  Value<String> notes,
  Value<double> amountUsd,
  Value<double> amountCny,
  Value<double> amountHkd,
  Value<double> amountSgd,
  Value<DateTime?> createdAt,
  Value<bool> synced,
});
typedef $$ExpensesTableUpdateCompanionBuilder = ExpensesCompanion Function({
  Value<int> id,
  Value<int?> remoteId,
  Value<double> amount,
  Value<String> currency,
  Value<DateTime> date,
  Value<String> category,
  Value<String> name,
  Value<String> notes,
  Value<double> amountUsd,
  Value<double> amountCny,
  Value<double> amountHkd,
  Value<double> amountSgd,
  Value<DateTime?> createdAt,
  Value<bool> synced,
});

class $$ExpensesTableFilterComposer
    extends Composer<_$AppDatabase, $ExpensesTable> {
  $$ExpensesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amountUsd => $composableBuilder(
      column: $table.amountUsd, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amountCny => $composableBuilder(
      column: $table.amountCny, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amountHkd => $composableBuilder(
      column: $table.amountHkd, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amountSgd => $composableBuilder(
      column: $table.amountSgd, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnFilters(column));
}

class $$ExpensesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExpensesTable> {
  $$ExpensesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amountUsd => $composableBuilder(
      column: $table.amountUsd, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amountCny => $composableBuilder(
      column: $table.amountCny, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amountHkd => $composableBuilder(
      column: $table.amountHkd, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amountSgd => $composableBuilder(
      column: $table.amountSgd, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnOrderings(column));
}

class $$ExpensesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExpensesTable> {
  $$ExpensesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<double> get amountUsd =>
      $composableBuilder(column: $table.amountUsd, builder: (column) => column);

  GeneratedColumn<double> get amountCny =>
      $composableBuilder(column: $table.amountCny, builder: (column) => column);

  GeneratedColumn<double> get amountHkd =>
      $composableBuilder(column: $table.amountHkd, builder: (column) => column);

  GeneratedColumn<double> get amountSgd =>
      $composableBuilder(column: $table.amountSgd, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$ExpensesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ExpensesTable,
    DbExpense,
    $$ExpensesTableFilterComposer,
    $$ExpensesTableOrderingComposer,
    $$ExpensesTableAnnotationComposer,
    $$ExpensesTableCreateCompanionBuilder,
    $$ExpensesTableUpdateCompanionBuilder,
    (DbExpense, BaseReferences<_$AppDatabase, $ExpensesTable, DbExpense>),
    DbExpense,
    PrefetchHooks Function()> {
  $$ExpensesTableTableManager(_$AppDatabase db, $ExpensesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExpensesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExpensesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExpensesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> remoteId = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<DateTime> date = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<double> amountUsd = const Value.absent(),
            Value<double> amountCny = const Value.absent(),
            Value<double> amountHkd = const Value.absent(),
            Value<double> amountSgd = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<bool> synced = const Value.absent(),
          }) =>
              ExpensesCompanion(
            id: id,
            remoteId: remoteId,
            amount: amount,
            currency: currency,
            date: date,
            category: category,
            name: name,
            notes: notes,
            amountUsd: amountUsd,
            amountCny: amountCny,
            amountHkd: amountHkd,
            amountSgd: amountSgd,
            createdAt: createdAt,
            synced: synced,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> remoteId = const Value.absent(),
            required double amount,
            required String currency,
            required DateTime date,
            required String category,
            required String name,
            Value<String> notes = const Value.absent(),
            Value<double> amountUsd = const Value.absent(),
            Value<double> amountCny = const Value.absent(),
            Value<double> amountHkd = const Value.absent(),
            Value<double> amountSgd = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<bool> synced = const Value.absent(),
          }) =>
              ExpensesCompanion.insert(
            id: id,
            remoteId: remoteId,
            amount: amount,
            currency: currency,
            date: date,
            category: category,
            name: name,
            notes: notes,
            amountUsd: amountUsd,
            amountCny: amountCny,
            amountHkd: amountHkd,
            amountSgd: amountSgd,
            createdAt: createdAt,
            synced: synced,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ExpensesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ExpensesTable,
    DbExpense,
    $$ExpensesTableFilterComposer,
    $$ExpensesTableOrderingComposer,
    $$ExpensesTableAnnotationComposer,
    $$ExpensesTableCreateCompanionBuilder,
    $$ExpensesTableUpdateCompanionBuilder,
    (DbExpense, BaseReferences<_$AppDatabase, $ExpensesTable, DbExpense>),
    DbExpense,
    PrefetchHooks Function()>;
typedef $$TripsTableCreateCompanionBuilder = TripsCompanion Function({
  Value<int> id,
  Value<int?> remoteId,
  required String destination,
  required DateTime startDate,
  required DateTime endDate,
  Value<String> notes,
  Value<DateTime?> createdAt,
  Value<bool> synced,
});
typedef $$TripsTableUpdateCompanionBuilder = TripsCompanion Function({
  Value<int> id,
  Value<int?> remoteId,
  Value<String> destination,
  Value<DateTime> startDate,
  Value<DateTime> endDate,
  Value<String> notes,
  Value<DateTime?> createdAt,
  Value<bool> synced,
});

final class $$TripsTableReferences
    extends BaseReferences<_$AppDatabase, $TripsTable, DbTrip> {
  $$TripsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TravelExpensesTable, List<DbTravelExpense>>
      _travelExpensesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.travelExpenses,
              aliasName:
                  $_aliasNameGenerator(db.trips.id, db.travelExpenses.tripId));

  $$TravelExpensesTableProcessedTableManager get travelExpensesRefs {
    final manager = $$TravelExpensesTableTableManager($_db, $_db.travelExpenses)
        .filter((f) => f.tripId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_travelExpensesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$TripsTableFilterComposer extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get destination => $composableBuilder(
      column: $table.destination, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endDate => $composableBuilder(
      column: $table.endDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnFilters(column));

  Expression<bool> travelExpensesRefs(
      Expression<bool> Function($$TravelExpensesTableFilterComposer f) f) {
    final $$TravelExpensesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.travelExpenses,
        getReferencedColumn: (t) => t.tripId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TravelExpensesTableFilterComposer(
              $db: $db,
              $table: $db.travelExpenses,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$TripsTableOrderingComposer
    extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get destination => $composableBuilder(
      column: $table.destination, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
      column: $table.endDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnOrderings(column));
}

class $$TripsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get destination => $composableBuilder(
      column: $table.destination, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  Expression<T> travelExpensesRefs<T extends Object>(
      Expression<T> Function($$TravelExpensesTableAnnotationComposer a) f) {
    final $$TravelExpensesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.travelExpenses,
        getReferencedColumn: (t) => t.tripId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TravelExpensesTableAnnotationComposer(
              $db: $db,
              $table: $db.travelExpenses,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$TripsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TripsTable,
    DbTrip,
    $$TripsTableFilterComposer,
    $$TripsTableOrderingComposer,
    $$TripsTableAnnotationComposer,
    $$TripsTableCreateCompanionBuilder,
    $$TripsTableUpdateCompanionBuilder,
    (DbTrip, $$TripsTableReferences),
    DbTrip,
    PrefetchHooks Function({bool travelExpensesRefs})> {
  $$TripsTableTableManager(_$AppDatabase db, $TripsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> remoteId = const Value.absent(),
            Value<String> destination = const Value.absent(),
            Value<DateTime> startDate = const Value.absent(),
            Value<DateTime> endDate = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<bool> synced = const Value.absent(),
          }) =>
              TripsCompanion(
            id: id,
            remoteId: remoteId,
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            notes: notes,
            createdAt: createdAt,
            synced: synced,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> remoteId = const Value.absent(),
            required String destination,
            required DateTime startDate,
            required DateTime endDate,
            Value<String> notes = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<bool> synced = const Value.absent(),
          }) =>
              TripsCompanion.insert(
            id: id,
            remoteId: remoteId,
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            notes: notes,
            createdAt: createdAt,
            synced: synced,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$TripsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({travelExpensesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (travelExpensesRefs) db.travelExpenses
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (travelExpensesRefs)
                    await $_getPrefetchedData<DbTrip, $TripsTable,
                            DbTravelExpense>(
                        currentTable: table,
                        referencedTable:
                            $$TripsTableReferences._travelExpensesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TripsTableReferences(db, table, p0)
                                .travelExpensesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.tripId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$TripsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TripsTable,
    DbTrip,
    $$TripsTableFilterComposer,
    $$TripsTableOrderingComposer,
    $$TripsTableAnnotationComposer,
    $$TripsTableCreateCompanionBuilder,
    $$TripsTableUpdateCompanionBuilder,
    (DbTrip, $$TripsTableReferences),
    DbTrip,
    PrefetchHooks Function({bool travelExpensesRefs})>;
typedef $$TravelExpensesTableCreateCompanionBuilder = TravelExpensesCompanion
    Function({
  Value<int> id,
  Value<int?> remoteId,
  required int tripId,
  Value<int?> tripRemoteId,
  required double amount,
  required String currency,
  required DateTime date,
  required String category,
  required String name,
  Value<String> notes,
  Value<double> amountUsd,
  Value<double> amountCny,
  Value<double> amountHkd,
  Value<double> amountSgd,
  Value<DateTime?> createdAt,
  Value<bool> synced,
});
typedef $$TravelExpensesTableUpdateCompanionBuilder = TravelExpensesCompanion
    Function({
  Value<int> id,
  Value<int?> remoteId,
  Value<int> tripId,
  Value<int?> tripRemoteId,
  Value<double> amount,
  Value<String> currency,
  Value<DateTime> date,
  Value<String> category,
  Value<String> name,
  Value<String> notes,
  Value<double> amountUsd,
  Value<double> amountCny,
  Value<double> amountHkd,
  Value<double> amountSgd,
  Value<DateTime?> createdAt,
  Value<bool> synced,
});

final class $$TravelExpensesTableReferences extends BaseReferences<
    _$AppDatabase, $TravelExpensesTable, DbTravelExpense> {
  $$TravelExpensesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $TripsTable _tripIdTable(_$AppDatabase db) => db.trips
      .createAlias($_aliasNameGenerator(db.travelExpenses.tripId, db.trips.id));

  $$TripsTableProcessedTableManager get tripId {
    final $_column = $_itemColumn<int>('trip_id')!;

    final manager = $$TripsTableTableManager($_db, $_db.trips)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$TravelExpensesTableFilterComposer
    extends Composer<_$AppDatabase, $TravelExpensesTable> {
  $$TravelExpensesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tripRemoteId => $composableBuilder(
      column: $table.tripRemoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amountUsd => $composableBuilder(
      column: $table.amountUsd, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amountCny => $composableBuilder(
      column: $table.amountCny, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amountHkd => $composableBuilder(
      column: $table.amountHkd, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amountSgd => $composableBuilder(
      column: $table.amountSgd, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnFilters(column));

  $$TripsTableFilterComposer get tripId {
    final $$TripsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tripId,
        referencedTable: $db.trips,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripsTableFilterComposer(
              $db: $db,
              $table: $db.trips,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TravelExpensesTableOrderingComposer
    extends Composer<_$AppDatabase, $TravelExpensesTable> {
  $$TravelExpensesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tripRemoteId => $composableBuilder(
      column: $table.tripRemoteId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amountUsd => $composableBuilder(
      column: $table.amountUsd, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amountCny => $composableBuilder(
      column: $table.amountCny, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amountHkd => $composableBuilder(
      column: $table.amountHkd, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amountSgd => $composableBuilder(
      column: $table.amountSgd, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnOrderings(column));

  $$TripsTableOrderingComposer get tripId {
    final $$TripsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tripId,
        referencedTable: $db.trips,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripsTableOrderingComposer(
              $db: $db,
              $table: $db.trips,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TravelExpensesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TravelExpensesTable> {
  $$TravelExpensesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<int> get tripRemoteId => $composableBuilder(
      column: $table.tripRemoteId, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<double> get amountUsd =>
      $composableBuilder(column: $table.amountUsd, builder: (column) => column);

  GeneratedColumn<double> get amountCny =>
      $composableBuilder(column: $table.amountCny, builder: (column) => column);

  GeneratedColumn<double> get amountHkd =>
      $composableBuilder(column: $table.amountHkd, builder: (column) => column);

  GeneratedColumn<double> get amountSgd =>
      $composableBuilder(column: $table.amountSgd, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  $$TripsTableAnnotationComposer get tripId {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tripId,
        referencedTable: $db.trips,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripsTableAnnotationComposer(
              $db: $db,
              $table: $db.trips,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TravelExpensesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TravelExpensesTable,
    DbTravelExpense,
    $$TravelExpensesTableFilterComposer,
    $$TravelExpensesTableOrderingComposer,
    $$TravelExpensesTableAnnotationComposer,
    $$TravelExpensesTableCreateCompanionBuilder,
    $$TravelExpensesTableUpdateCompanionBuilder,
    (DbTravelExpense, $$TravelExpensesTableReferences),
    DbTravelExpense,
    PrefetchHooks Function({bool tripId})> {
  $$TravelExpensesTableTableManager(
      _$AppDatabase db, $TravelExpensesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TravelExpensesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TravelExpensesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TravelExpensesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> remoteId = const Value.absent(),
            Value<int> tripId = const Value.absent(),
            Value<int?> tripRemoteId = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<DateTime> date = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<double> amountUsd = const Value.absent(),
            Value<double> amountCny = const Value.absent(),
            Value<double> amountHkd = const Value.absent(),
            Value<double> amountSgd = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<bool> synced = const Value.absent(),
          }) =>
              TravelExpensesCompanion(
            id: id,
            remoteId: remoteId,
            tripId: tripId,
            tripRemoteId: tripRemoteId,
            amount: amount,
            currency: currency,
            date: date,
            category: category,
            name: name,
            notes: notes,
            amountUsd: amountUsd,
            amountCny: amountCny,
            amountHkd: amountHkd,
            amountSgd: amountSgd,
            createdAt: createdAt,
            synced: synced,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> remoteId = const Value.absent(),
            required int tripId,
            Value<int?> tripRemoteId = const Value.absent(),
            required double amount,
            required String currency,
            required DateTime date,
            required String category,
            required String name,
            Value<String> notes = const Value.absent(),
            Value<double> amountUsd = const Value.absent(),
            Value<double> amountCny = const Value.absent(),
            Value<double> amountHkd = const Value.absent(),
            Value<double> amountSgd = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<bool> synced = const Value.absent(),
          }) =>
              TravelExpensesCompanion.insert(
            id: id,
            remoteId: remoteId,
            tripId: tripId,
            tripRemoteId: tripRemoteId,
            amount: amount,
            currency: currency,
            date: date,
            category: category,
            name: name,
            notes: notes,
            amountUsd: amountUsd,
            amountCny: amountCny,
            amountHkd: amountHkd,
            amountSgd: amountSgd,
            createdAt: createdAt,
            synced: synced,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$TravelExpensesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({tripId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (tripId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.tripId,
                    referencedTable:
                        $$TravelExpensesTableReferences._tripIdTable(db),
                    referencedColumn:
                        $$TravelExpensesTableReferences._tripIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$TravelExpensesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TravelExpensesTable,
    DbTravelExpense,
    $$TravelExpensesTableFilterComposer,
    $$TravelExpensesTableOrderingComposer,
    $$TravelExpensesTableAnnotationComposer,
    $$TravelExpensesTableCreateCompanionBuilder,
    $$TravelExpensesTableUpdateCompanionBuilder,
    (DbTravelExpense, $$TravelExpensesTableReferences),
    DbTravelExpense,
    PrefetchHooks Function({bool tripId})>;
typedef $$AccountsTableCreateCompanionBuilder = AccountsCompanion Function({
  Value<int> id,
  Value<int?> remoteId,
  required String name,
  required String currency,
  Value<double> balance,
  Value<bool> includeInTotal,
  Value<String> notes,
  Value<String?> apiUrl,
  Value<String?> apiValuePath,
  Value<String?> apiAuth,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<bool> synced,
});
typedef $$AccountsTableUpdateCompanionBuilder = AccountsCompanion Function({
  Value<int> id,
  Value<int?> remoteId,
  Value<String> name,
  Value<String> currency,
  Value<double> balance,
  Value<bool> includeInTotal,
  Value<String> notes,
  Value<String?> apiUrl,
  Value<String?> apiValuePath,
  Value<String?> apiAuth,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<bool> synced,
});

final class $$AccountsTableReferences
    extends BaseReferences<_$AppDatabase, $AccountsTable, DbAccount> {
  $$AccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BalanceSnapshotsTable, List<DbBalanceSnapshot>>
      _balanceSnapshotsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.balanceSnapshots,
              aliasName: $_aliasNameGenerator(
                  db.accounts.id, db.balanceSnapshots.accountId));

  $$BalanceSnapshotsTableProcessedTableManager get balanceSnapshotsRefs {
    final manager =
        $$BalanceSnapshotsTableTableManager($_db, $_db.balanceSnapshots)
            .filter((f) => f.accountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_balanceSnapshotsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get balance => $composableBuilder(
      column: $table.balance, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get includeInTotal => $composableBuilder(
      column: $table.includeInTotal,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get apiUrl => $composableBuilder(
      column: $table.apiUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get apiValuePath => $composableBuilder(
      column: $table.apiValuePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get apiAuth => $composableBuilder(
      column: $table.apiAuth, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnFilters(column));

  Expression<bool> balanceSnapshotsRefs(
      Expression<bool> Function($$BalanceSnapshotsTableFilterComposer f) f) {
    final $$BalanceSnapshotsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.balanceSnapshots,
        getReferencedColumn: (t) => t.accountId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BalanceSnapshotsTableFilterComposer(
              $db: $db,
              $table: $db.balanceSnapshots,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get balance => $composableBuilder(
      column: $table.balance, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get includeInTotal => $composableBuilder(
      column: $table.includeInTotal,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get apiUrl => $composableBuilder(
      column: $table.apiUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get apiValuePath => $composableBuilder(
      column: $table.apiValuePath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get apiAuth => $composableBuilder(
      column: $table.apiAuth, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnOrderings(column));
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<double> get balance =>
      $composableBuilder(column: $table.balance, builder: (column) => column);

  GeneratedColumn<bool> get includeInTotal => $composableBuilder(
      column: $table.includeInTotal, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get apiUrl =>
      $composableBuilder(column: $table.apiUrl, builder: (column) => column);

  GeneratedColumn<String> get apiValuePath => $composableBuilder(
      column: $table.apiValuePath, builder: (column) => column);

  GeneratedColumn<String> get apiAuth =>
      $composableBuilder(column: $table.apiAuth, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  Expression<T> balanceSnapshotsRefs<T extends Object>(
      Expression<T> Function($$BalanceSnapshotsTableAnnotationComposer a) f) {
    final $$BalanceSnapshotsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.balanceSnapshots,
        getReferencedColumn: (t) => t.accountId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BalanceSnapshotsTableAnnotationComposer(
              $db: $db,
              $table: $db.balanceSnapshots,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$AccountsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AccountsTable,
    DbAccount,
    $$AccountsTableFilterComposer,
    $$AccountsTableOrderingComposer,
    $$AccountsTableAnnotationComposer,
    $$AccountsTableCreateCompanionBuilder,
    $$AccountsTableUpdateCompanionBuilder,
    (DbAccount, $$AccountsTableReferences),
    DbAccount,
    PrefetchHooks Function({bool balanceSnapshotsRefs})> {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> remoteId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<double> balance = const Value.absent(),
            Value<bool> includeInTotal = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<String?> apiUrl = const Value.absent(),
            Value<String?> apiValuePath = const Value.absent(),
            Value<String?> apiAuth = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<bool> synced = const Value.absent(),
          }) =>
              AccountsCompanion(
            id: id,
            remoteId: remoteId,
            name: name,
            currency: currency,
            balance: balance,
            includeInTotal: includeInTotal,
            notes: notes,
            apiUrl: apiUrl,
            apiValuePath: apiValuePath,
            apiAuth: apiAuth,
            createdAt: createdAt,
            updatedAt: updatedAt,
            synced: synced,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> remoteId = const Value.absent(),
            required String name,
            required String currency,
            Value<double> balance = const Value.absent(),
            Value<bool> includeInTotal = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<String?> apiUrl = const Value.absent(),
            Value<String?> apiValuePath = const Value.absent(),
            Value<String?> apiAuth = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<bool> synced = const Value.absent(),
          }) =>
              AccountsCompanion.insert(
            id: id,
            remoteId: remoteId,
            name: name,
            currency: currency,
            balance: balance,
            includeInTotal: includeInTotal,
            notes: notes,
            apiUrl: apiUrl,
            apiValuePath: apiValuePath,
            apiAuth: apiAuth,
            createdAt: createdAt,
            updatedAt: updatedAt,
            synced: synced,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$AccountsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({balanceSnapshotsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (balanceSnapshotsRefs) db.balanceSnapshots
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (balanceSnapshotsRefs)
                    await $_getPrefetchedData<DbAccount, $AccountsTable,
                            DbBalanceSnapshot>(
                        currentTable: table,
                        referencedTable: $$AccountsTableReferences
                            ._balanceSnapshotsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$AccountsTableReferences(db, table, p0)
                                .balanceSnapshotsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.accountId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$AccountsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AccountsTable,
    DbAccount,
    $$AccountsTableFilterComposer,
    $$AccountsTableOrderingComposer,
    $$AccountsTableAnnotationComposer,
    $$AccountsTableCreateCompanionBuilder,
    $$AccountsTableUpdateCompanionBuilder,
    (DbAccount, $$AccountsTableReferences),
    DbAccount,
    PrefetchHooks Function({bool balanceSnapshotsRefs})>;
typedef $$BalanceSnapshotsTableCreateCompanionBuilder
    = BalanceSnapshotsCompanion Function({
  Value<int> id,
  required int accountId,
  required double balance,
  Value<double> change,
  required DateTime snapshotDate,
  Value<double> amountUsd,
  Value<double> amountCny,
  Value<double> amountHkd,
  Value<double> amountSgd,
});
typedef $$BalanceSnapshotsTableUpdateCompanionBuilder
    = BalanceSnapshotsCompanion Function({
  Value<int> id,
  Value<int> accountId,
  Value<double> balance,
  Value<double> change,
  Value<DateTime> snapshotDate,
  Value<double> amountUsd,
  Value<double> amountCny,
  Value<double> amountHkd,
  Value<double> amountSgd,
});

final class $$BalanceSnapshotsTableReferences extends BaseReferences<
    _$AppDatabase, $BalanceSnapshotsTable, DbBalanceSnapshot> {
  $$BalanceSnapshotsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias(
          $_aliasNameGenerator(db.balanceSnapshots.accountId, db.accounts.id));

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<int>('account_id')!;

    final manager = $$AccountsTableTableManager($_db, $_db.accounts)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$BalanceSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $BalanceSnapshotsTable> {
  $$BalanceSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get balance => $composableBuilder(
      column: $table.balance, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get change => $composableBuilder(
      column: $table.change, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get snapshotDate => $composableBuilder(
      column: $table.snapshotDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amountUsd => $composableBuilder(
      column: $table.amountUsd, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amountCny => $composableBuilder(
      column: $table.amountCny, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amountHkd => $composableBuilder(
      column: $table.amountHkd, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amountSgd => $composableBuilder(
      column: $table.amountSgd, builder: (column) => ColumnFilters(column));

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.accountId,
        referencedTable: $db.accounts,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AccountsTableFilterComposer(
              $db: $db,
              $table: $db.accounts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BalanceSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $BalanceSnapshotsTable> {
  $$BalanceSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get balance => $composableBuilder(
      column: $table.balance, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get change => $composableBuilder(
      column: $table.change, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get snapshotDate => $composableBuilder(
      column: $table.snapshotDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amountUsd => $composableBuilder(
      column: $table.amountUsd, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amountCny => $composableBuilder(
      column: $table.amountCny, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amountHkd => $composableBuilder(
      column: $table.amountHkd, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amountSgd => $composableBuilder(
      column: $table.amountSgd, builder: (column) => ColumnOrderings(column));

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.accountId,
        referencedTable: $db.accounts,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AccountsTableOrderingComposer(
              $db: $db,
              $table: $db.accounts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BalanceSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BalanceSnapshotsTable> {
  $$BalanceSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get balance =>
      $composableBuilder(column: $table.balance, builder: (column) => column);

  GeneratedColumn<double> get change =>
      $composableBuilder(column: $table.change, builder: (column) => column);

  GeneratedColumn<DateTime> get snapshotDate => $composableBuilder(
      column: $table.snapshotDate, builder: (column) => column);

  GeneratedColumn<double> get amountUsd =>
      $composableBuilder(column: $table.amountUsd, builder: (column) => column);

  GeneratedColumn<double> get amountCny =>
      $composableBuilder(column: $table.amountCny, builder: (column) => column);

  GeneratedColumn<double> get amountHkd =>
      $composableBuilder(column: $table.amountHkd, builder: (column) => column);

  GeneratedColumn<double> get amountSgd =>
      $composableBuilder(column: $table.amountSgd, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.accountId,
        referencedTable: $db.accounts,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AccountsTableAnnotationComposer(
              $db: $db,
              $table: $db.accounts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BalanceSnapshotsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BalanceSnapshotsTable,
    DbBalanceSnapshot,
    $$BalanceSnapshotsTableFilterComposer,
    $$BalanceSnapshotsTableOrderingComposer,
    $$BalanceSnapshotsTableAnnotationComposer,
    $$BalanceSnapshotsTableCreateCompanionBuilder,
    $$BalanceSnapshotsTableUpdateCompanionBuilder,
    (DbBalanceSnapshot, $$BalanceSnapshotsTableReferences),
    DbBalanceSnapshot,
    PrefetchHooks Function({bool accountId})> {
  $$BalanceSnapshotsTableTableManager(
      _$AppDatabase db, $BalanceSnapshotsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BalanceSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BalanceSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BalanceSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> accountId = const Value.absent(),
            Value<double> balance = const Value.absent(),
            Value<double> change = const Value.absent(),
            Value<DateTime> snapshotDate = const Value.absent(),
            Value<double> amountUsd = const Value.absent(),
            Value<double> amountCny = const Value.absent(),
            Value<double> amountHkd = const Value.absent(),
            Value<double> amountSgd = const Value.absent(),
          }) =>
              BalanceSnapshotsCompanion(
            id: id,
            accountId: accountId,
            balance: balance,
            change: change,
            snapshotDate: snapshotDate,
            amountUsd: amountUsd,
            amountCny: amountCny,
            amountHkd: amountHkd,
            amountSgd: amountSgd,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int accountId,
            required double balance,
            Value<double> change = const Value.absent(),
            required DateTime snapshotDate,
            Value<double> amountUsd = const Value.absent(),
            Value<double> amountCny = const Value.absent(),
            Value<double> amountHkd = const Value.absent(),
            Value<double> amountSgd = const Value.absent(),
          }) =>
              BalanceSnapshotsCompanion.insert(
            id: id,
            accountId: accountId,
            balance: balance,
            change: change,
            snapshotDate: snapshotDate,
            amountUsd: amountUsd,
            amountCny: amountCny,
            amountHkd: amountHkd,
            amountSgd: amountSgd,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$BalanceSnapshotsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({accountId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (accountId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.accountId,
                    referencedTable:
                        $$BalanceSnapshotsTableReferences._accountIdTable(db),
                    referencedColumn: $$BalanceSnapshotsTableReferences
                        ._accountIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$BalanceSnapshotsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BalanceSnapshotsTable,
    DbBalanceSnapshot,
    $$BalanceSnapshotsTableFilterComposer,
    $$BalanceSnapshotsTableOrderingComposer,
    $$BalanceSnapshotsTableAnnotationComposer,
    $$BalanceSnapshotsTableCreateCompanionBuilder,
    $$BalanceSnapshotsTableUpdateCompanionBuilder,
    (DbBalanceSnapshot, $$BalanceSnapshotsTableReferences),
    DbBalanceSnapshot,
    PrefetchHooks Function({bool accountId})>;
typedef $$ExchangeRatesTableCreateCompanionBuilder = ExchangeRatesCompanion
    Function({
  Value<int> id,
  required DateTime rateDate,
  required double cny,
  required double hkd,
  required double sgd,
  required double jpy,
});
typedef $$ExchangeRatesTableUpdateCompanionBuilder = ExchangeRatesCompanion
    Function({
  Value<int> id,
  Value<DateTime> rateDate,
  Value<double> cny,
  Value<double> hkd,
  Value<double> sgd,
  Value<double> jpy,
});

class $$ExchangeRatesTableFilterComposer
    extends Composer<_$AppDatabase, $ExchangeRatesTable> {
  $$ExchangeRatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get rateDate => $composableBuilder(
      column: $table.rateDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get cny => $composableBuilder(
      column: $table.cny, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get hkd => $composableBuilder(
      column: $table.hkd, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get sgd => $composableBuilder(
      column: $table.sgd, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get jpy => $composableBuilder(
      column: $table.jpy, builder: (column) => ColumnFilters(column));
}

class $$ExchangeRatesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExchangeRatesTable> {
  $$ExchangeRatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get rateDate => $composableBuilder(
      column: $table.rateDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get cny => $composableBuilder(
      column: $table.cny, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get hkd => $composableBuilder(
      column: $table.hkd, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get sgd => $composableBuilder(
      column: $table.sgd, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get jpy => $composableBuilder(
      column: $table.jpy, builder: (column) => ColumnOrderings(column));
}

class $$ExchangeRatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExchangeRatesTable> {
  $$ExchangeRatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get rateDate =>
      $composableBuilder(column: $table.rateDate, builder: (column) => column);

  GeneratedColumn<double> get cny =>
      $composableBuilder(column: $table.cny, builder: (column) => column);

  GeneratedColumn<double> get hkd =>
      $composableBuilder(column: $table.hkd, builder: (column) => column);

  GeneratedColumn<double> get sgd =>
      $composableBuilder(column: $table.sgd, builder: (column) => column);

  GeneratedColumn<double> get jpy =>
      $composableBuilder(column: $table.jpy, builder: (column) => column);
}

class $$ExchangeRatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ExchangeRatesTable,
    DbExchangeRate,
    $$ExchangeRatesTableFilterComposer,
    $$ExchangeRatesTableOrderingComposer,
    $$ExchangeRatesTableAnnotationComposer,
    $$ExchangeRatesTableCreateCompanionBuilder,
    $$ExchangeRatesTableUpdateCompanionBuilder,
    (
      DbExchangeRate,
      BaseReferences<_$AppDatabase, $ExchangeRatesTable, DbExchangeRate>
    ),
    DbExchangeRate,
    PrefetchHooks Function()> {
  $$ExchangeRatesTableTableManager(_$AppDatabase db, $ExchangeRatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExchangeRatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExchangeRatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExchangeRatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> rateDate = const Value.absent(),
            Value<double> cny = const Value.absent(),
            Value<double> hkd = const Value.absent(),
            Value<double> sgd = const Value.absent(),
            Value<double> jpy = const Value.absent(),
          }) =>
              ExchangeRatesCompanion(
            id: id,
            rateDate: rateDate,
            cny: cny,
            hkd: hkd,
            sgd: sgd,
            jpy: jpy,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime rateDate,
            required double cny,
            required double hkd,
            required double sgd,
            required double jpy,
          }) =>
              ExchangeRatesCompanion.insert(
            id: id,
            rateDate: rateDate,
            cny: cny,
            hkd: hkd,
            sgd: sgd,
            jpy: jpy,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ExchangeRatesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ExchangeRatesTable,
    DbExchangeRate,
    $$ExchangeRatesTableFilterComposer,
    $$ExchangeRatesTableOrderingComposer,
    $$ExchangeRatesTableAnnotationComposer,
    $$ExchangeRatesTableCreateCompanionBuilder,
    $$ExchangeRatesTableUpdateCompanionBuilder,
    (
      DbExchangeRate,
      BaseReferences<_$AppDatabase, $ExchangeRatesTable, DbExchangeRate>
    ),
    DbExchangeRate,
    PrefetchHooks Function()>;
typedef $$SyncQueueTableCreateCompanionBuilder = SyncQueueCompanion Function({
  Value<int> id,
  required String entityType,
  required String operation,
  required int localId,
  required String payload,
  Value<DateTime?> createdAt,
  Value<int> retryCount,
});
typedef $$SyncQueueTableUpdateCompanionBuilder = SyncQueueCompanion Function({
  Value<int> id,
  Value<String> entityType,
  Value<String> operation,
  Value<int> localId,
  Value<String> payload,
  Value<DateTime?> createdAt,
  Value<int> retryCount,
});

class $$SyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get localId => $composableBuilder(
      column: $table.localId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnFilters(column));
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get localId => $composableBuilder(
      column: $table.localId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnOrderings(column));
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<int> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => column);
}

class $$SyncQueueTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncQueueTable,
    DbSyncOperation,
    $$SyncQueueTableFilterComposer,
    $$SyncQueueTableOrderingComposer,
    $$SyncQueueTableAnnotationComposer,
    $$SyncQueueTableCreateCompanionBuilder,
    $$SyncQueueTableUpdateCompanionBuilder,
    (
      DbSyncOperation,
      BaseReferences<_$AppDatabase, $SyncQueueTable, DbSyncOperation>
    ),
    DbSyncOperation,
    PrefetchHooks Function()> {
  $$SyncQueueTableTableManager(_$AppDatabase db, $SyncQueueTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> entityType = const Value.absent(),
            Value<String> operation = const Value.absent(),
            Value<int> localId = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
          }) =>
              SyncQueueCompanion(
            id: id,
            entityType: entityType,
            operation: operation,
            localId: localId,
            payload: payload,
            createdAt: createdAt,
            retryCount: retryCount,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String entityType,
            required String operation,
            required int localId,
            required String payload,
            Value<DateTime?> createdAt = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
          }) =>
              SyncQueueCompanion.insert(
            id: id,
            entityType: entityType,
            operation: operation,
            localId: localId,
            payload: payload,
            createdAt: createdAt,
            retryCount: retryCount,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncQueueTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncQueueTable,
    DbSyncOperation,
    $$SyncQueueTableFilterComposer,
    $$SyncQueueTableOrderingComposer,
    $$SyncQueueTableAnnotationComposer,
    $$SyncQueueTableCreateCompanionBuilder,
    $$SyncQueueTableUpdateCompanionBuilder,
    (
      DbSyncOperation,
      BaseReferences<_$AppDatabase, $SyncQueueTable, DbSyncOperation>
    ),
    DbSyncOperation,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ExpensesTableTableManager get expenses =>
      $$ExpensesTableTableManager(_db, _db.expenses);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db, _db.trips);
  $$TravelExpensesTableTableManager get travelExpenses =>
      $$TravelExpensesTableTableManager(_db, _db.travelExpenses);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$BalanceSnapshotsTableTableManager get balanceSnapshots =>
      $$BalanceSnapshotsTableTableManager(_db, _db.balanceSnapshots);
  $$ExchangeRatesTableTableManager get exchangeRates =>
      $$ExchangeRatesTableTableManager(_db, _db.exchangeRates);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
}
