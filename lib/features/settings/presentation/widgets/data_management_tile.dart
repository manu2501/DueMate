import 'package:flutter/material.dart';
import 'package:duemate/core/utils/backup_helper.dart';
import 'package:duemate/core/utils/csv_exporter.dart';
import 'package:duemate/core/utils/permission_manager.dart';
import 'package:duemate/data/database/app_database.dart' hide Person;
import 'package:duemate/domain/entities/ledger_transaction.dart';
import 'package:duemate/domain/entities/person.dart';

class DataManagementTile extends StatelessWidget {
  final List<LedgerTransaction> allTransactions;
  final Map<String, Person> personsMap;
  final String currentCurrency;
  final AppDatabase db;

  const DataManagementTile({
    super.key,
    required this.allTransactions,
    required this.personsMap,
    required this.currentCurrency,
    required this.db,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.table_view_rounded, color: cs.primary, size: 20),
            ),
            title: Text(
              'Export CSV Statement',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'Spreadsheet-compatible complete ledger',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              CsvExporter.exportAndShareAllTransactions(
                transactions: allTransactions,
                personsMap: personsMap,
                currencySymbol: currentCurrency,
              );
            },
          ),
          Divider(height: 1, indent: 64, endIndent: 20, color: cs.outlineVariant),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.folder_zip_outlined, color: cs.secondary, size: 20),
            ),
            title: Text(
              'Full JSON Backup',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'Export full device backup file',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => BackupHelper.exportBackup(db),
          ),
          Divider(height: 1, indent: 64, endIndent: 20, color: cs.outlineVariant),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.tertiary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.security_rounded, color: cs.tertiary, size: 20),
            ),
            title: Text(
              'System Permissions',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'Manage Contacts & Storage access',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => PermissionManager.showPermissionsSheet(context),
          ),
        ],
      ),
    );
  }
}
