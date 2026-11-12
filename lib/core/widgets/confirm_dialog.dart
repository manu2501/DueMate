import 'package:flutter/material.dart';
import 'package:duemate/domain/entities/person.dart';

/// Standard yes/no dialog. Resolves to true only when the user confirms.
/// [destructive] styles the confirm button in the error colour.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
  String cancelLabel = 'Cancel',
}) async {
  final cs = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError)
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Shown when adding someone who is already in the ledger. Resolves to true
/// when the user wants to open the existing person's ledger.
Future<bool> showAlreadyInLedgerDialog(
  BuildContext context,
  Person existing, {
  bool samePhone = false,
}) {
  final hasPhone = existing.phone != null && existing.phone!.trim().isNotEmpty;
  final message = samePhone && hasPhone
      ? '${existing.name} already has the number ${existing.phone}.'
      : hasPhone
          ? '${existing.name} (${existing.phone}) is already in your ledger.'
          : '${existing.name} is already in your ledger.';
  return showConfirmDialog(
    context,
    title: 'Already in your ledger',
    message: message,
    confirmLabel: 'Open ledger',
  );
}
