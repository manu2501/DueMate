import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smarava/core/constants/app_constants.dart';
import 'package:smarava/core/utils/backup_helper.dart';
import 'package:smarava/core/utils/csv_exporter.dart';
import 'package:smarava/core/utils/permission_manager.dart';
import 'package:smarava/data/providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _clearAllData(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: cs.error),
            const SizedBox(width: 8),
            Text('Erase All Data?', style: TextStyle(color: cs.error, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'This action is irreversible.\n\n'
          'All people, loan records, repayment transactions, and notes will be permanently deleted from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final db = ref.read(databaseProvider);
    await db.delete(db.transactions).go();
    await db.delete(db.persons).go();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cs.error,
          content: Text(
            'All vault data has been cleared from local storage.',
            style: TextStyle(color: cs.onError, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currentCurrency = ref.watch(currencySymbolProvider);
    final currentThemeMode = ref.watch(themeModeProvider);
    final db = ref.watch(databaseProvider);
    final allTxsAsync = ref.watch(allTransactionsProvider);
    final personsMap = ref.watch(personsMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Identity Hero Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.account_balance_wallet_rounded, color: cs.primary, size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppConstants.appName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppConstants.appTagline,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_outlined, size: 12, color: cs.primary),
                              const SizedBox(width: 4),
                              Text(
                                '100% Offline Vault',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 1: Appearance (Visual Theme Mockups)
            _sectionHeader('APPEARANCE', theme),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme Mode',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose how ${AppConstants.appName} looks on your device',
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  _buildThemeSelector(context, ref, currentThemeMode),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 2: Currency & Formatting
            _sectionHeader('CURRENCY & REGIONAL', theme),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.currency_exchange_rounded, color: cs.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Display Currency',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Used across balances, reports, and reminders',
                              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildCurrencyDropdown(context, ref, currentCurrency),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 3: Data & Backup
            _sectionHeader('DATA MANAGEMENT', theme),
            Container(
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
                      final txs = allTxsAsync.value ?? [];
                      CsvExporter.exportAndShareAllTransactions(
                        transactions: txs,
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
            ),
            const SizedBox(height: 24),

            // Section 4: Danger Zone
            _sectionHeader('DANGER ZONE', theme),
            Container(
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.delete_forever_rounded, color: cs.error, size: 20),
                ),
                title: Text(
                  'Clear All Vault Data',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.error,
                  ),
                ),
                subtitle: Text(
                  'Permanently delete records & contacts',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: cs.error),
                onTap: () => _clearAllData(context, ref),
              ),
            ),
            const SizedBox(height: 32),

            // Version info footer
            Center(
              child: Column(
                children: [
                  Text(
                    '${AppConstants.appName} ${AppConstants.appVersionString}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '100% Private · Zero Analytics · Local SQLite Vault',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context, WidgetRef ref, ThemeMode currentMode) {
    return Row(
      children: [
        Expanded(
          child: _ThemePreviewCard(
            title: 'System',
            mode: ThemeMode.system,
            isSelected: currentMode == ThemeMode.system,
            onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ThemePreviewCard(
            title: 'Light',
            mode: ThemeMode.light,
            isSelected: currentMode == ThemeMode.light,
            onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ThemePreviewCard(
            title: 'Dark',
            mode: ThemeMode.dark,
            isSelected: currentMode == ThemeMode.dark,
            onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencyDropdown(BuildContext context, WidgetRef ref, String currentCurrency) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final currentOption = AppConstants.supportedCurrencies.firstWhere(
      (c) => c.symbol == currentCurrency,
      orElse: () => AppConstants.supportedCurrencies.first,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentOption.code,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: cs.primary),
          dropdownColor: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          items: AppConstants.supportedCurrencies.map((c) {
            final isSelected = c.code == currentOption.code;
            return DropdownMenuItem<String>(
              value: c.code,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? cs.primary : cs.surfaceContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      c.symbol,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? cs.onPrimary : cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${c.code} (${c.symbol})',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected ? cs.primary : cs.onSurface,
                          ),
                        ),
                        Text(
                          c.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_rounded, color: cs.primary, size: 18),
                ],
              ),
            );
          }).toList(),
          onChanged: (code) {
            if (code != null) {
              final selected = AppConstants.supportedCurrencies.firstWhere((c) => c.code == code);
              ref.read(currencySymbolProvider.notifier).setCurrency(selected.symbol);
            }
          },
        ),
      ),
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  final String title;
  final ThemeMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemePreviewCard({
    required this.title,
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surfaceContainerHigh.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.4),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: [
            // Preview Mockup Box
            Container(
              height: 52,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? cs.primary.withValues(alpha: 0.3) : cs.outlineVariant,
                  width: 1,
                ),
                gradient: mode == ThemeMode.system
                    ? const LinearGradient(
                        colors: [Color(0xFFF8FAFC), Color(0xFF1E293B)],
                        stops: [0.5, 0.5],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: mode == ThemeMode.light
                    ? const Color(0xFFF8FAFC)
                    : mode == ThemeMode.dark
                        ? const Color(0xFF0F172A)
                        : null,
              ),
              child: Stack(
                children: [
                  // Mock header bar
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      height: 7,
                      decoration: BoxDecoration(
                        color: mode == ThemeMode.dark
                            ? const Color(0xFF334155)
                            : mode == ThemeMode.light
                                ? const Color(0xFFE2E8F0)
                                : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  // Mock primary tag
                  Positioned(
                    top: 20,
                    left: 8,
                    width: 24,
                    height: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Mock content line
                  Positioned(
                    top: 30,
                    left: 8,
                    right: 14,
                    height: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: mode == ThemeMode.dark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  mode == ThemeMode.system
                      ? Icons.brightness_auto_rounded
                      : mode == ThemeMode.light
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                  size: 14,
                  color: isSelected ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? cs.primary : cs.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
