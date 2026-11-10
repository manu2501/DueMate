import 'package:drift/drift.dart';

enum TransactionType {
  moneyGiven,
  paymentReceived,
}

enum PaymentMethod {
  upi,
  cash,
  bankTransfer,
  card,
  other,
}

class Persons extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get avatarPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get personId => text().references(Persons, #id, onDelete: KeyAction.cascade)();
  IntColumn get type => intEnum<TransactionType>()();
  RealColumn get amount => real()();
  DateTimeColumn get transactionDate => dateTime()();
  IntColumn get paymentMethod => intEnum<PaymentMethod>()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

