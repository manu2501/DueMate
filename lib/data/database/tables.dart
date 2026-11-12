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
  /// Their UPI ID (VPA), to pay them from a UPI app. Since schema v8.
  TextColumn get upiId => text().nullable()();
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
  BoolColumn get isSettled => boolean().withDefault(const Constant(false))();
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
  RealColumn get interestRate => real().withDefault(const Constant(0.0))();
  TextColumn get interestType => text().withDefault(const Constant('reducing'))();
  /// 'card' | 'loan'. Drives labels and colours; no longer guessed from names.
  TextColumn get kind => text().withDefault(const Constant('card'))();
  /// How the plan was entered: 'split' (a total divided over months) or
  /// 'emi' (the monthly EMI typed in directly).
  TextColumn get planMode => text().withDefault(const Constant('emi'))();
  /// Original amount before interest and charges. 0 = not known.
  RealColumn get principal => real().withDefault(const Constant(0.0))();
  /// One-time charges (processing fee, GST, ...).
  RealColumn get charges => real().withDefault(const Constant(0.0))();
  TextColumn get customScheduleJson => text().nullable()();
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

  /// The [RecurringExpenses] rule that posted it, if any. No foreign key:
  /// stopping a rule keeps the expenses it posted. Since schema v9.
  TextColumn get recurringId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A monthly repeating expense (rent, subscriptions). Since schema v9.
/// Deleting a rule stops it; expenses it already posted stay.
class RecurringExpenses extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 150)();
  RealColumn get amount => real()();
  IntColumn get category => intEnum<ExpenseCategory>()();
  IntColumn get paymentMethod => intEnum<PaymentMethod>()();
  TextColumn get notes => text().nullable()();

  /// Posts on this day each month (clamped to short months).
  IntColumn get dayOfMonth => integer()();

  /// First occurrence; nothing is posted before it.
  DateTimeColumn get startDate => dateTime()();

  /// Date of the latest posted occurrence; months up to it are done.
  DateTimeColumn get lastPostedDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
