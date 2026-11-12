import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/reminder_helper.dart';
import 'package:duemate/core/utils/whatsapp_helper.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/core/widgets/whatsapp_icon.dart';
import 'package:duemate/domain/entities/person.dart';
import 'package:duemate/domain/entities/person_summary.dart';

class PersonHeaderCard extends StatelessWidget {
  final Person person;
  final PersonSummary summary;
  final String currencySymbol;

  const PersonHeaderCard({
    super.key,
    required this.person,
    required this.summary,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final balance = summary.balance;
    final owes = summary.owesMoney;
    final overpaid = summary.isOverpaid;

    final double progress = summary.totalGiven > 0
        ? (summary.totalReceived / summary.totalGiven).clamp(0.0, 1.0)
        : (balance == 0 ? 1.0 : 0.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Avatar Row
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

        // 1. Soft Peach / Coral Alert Card
        if (owes || overpaid)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C1919) : AppTheme.peachAccent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF5A2C2C) : const Color(0xFFF7D1C6),
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

        // 2. Main White Payment Card with Progress Bar
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: isDark ? cs.surfaceContainerHighest : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation(
                      balance == 0
                          ? cs.primary
                          : (owes ? AppTheme.darkBannerBackground : AppTheme.receivedColor),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.mutedLabel,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            balance == 0
                                ? 'Settled'
                                : (owes ? 'Owes Money' : 'Overpaid'),
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
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
                          icon: const WhatsAppIcon(size: 18),
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}
