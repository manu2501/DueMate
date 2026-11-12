import 'package:flutter/material.dart';
import 'package:duemate/core/widgets/ledger_entry_sheet.dart';
import 'package:duemate/data/database/tables.dart';

/// Opens the ledger entry sheet for money you receive.
abstract final class QuickReceiveSheet {
  static Future<void> show(BuildContext context, {String? personId}) =>
      LedgerEntrySheet.show(context, type: TransactionType.paymentReceived, personId: personId);
}
