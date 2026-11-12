import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/domain/entities/ledger_transaction.dart';
import 'package:duemate/domain/entities/person.dart';
import 'package:duemate/domain/entities/person_summary.dart';

class PdfExporter {
  static String _formatAmount(double amount, String symbol) {
    final cleanSymbol = (symbol == '₹') ? 'Rs. ' : '$symbol ';
    return CurrencyFormatter.format(amount, symbol: cleanSymbol);
  }

  /// Exports and shares a formatted PDF statement for a specific person
  static Future<void> exportAndSharePersonStatement({
    required PersonSummary summary,
    required List<LedgerTransaction> transactions,
    String currencySymbol = '₹',
  }) async {
    final pdf = pw.Document();
    final person = summary.person;
    final balanceText = _formatAmount(summary.balance.abs(), currencySymbol);
    final totalGivenText = _formatAmount(summary.totalGiven, currencySymbol);
    final totalReceivedText = _formatAmount(summary.totalReceived, currencySymbol);

    final statusText = summary.owesMoney
        ? 'Owes $balanceText'
        : summary.isOverpaid
            ? 'Advance Credit $balanceText'
            : 'Settled (Zero Balance)';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'DueMate Ledger Statement',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo900,
                  ),
                ),
                pw.Text(
                  DateFormatter.formatDate(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 12),
          ],
        ),
        build: (context) => [
          // Person & Summary Header Box
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        person.name,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      if (person.phone != null && person.phone!.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Phone: ${person.phone}',
                          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
                        ),
                      ],
                      if (person.email != null && person.email!.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Email: ${person.email}',
                          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
                        ),
                      ],
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Status: $statusText',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: summary.owesMoney
                              ? PdfColors.red800
                              : summary.isOverpaid
                                  ? PdfColors.teal800
                                  : PdfColors.green800,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Total Given: $totalGivenText',
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800)),
                    pw.SizedBox(height: 3),
                    pw.Text('Total Received: $totalReceivedText',
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800)),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Outstanding: $balanceText',
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: summary.owesMoney ? PdfColors.red800 : PdfColors.indigo900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Transaction Table Header
          pw.Text(
            'Transaction Activity (${transactions.length})',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),

          if (transactions.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 24),
              child: pw.Center(
                child: pw.Text(
                  'No transactions recorded for this contact.',
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                ),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              headers: const ['Date', 'Type', 'Payment Method', 'Note', 'Amount'],
              data: transactions.map((tx) {
                final isReceived = tx.type == TransactionType.paymentReceived;
                final sign = isReceived ? '+' : '-';
                final amountText = '$sign${_formatAmount(tx.amount, currencySymbol)}';

                return [
                  DateFormatter.formatDate(tx.transactionDate),
                  tx.type.label,
                  tx.paymentMethod.label,
                  tx.note ?? '-',
                  amountText,
                ];
              }).toList(),
            ),
        ],
        footer: (context) => pw.Column(
          children: [
            pw.Divider(thickness: 0.5, color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('DueMate ledger',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final sanitizedName = person.name.replaceAll(RegExp(r'[^\w\s]+'), '_');
    final file = File(
      '${tempDir.path}/statement_${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        text: 'DueMate Statement for ${person.name}',
        subject: 'DueMate Statement - ${person.name}',
      ),
    );
  }

  /// Exports and shares a formatted PDF report of all filtered transactions
  static Future<void> exportAndShareAllTransactions({
    required List<LedgerTransaction> transactions,
    required Map<String, Person> personsMap,
    String currencySymbol = '₹',
    String? filterTitle,
  }) async {
    final pdf = pw.Document();

    double totalGiven = 0;
    double totalReceived = 0;
    for (final tx in transactions) {
      if (tx.type == TransactionType.moneyGiven) {
        totalGiven += tx.amount;
      } else {
        totalReceived += tx.amount;
      }
    }
    final netDiff = totalGiven - totalReceived;

    final filterLabel = filterTitle != null ? ' ($filterTitle)' : '';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'DueMate - Activity & Transactions Report$filterLabel',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo900,
                  ),
                ),
                pw.Text(
                  DateFormatter.formatDate(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 12),
          ],
        ),
        build: (context) => [
          // Report Summary Metrics Box
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Text('Total Transactions',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '${transactions.length}',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('Total Given',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _formatAmount(totalGiven, currencySymbol),
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red800,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('Total Received',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _formatAmount(totalReceived, currencySymbol),
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('Net Balance',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _formatAmount(netDiff, currencySymbol),
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: netDiff > 0 ? PdfColors.red800 : PdfColors.indigo900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          pw.Text(
            'Activity Records (${transactions.length})',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),

          if (transactions.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 24),
              child: pw.Center(
                child: pw.Text(
                  'No transactions recorded for this period.',
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                ),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              headers: const ['Date', 'Person', 'Type', 'Method', 'Note', 'Amount'],
              data: transactions.map((tx) {
                final person = personsMap[tx.personId];
                final personName = person?.name ?? 'Unknown';
                final isReceived = tx.type == TransactionType.paymentReceived;
                final sign = isReceived ? '+' : '-';
                final amountText = '$sign${_formatAmount(tx.amount, currencySymbol)}';

                return [
                  DateFormatter.formatDate(tx.transactionDate),
                  personName,
                  tx.type.label,
                  tx.paymentMethod.label,
                  tx.note ?? '-',
                  amountText,
                ];
              }).toList(),
            ),
        ],
        footer: (context) => pw.Column(
          children: [
            pw.Divider(thickness: 0.5, color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('DueMate ledger',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/duemate_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        text: 'DueMate Activity & Transactions Report',
        subject: 'DueMate Activity Report',
      ),
    );
  }
}

