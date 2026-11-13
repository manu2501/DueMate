import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/utils/whatsapp_helper.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/core/widgets/whatsapp_icon.dart';
import 'package:duemate/domain/entities/person.dart';
import 'package:duemate/domain/entities/person_summary.dart';
import 'package:duemate/features/people/presentation/screens/add_edit_person_screen.dart';

class PersonInfoSheet extends ConsumerWidget {
  final Person person;
  final PersonSummary summary;
  final String currencySymbol;

  const PersonInfoSheet({
    super.key,
    required this.person,
    required this.summary,
    required this.currencySymbol,
  });

  static Future<void> show(
    BuildContext context, {
    required Person person,
    required PersonSummary summary,
    required String currencySymbol,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (_) => PersonInfoSheet(
        person: person,
        summary: summary,
        currencySymbol: currencySymbol,
      ),
    );
  }

  static bool _has(String? s) => s != null && s.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasPhone = _has(person.phone);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarWidget(
                  name: person.name,
                  radius: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (person.phone != null && person.phone!.isNotEmpty)
                        Text(
                          person.phone!,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () {
                    Navigator.of(context).pop();
                    AddEditPersonScreen.show(context, personToEdit: person);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Edit Contact Details',
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text(
              'CONTACT INFORMATION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                children: [
                  for (final (i, row) in [
                    _InfoRow(
                      icon: const WhatsAppIcon(size: 18),
                      tint: const Color(0xFF25D366), // WhatsApp brand green, as on its icon
                      title: 'WhatsApp Number',
                      subtitle: Text(hasPhone ? person.phone! : 'No phone number added'),
                      onTap: hasPhone
                          ? () {
                              Navigator.of(context).pop();
                              WhatsAppHelper.sendWhatsAppMessage(
                                phoneNumber: person.phone,
                                message: WhatsAppHelper.generateLedgerReminderMessage(summary,
                                    currencySymbol: currencySymbol, upiId: ref.read(upiIdForRemindersProvider)),
                                context: context,
                              );
                            }
                          : null,
                    ),
                    if (_has(person.email))
                      _InfoRow.icon(Icons.email_outlined, cs.primary, 'Email Address', Text(person.email!)),
                    if (_has(person.upiId))
                      _InfoRow.icon(Icons.account_balance_wallet_outlined, cs.primary, 'UPI ID',
                          SelectableText(person.upiId!)),
                    if (_has(person.notes))
                      _InfoRow.icon(Icons.note_alt_outlined, cs.secondary, 'Notes', Text(person.notes!)),
                    _InfoRow.icon(Icons.calendar_today_outlined, cs.tertiary, 'Added to Ledger',
                        Text(DateFormatter.formatDate(person.createdAt))),
                  ].indexed) ...[
                    if (i > 0) Divider(height: 1, indent: 56, color: cs.outlineVariant),
                    row,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One contact-detail row: a tinted icon badge, a label and the value.
class _InfoRow extends StatelessWidget {
  final Widget icon;
  final Color tint;
  final String title;
  final Widget subtitle;
  final VoidCallback? onTap;

  const _InfoRow({required this.icon, required this.tint, required this.title, required this.subtitle, this.onTap});

  _InfoRow.icon(IconData data, Color color, String title, Widget subtitle)
      : this(icon: Icon(data, size: 18, color: color), tint: color, title: title, subtitle: subtitle);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: icon,
      ),
      title: Text(title),
      subtitle: subtitle,
      trailing: onTap == null ? null : const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      onTap: onTap,
    );
  }
}
