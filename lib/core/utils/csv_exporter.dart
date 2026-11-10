import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/entities/ledger_transaction.dart';
import '../../domain/entities/person.dart';
import '../../domain/entities/person_summary.dart';
import '../constants/app_constants.dart';
import 'currency_formatter.dart';
import 'date_formatter.dart';

class CsvExporter {
  static Future<void> exportAndShareAllTransactions({
    required List<LedgerTransaction> transactions,
    required Map<String, Person> personsMap,
    String currencySymbol = '₹',
  }) async {
    final List<List<dynamic>> rows = [];

    // Header
    rows.add([
      'Date',
      'Time',
      'Person Name',
      'Type',
      'Amount',
      'Payment Method',
      'Note',
    ]);

    for (final tx in transactions) {
      final person = personsMap[tx.personId];
      final personName = person?.name ?? 'Unknown';
      rows.add([
        DateFormatter.formatDate(tx.transactionDate),
        DateFormatter.formatTime(tx.transactionDate),
        personName,
        tx.type.label,
        tx.amount.toStringAsFixed(2),
        tx.paymentMethod.label,
        tx.note ?? '',
      ]);
    }

    final csvData = csv.encode(rows);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/duemate_transactions_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csvData);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        text: 'DueMate - All Transactions Export',
        subject: 'DueMate Ledger Export',
      ),
    );
  }

  static Future<void> exportAndSharePersonStatement({
    required PersonSummary summary,
    required List<LedgerTransaction> transactions,
    String currencySymbol = '₹',
  }) async {
    final List<List<dynamic>> rows = [];

    // Statement Header
    rows.add(['DueMate Ledger Statement']);
    rows.add(['Person', summary.person.name]);
    if (summary.person.phone != null && summary.person.phone!.isNotEmpty) {
      rows.add(['Phone', summary.person.phone!]);
    }
    rows.add(['Generated On', DateFormatter.formatDateTime(DateTime.now())]);
    rows.add(['Total Given', CurrencyFormatter.format(summary.totalGiven, symbol: currencySymbol)]);
    rows.add(['Total Received', CurrencyFormatter.format(summary.totalReceived, symbol: currencySymbol)]);
    rows.add(['Outstanding Balance', CurrencyFormatter.format(summary.balance, symbol: currencySymbol)]);
    rows.add([]); // Blank row

    // Table Header
    rows.add([
      'Date',
      'Type',
      'Amount',
      'Payment Method',
      'Note',
    ]);

    for (final tx in transactions) {
      rows.add([
        DateFormatter.formatDate(tx.transactionDate),
        tx.type.label,
        tx.amount.toStringAsFixed(2),
        tx.paymentMethod.label,
        tx.note ?? '',
      ]);
    }

    final csvData = csv.encode(rows);
    final tempDir = await getTemporaryDirectory();
    final sanitizedName = summary.person.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final file = File('${tempDir.path}/statement_${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csvData);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        text: 'Statement for ${summary.person.name}',
        subject: 'DueMate Statement - ${summary.person.name}',
      ),
    );
  }
}
