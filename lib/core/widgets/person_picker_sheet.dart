import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:duemate/core/utils/contacts_helper.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/core/widgets/ui_kit.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/person.dart';
import 'package:duemate/domain/entities/person_summary.dart';

class PersonPickerSheet extends ConsumerStatefulWidget {
  final String? currentSelectedPersonId;

  const PersonPickerSheet({
    super.key,
    this.currentSelectedPersonId,
  });

  static Future<String?> show(BuildContext context, {String? currentSelectedPersonId}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PersonPickerSheet(currentSelectedPersonId: currentSelectedPersonId),
    );
  }

  @override
  ConsumerState<PersonPickerSheet> createState() => _PersonPickerSheetState();
}

class _PersonPickerSheetState extends ConsumerState<PersonPickerSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isImportingContact = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickFromContacts() async {
    setState(() => _isImportingContact = true);
    try {
      final contactData = await ContactsHelper.pickContact();
      if (contactData == null) {
        setState(() => _isImportingContact = false);
        return;
      }

      final allPersons = await ref.read(allPersonSummariesProvider.future);
      final existing = allPersons.where((s) {
        final sameName = s.person.name.toLowerCase() == contactData.name.toLowerCase();
        final samePhone = contactData.phone != null &&
            s.person.phone != null &&
            s.person.phone!.replaceAll(RegExp(r'\s+'), '') ==
                contactData.phone!.replaceAll(RegExp(r'\s+'), '');
        return sameName || samePhone;
      }).firstOrNull;

      if (existing != null) {
        if (mounted) {
          Navigator.of(context).pop(existing.person.id);
        }
        return;
      }

      final now = DateTime.now();
      final newPerson = Person(
        id: const Uuid().v4(),
        name: contactData.name,
        phone: contactData.phone,
        email: contactData.email,
        notes: 'Imported from Phone Contacts',
        createdAt: now,
        updatedAt: now,
      );

      await ref.read(personRepositoryProvider).createPerson(newPerson);

      if (mounted) {
        Navigator.of(context).pop(newPerson.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            content: Text(
              'Added ${newPerson.name} from Contacts',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't read that contact.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isImportingContact = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPersonsAsync = ref.watch(allPersonSummariesProvider);
    final currencySymbol = ref.watch(currencySymbolProvider);

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.people_outline_rounded, color: cs.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Select Person',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SearchBar(
              controller: _searchController,
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerHigh),
              hintText: 'Search people by name...',
              leading: Icon(Icons.search_rounded, size: 20, color: cs.onSurfaceVariant),
              trailing: [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
              ],
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),
          const SizedBox(height: 12),

          // Import Action Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: InkWell(
              onTap: _isImportingContact ? null : _pickFromContacts,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _isImportingContact
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                          )
                        : Icon(Icons.contacts_rounded, color: cs.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Choose from Phone Contacts',
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: cs.primary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          Divider(height: 1, color: cs.outlineVariant),

          // Persons List
          Expanded(
            child: allPersonsAsync.when(
              data: (summaries) {
                final active = summaries.where((s) => !s.person.isArchived).toList();
                final filtered = _searchQuery.isEmpty
                    ? active
                    : active.where((s) {
                        return s.person.name.toLowerCase().contains(_searchQuery) ||
                            (s.person.phone?.toLowerCase().contains(_searchQuery) ?? false);
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search_rounded, size: 44, color: cs.outline),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isEmpty ? 'No people in ledger yet' : 'No matches for "$_searchQuery"',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Import from phone contacts above to begin.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final summary = filtered[index];
                    final isSelected = summary.person.id == widget.currentSelectedPersonId;

                    return _PersonPickerItem(
                      summary: summary,
                      isSelected: isSelected,
                      currencySymbol: currencySymbol,
                      onTap: () => Navigator.of(context).pop(summary.person.id),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Center(child: Text("Couldn't load people.")),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonPickerItem extends StatelessWidget {
  final PersonSummary summary;
  final bool isSelected;
  final String currencySymbol;
  final VoidCallback onTap;

  const _PersonPickerItem({
    required this.summary,
    required this.isSelected,
    required this.currencySymbol,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final wording = balanceWording(summary);
    final hasBalance = summary.balance.abs() > 0.0001;
    final phone = summary.person.phone;

    return ListTile(
      onTap: onTap,
      selected: isSelected,
      selectedTileColor: cs.primaryContainer.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: AvatarWidget(name: summary.person.name, radius: 18),
      title: Text(summary.person.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: (phone != null && phone.isNotEmpty) ? Text(phone) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (hasBalance) MoneyText(summary.balance, symbol: currencySymbol, tone: wording.tone),
              Text(wording.label, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
          if (isSelected) ...[
            const SizedBox(width: 8),
            Icon(Icons.check_circle_rounded, color: cs.primary, size: 20),
          ],
        ],
      ),
    );
  }
}
