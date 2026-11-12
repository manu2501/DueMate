import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/utils/backup_helper.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/widgets/confirm_dialog.dart';
import 'package:duemate/data/providers/app_providers.dart';

/// Lets the user pick a backup file; resolves to its text, or null if they
/// cancelled. Overridden in tests.
final backupFilePickerProvider = Provider<Future<String?> Function()>(
  (ref) => () async {
    final files = await FilePicker.pickFiles(dialogTitle: 'Choose a DueMate backup');
    return files.isEmpty ? null : files.first.xFile.readAsString();
  },
);

/// Pick a backup, show what's in it, and replace all data after confirming.
Future<void> restoreFromBackup(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) => messenger.showSnackBar(SnackBar(content: Text(text)));

  final String? json;
  try {
    json = await ref.read(backupFilePickerProvider)();
  } catch (_) {
    say("Couldn't open that file.");
    return;
  }
  if (json == null || !context.mounted) return;

  final BackupContents backup;
  try {
    backup = BackupContents.parse(json);
  } on BackupFormatException catch (e) {
    say(e.message);
    return;
  }

  String n(int count, String one, String many) => '$count ${count == 1 ? one : many}';
  final from = backup.exportedAt == null ? '' : ' from ${DateFormatter.formatDate(backup.exportedAt!)}';
  final ok = await showConfirmDialog(
    context,
    title: 'Replace all data?',
    message: 'This backup$from has ${n(backup.peopleCount, 'person', 'people')}, '
        '${n(backup.transactions.length, 'entry', 'entries')}, ${n(backup.emis.length, 'EMI', 'EMIs')} '
        'and ${n(backup.expenses.length, 'expense', 'expenses')}.\n\n'
        "Everything on this phone now will be replaced by it. There's no undo.",
    confirmLabel: 'Replace everything',
    destructive: true,
  );
  if (!ok) return;

  try {
    await backup.restoreInto(ref.read(databaseProvider));
  } catch (_) {
    say("Couldn't restore. Nothing was changed.");
    return;
  }
  // Post installments and recurring expenses due since the backup was made.
  // refresh (not just invalidate): runs now even if Home isn't on screen.
  await (ref.refresh(emiAutoProcessorProvider.future), ref.refresh(recurringExpenseProcessorProvider.future)).wait;
  say('Backup restored');
}
