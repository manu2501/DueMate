import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/utils/whatsapp_helper.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/core/widgets/quick_give_sheet.dart';
import 'package:duemate/core/widgets/quick_receive_sheet.dart';
import 'package:duemate/core/widgets/whatsapp_icon.dart';
import 'package:duemate/domain/entities/person_summary.dart';

class PersonDirectoryTile extends StatelessWidget {
  final PersonSummary summary;
  final String currencySymbol;

  const PersonDirectoryTile({
    super.key,
    required this.summary,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final person = summary.person;
    final balance = summary.balance;
    final owes = summary.owesMoney;
    final overpaid = summary.isOverpaid;

    Color badgeColor;
    String badgeTitle;
    if (owes) {
      badgeColor = cs.primary;
      badgeTitle = 'Owes You: ${CurrencyFormatter.format(balance, symbol: currencySymbol)}';
    } else if (overpaid) {
      badgeColor = cs.error;
      badgeTitle = 'You Owe: ${CurrencyFormatter.format(balance.abs(), symbol: currencySymbol)}';
    } else {
      badgeColor = cs.secondary;
      badgeTitle = 'Settled';
    }

    return InkWell(
      onTap: () => context.push('/people/${person.id}'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
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
                        person.name,
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF131438),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary.lastTransaction != null
                            ? 'Last paid ${DateFormatter.formatRelative(summary.lastTransaction!.transactionDate)}'
                            : (person.phone != null && person.phone!.isNotEmpty)
                                ? person.phone!
                                : 'Added ${DateFormatter.formatShortDate(person.createdAt)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeTitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.6)),
            const SizedBox(height: 10),

            // Card Quick Actions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (owes) ...[
                      SizedBox(
                        height: 32,
                        child: FilledButton.tonalIcon(
                          onPressed: () => QuickReceiveSheet.show(context, personId: person.id),
                          icon: Icon(Icons.south_west_rounded, size: 14, color: cs.primary),
                          label: const Text('Receive', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else if (overpaid) ...[
                      SizedBox(
                        height: 32,
                        child: FilledButton.icon(
                          onPressed: () => QuickGiveSheet.show(context, personId: person.id),
                          icon: const Icon(Icons.north_east_rounded, size: 14),
                          label: const Text('Pay', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    if (owes && person.phone != null && person.phone!.isNotEmpty)
                      SizedBox(
                        height: 32,
                        child: IconButton.filledTonal(
                          onPressed: () {
                            final msg = WhatsAppHelper.generateLedgerReminderMessage(
                              summary,
                              currencySymbol: currencySymbol,
                            );
                            WhatsAppHelper.sendWhatsAppMessage(
                              phoneNumber: person.phone,
                              message: msg,
                              context: context,
                            );
                          },
                          icon: const WhatsAppIcon(size: 16),
                          tooltip: 'WhatsApp Reminder',
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                  ],
                ),

                Row(
                  children: [
                    Text(
                      'View Ledger',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: cs.primary,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
