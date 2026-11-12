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

enum ExpenseCategory {
  groceries,
  utilities,
  rent,
  fuel,
  food,
  shopping,
  entertainment,
  health,
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
  TextColumn get emiId => text().nullable()();
  IntColumn get installmentNumber => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class CreditCardEmis extends Table {
  TextColumn get id => text()();
  TextColumn get personId => text().references(Persons, #id, onDelete: KeyAction.cascade)();
  TextColumn get itemName => text().withLength(min: 1, max: 150)();
  TextColumn get cardName => text().withLength(min: 1, max: 100)();
  RealColumn get totalAmount => real()();
  RealColumn get monthlyInstallment => real()();
  IntColumn get totalTenureMonths => integer()();
  IntColumn get installmentsPaid => integer().withDefault(const Constant(0))();
  DateTimeColumn get startDate => dateTime()();
  IntColumn get dueDayOfMonth => integer()();
  BoolColumn get isPaidByMe => boolean().withDefault(const Constant(true))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get lastProcessedDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 150)();
  RealColumn get amount => real()();
  IntColumn get category => intEnum<ExpenseCategory>()();
  DateTimeColumn get expenseDate => dateTime()();
  IntColumn get paymentMethod => intEnum<PaymentMethod>()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

