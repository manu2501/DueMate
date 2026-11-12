import 'package:flutter/material.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/utils/whatsapp_helper.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/core/widgets/whatsapp_icon.dart';
import 'package:duemate/domain/entities/person.dart';
import 'package:duemate/domain/entities/person_summary.dart';
import 'package:duemate/features/people/presentation/screens/add_edit_person_screen.dart';

class PersonInfoSheet extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const WhatsAppIcon(size: 18),
                    ),
                    title: const Text('WhatsApp Number'),
                    subtitle: Text(person.phone ?? 'No phone number added'),
                    trailing: (person.phone != null && person.phone!.isNotEmpty)
                        ? const Icon(Icons.arrow_forward_ios_rounded, size: 14)
                        : null,
                    onTap: (person.phone != null && person.phone!.isNotEmpty)
                        ? () {
                            Navigator.of(context).pop();
                            final msg = WhatsAppHelper.generateLedgerReminderMessage(summary, currencySymbol: currencySymbol);
                            WhatsAppHelper.sendWhatsAppMessage(
                              phoneNumber: person.phone,
                              message: msg,
                              context: context,
                            );
                          }
                        : null,
                  ),
                  if (person.email != null && person.email!.isNotEmpty) ...[
                    Divider(height: 1, indent: 56, color: cs.outlineVariant),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.email_outlined, size: 18, color: cs.primary),
                      ),
                      title: const Text('Email Address'),
                      subtitle: Text(person.email!),
                    ),
                  ],
                  if (person.notes != null && person.notes!.isNotEmpty) ...[
                    Divider(height: 1, indent: 56, color: cs.outlineVariant),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.note_alt_outlined, size: 18, color: cs.secondary),
                      ),
                      title: const Text('Notes'),
                      subtitle: Text(person.notes!),
                    ),
                  ],
                  Divider(height: 1, indent: 56, color: cs.outlineVariant),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.tertiary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.calendar_today_outlined, size: 18, color: cs.tertiary),
                    ),
                    title: const Text('Added to Ledger'),
                    subtitle: Text(DateFormatter.formatDate(person.createdAt)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
