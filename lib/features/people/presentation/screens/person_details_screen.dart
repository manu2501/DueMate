import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/csv_exporter.dart';
import 'package:duemate/core/utils/pdf_exporter.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/reminder_helper.dart';
import 'package:duemate/core/utils/whatsapp_helper.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/core/widgets/empty_state_widget.dart';
import 'package:duemate/core/widgets/export_options_sheet.dart';
import 'package:duemate/core/widgets/quick_give_sheet.dart';
import 'package:duemate/core/widgets/quick_receive_sheet.dart';
import 'package:duemate/core/widgets/transaction_tile.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/features/emis/presentation/screens/add_edit_emi_screen.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_card.dart';
import 'package:duemate/features/people/presentation/screens/add_edit_person_screen.dart';
import 'package:duemate/features/transactions/presentation/widgets/transaction_details_dialog.dart';

class PersonDetailsScreen extends ConsumerWidget {
  final String personId;

  const PersonDetailsScreen({super.key, required this.personId});

  void _confirmArchive(BuildContext context, WidgetRef ref, bool isArchived, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArchived ? 'Unarchive $name?' : 'Archive $name?'),
        content: Text(
          isArchived
              ? '$name will be restored to your active list.'
              : '$name will be hidden from the primary active list, but all records remain safe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (isArchived) {
                await ref.read(personRepositoryProvider).unarchivePerson(personId);
              } else {
                await ref.read(personRepositoryProvider).archivePerson(personId);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isArchived ? '$name unarchived' : '$name archived')),
                );
              }
            },
            child: Text(isArchived ? 'Unarchive' : 'Archive'),
          ),
        ],
      ),
    );
  }

  void _navigateBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/people');
    }
  }

  void _confirmDeletePerson(BuildContext context, WidgetRef ref, String name) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $name?', style: TextStyle(color: cs.error)),
        content: Text(
          'Are you sure you want to permanently delete $name and all associated transactions? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(personRepositoryProvider).deletePerson(personId);
              if (context.mounted) {
                _navigateBack(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$name deleted')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final summaryAsync = ref.watch(personSummaryProvider(personId));
    final transactionsAsync = ref.watch(personTransactionsProvider(personId));
    final emisAsync = ref.watch(personEmisProvider(personId));

    return summaryAsync.when(
      data: (summary) {
        if (summary == null) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _navigateBack(context);
            },
            child: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => _navigateBack(context),
                ),
              ),
              body: const Center(child: Text('Person not found')),
            ),
          );
        }

        final person = summary.person;
        final balance = summary.balance;
        final owes = summary.owesMoney;
        final overpaid = summary.isOverpaid;

        // Progress calculation
        final double progress = summary.totalGiven > 0
            ? (summary.totalReceived / summary.totalGiven).clamp(0.0, 1.0)
            : (balance == 0 ? 1.0 : 0.0);

        final transactions = transactionsAsync.value ?? [];

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _navigateBack(context);
          },
          child: Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      // Back button in rounded white box (Screen 2 from screenshot)
                      InkWell(
                        onTap: () => _navigateBack(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cs.outlineVariant),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            size: 20,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    const Spacer(),

                    // Action buttons (WhatsApp + Share reminder + Menu)
                    IconButton(
                      tooltip: 'WhatsApp Reminder',
                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366)),
                      onPressed: () {
                        final msg = WhatsAppHelper.generateLedgerReminderMessage(summary, currencySymbol: currencySymbol);
                        WhatsAppHelper.sendWhatsAppMessage(
                          phoneNumber: person.phone,
                          message: msg,
                          context: context,
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Share Reminder',
                      icon: const Icon(Icons.share_outlined),
                      onPressed: () => ReminderHelper.shareReminder(summary, currencySymbol: currencySymbol),
                    ),
                    IconButton(
                      tooltip: 'Share Statement',
                      icon: const Icon(Icons.receipt_long_outlined),
                      onPressed: () {
                        ExportOptionsSheet.show(
                          context: context,
                          title: 'Statement for ${person.name}',
                          onSharePdf: () => PdfExporter.exportAndSharePersonStatement(
                            summary: summary,
                            transactions: transactions,
                            currencySymbol: currencySymbol,
                          ),
                          onShareCsv: () => CsvExporter.exportAndSharePersonStatement(
                            summary: summary,
                            transactions: transactions,
                            currencySymbol: currencySymbol,
                          ),
                        );
                      },
                    ),

                    // Help / Options button in rounded white box (Screen 2 from screenshot)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'pdf') {
                          PdfExporter.exportAndSharePersonStatement(
                            summary: summary,
                            transactions: transactions,
                            currencySymbol: currencySymbol,
                          );
                        } else if (value == 'csv') {
                          CsvExporter.exportAndSharePersonStatement(
                            summary: summary,
                            transactions: transactions,
                            currencySymbol: currencySymbol,
                          );
                        } else if (value == 'edit') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => AddEditPersonScreen(personToEdit: person),
                            ),
                          );
                        } else if (value == 'add_emi') {
                          AddEditEmiScreen.show(context, personId: personId);
                        } else if (value == 'archive') {
                          _confirmArchive(context, ref, person.isArchived, person.name);
                        } else if (value == 'delete') {
                          _confirmDeletePerson(context, ref, person.name);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'pdf',
                          child: Row(
                            children: [
                              Icon(Icons.picture_as_pdf_outlined, size: 20, color: Colors.red),
                              SizedBox(width: 12),
                              Text('Share PDF Statement'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'csv',
                          child: Row(
                            children: [
                              Icon(Icons.table_chart_outlined, size: 20, color: Colors.green),
                              SizedBox(width: 12),
                              Text('Export CSV Statement'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'add_emi',
                          child: Row(
                            children: [
                              Icon(Icons.event_repeat_rounded, size: 20, color: Colors.purple),
                              SizedBox(width: 12),
                              Text('Add EMI / Loan'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 20),
                              SizedBox(width: 12),
                              Text('Edit Details'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(person.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined, size: 20),
                              SizedBox(width: 12),
                              Text(person.isArchived ? 'Unarchive' : 'Archive'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 20, color: cs.error),
                              SizedBox(width: 12),
                              Text('Delete Person', style: TextStyle(color: cs.error)),
                            ],
                          ),
                        ),
                      ],
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cs.outlineVariant),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.help_outline_rounded,
                          size: 20,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // Title: "Active loan" / Contact Heading from screenshot
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      AvatarWidget(
                        name: person.name,
                        radius: 22,
                        heroTag: 'avatar-${person.id}',
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Active ledger',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.mutedLabel,
                              ),
                            ),
                            Text(
                              person.name,
                              style: GoogleFonts.dmSans(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                color: isDark ? Colors.white : const Color(0xFF131438),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (person.isArchived)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Archived',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 1. Soft Peach / Coral Alert Card ("Penalty accrued" style in screenshot)
                if (owes || overpaid)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C1919) : AppTheme.peachAccent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF5A2C2C)
                              : const Color(0xFFF7D1C6),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                owes ? 'Payment due' : 'Overpaid balance',
                                style: GoogleFonts.dmSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFFFB4AB) : AppTheme.peachAccentText,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(balance.abs(), symbol: currencySymbol),
                                style: GoogleFonts.dmSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF131438),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            owes
                                ? 'Outstanding debt in your ledger.'
                                : 'Borrower has paid more than the initial principal. Credit available in your ledger.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: isDark ? const Color(0xFFE5B5B5) : const Color(0xFF6B433C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // 2. Main White Payment Card with Progress Bar (The signature card in Screenshot 2)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: cs.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: "Paid" and "Rs 500 / 2515"
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Paid',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.mutedLabel,
                              ),
                            ),
                            Text(
                              '${CurrencyFormatter.format(summary.totalReceived, symbol: currencySymbol)} / ${CurrencyFormatter.format(summary.totalGiven, symbol: currencySymbol)}',
                              style: GoogleFonts.dmSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF131438),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Progress Bar (Sleek linear bar matching screenshot)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: progress),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeOutCubic,
                            builder: (context, val, _) {
                              return LinearProgressIndicator(
                                value: val,
                                minHeight: 6,
                                backgroundColor: isDark
                                    ? cs.surfaceContainerHighest
                                    : const Color(0xFFEDEDF5),
                                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Row 2: "Pay" label with "Overdue" / "Active" badge
                        Row(
                          children: [
                            Text(
                              owes ? 'Pay' : 'Balance',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.mutedLabel,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: owes
                                    ? (isDark ? const Color(0xFF4C1D1D) : AppTheme.peachBadge)
                                    : cs.surfaceContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                owes
                                    ? 'Overdue'
                                    : (overpaid ? 'Credit' : 'Settled'),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: owes
                                      ? (isDark ? const Color(0xFFFFB4AB) : AppTheme.peachBadgeText)
                                      : cs.primary,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Huge Bold Amount: "Rs 265"
                        Text(
                          CurrencyFormatter.format(balance.abs(), symbol: currencySymbol),
                          style: GoogleFonts.dmSans(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: isDark ? Colors.white : const Color(0xFF131438),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Breakdown lines: e.g. "Rs 250 — Monthly payment"
                        Text(
                          '${CurrencyFormatter.format(summary.totalGiven, symbol: currencySymbol)} — Total money lent',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${CurrencyFormatter.format(summary.totalReceived, symbol: currencySymbol)} — Total repayments collected',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant,
                          ),
                        ),

                        const SizedBox(height: 20),
                        Divider(color: cs.outlineVariant.withValues(alpha: 0.6), height: 1),
                        const SizedBox(height: 14),

                        // Billing details / Statement link
                        InkWell(
                          onTap: () {
                            ExportOptionsSheet.show(
                              context: context,
                              title: 'Statement for ${person.name}',
                              onSharePdf: () => PdfExporter.exportAndSharePersonStatement(
                                summary: summary,
                                transactions: transactions,
                                currencySymbol: currencySymbol,
                              ),
                              onShareCsv: () => CsvExporter.exportAndSharePersonStatement(
                                summary: summary,
                                transactions: transactions,
                                currencySymbol: currencySymbol,
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Text(
                                'Billing details & statement',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: cs.primary,
                                ),
                              ),
                              const Spacer(),
                              Icon(Icons.arrow_forward_rounded, size: 18, color: cs.primary),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Dual Action Buttons: Record Repayment & Give Money Again
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: FilledButton.tonal(
                                  onPressed: () => QuickReceiveSheet.show(context, personId: personId),
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.south_west_rounded, size: 18, color: cs.primary),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Repayment',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: FilledButton(
                                  onPressed: () => QuickGiveSheet.show(context, personId: personId),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: cs.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.north_east_rounded, size: 18),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Give Money',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 3. Payment Reminder Card (Send Reminder Option)
                if (owes)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.notifications_active_outlined,
                              size: 22,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Payment Reminder',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF131438),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Send balance details via WhatsApp or SMS',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Row(
                            children: [
                              IconButton.filledTonal(
                                onPressed: () {
                                  final msg = WhatsAppHelper.generateLedgerReminderMessage(summary, currencySymbol: currencySymbol);
                                  WhatsAppHelper.sendWhatsAppMessage(
                                    phoneNumber: person.phone,
                                    message: msg,
                                    context: context,
                                  );
                                },
                                icon: const Icon(Icons.chat_rounded, size: 18, color: Color(0xFF25D366)),
                                tooltip: 'WhatsApp Reminder',
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonalIcon(
                                onPressed: () => ReminderHelper.shareReminder(summary, currencySymbol: currencySymbol),
                                icon: const Icon(Icons.share_rounded, size: 16),
                                label: const Text('Share'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // Credit Card EMIs section
                emisAsync.when(
                  data: (emis) {
                    if (emis.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: InkWell(
                          onTap: () => AddEditEmiScreen.show(context, personId: personId),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.event_repeat_rounded,
                                    color: Colors.purple,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Split EMI or Monthly Loan',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xFF131438),
                                        ),
                                      ),
                                      Text(
                                        'Auto-post monthly installments for cards & loans',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.add_circle_outline_rounded, color: cs.primary, size: 20),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'EMIs & Monthly Loans',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                      color: isDark ? Colors.white : const Color(0xFF131438),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${emis.length}',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.purple,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: () => AddEditEmiScreen.show(context, personId: personId),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add EMI / Loan'),
                                style: TextButton.styleFrom(
                                  foregroundColor: cs.primary,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...emis.map((emi) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: EmiCard(
                                  emi: emi,
                                  person: person,
                                  currencySymbol: currencySymbol,
                                ),
                              )),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 20),

                // 4. Transaction History Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transaction History',
                        style: GoogleFonts.dmSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: isDark ? Colors.white : const Color(0xFF131438),
                        ),
                      ),
                      Text(
                        '${transactions.length} entries',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Transaction list or empty state
                if (transactions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: EmptyStateWidget(
                      icon: Icons.receipt_long_outlined,
                      title: 'No transactions yet',
                      description: 'Tap Give Money or Repayment above to record your first transaction with ${person.name}.',
                      actionLabel: 'Give Money',
                      onActionPressed: () => QuickGiveSheet.show(context, personId: personId),
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: transactions.length,
                      separatorBuilder: (ctx, i) => Divider(
                        height: 1,
                        indent: 68,
                        endIndent: 16,
                        color: cs.outlineVariant.withValues(alpha: 0.6),
                      ),
                      itemBuilder: (ctx, index) {
                        final tx = transactions[index];
                        return TransactionTile(
                          transaction: tx,
                          person: person,
                          currencySymbol: currencySymbol,
                          onTap: () {
                            TransactionDetailsDialog.show(
                              context,
                              transaction: tx,
                              person: person,
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
      loading: () => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _navigateBack(context);
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => _navigateBack(context),
            ),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (err, _) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _navigateBack(context);
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => _navigateBack(context),
            ),
          ),
          body: Center(child: Text('Error: $err')),
        ),
      ),
    );
  }
}
