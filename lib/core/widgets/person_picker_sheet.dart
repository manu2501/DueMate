import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:smarava/core/utils/contacts_helper.dart';
import 'package:smarava/core/utils/currency_formatter.dart';
import 'package:smarava/core/widgets/avatar_widget.dart';
import 'package:smarava/data/providers/app_providers.dart';
import 'package:smarava/domain/entities/person.dart';
import 'package:smarava/domain/entities/person_summary.dart';

class PersonPickerSheet extends ConsumerStatefulWidget {
  final String? currentSelectedPersonId;

  const PersonPickerSheet({
    super.key,
    this.currentSelectedPersonId,
  });

  /// Opens the picker and returns the selected Person ID, or null if dismissed.
  static Future<String?> show(BuildContext context, {String? currentSelectedPersonId}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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

      // Check if a person with this name or phone already exists
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

      // Create new person from contact
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
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              'Added ${newPerson.name} from Contacts',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF09090B)),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not read contact: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImportingContact = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allPersonsAsync = ref.watch(allPersonSummariesProvider);
    final currencySymbol = ref.watch(currencySymbolProvider);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.people_outline_rounded, color: colorScheme.primary, size: 22),
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
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SearchBar(
              controller: _searchController,
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(colorScheme.surfaceContainerHigh),
              hintText: 'Search people by name...',
              leading: const Icon(Icons.search_rounded, size: 20),
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

          // Import From Contacts Action Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Card(
              elevation: 0,
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: ListTile(
                onTap: _isImportingContact ? null : _pickFromContacts,
                leading: _isImportingContact
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
                      )
                    : Icon(Icons.contacts_rounded, color: colorScheme.primary),
                title: Text(
                  'Choose from Phone Contacts',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
                subtitle: Text(
                  'Select from device address book directly',
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colorScheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Divider
          Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.4)),

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
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isEmpty ? 'No people added yet' : 'No matches for "$_searchQuery"',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Import from phone contacts above or add a new person.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Color(0xFF71717A)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final summary = filtered[index];
                    final isSelected = summary.person.id == widget.currentSelectedPersonId;

                    return _PersonPickerItem(
                      summary: summary,
                      isSelected: isSelected,
                      currencySymbol: currencySymbol,
                      isDark: isDark,
                      onTap: () => Navigator.of(context).pop(summary.person.id),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading people: $e')),
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
  final bool isDark;
  final VoidCallback onTap;

  const _PersonPickerItem({
    required this.summary,
    required this.isSelected,
    required this.currencySymbol,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final balance = summary.balance;

    Color badgeBg;
    Color badgeFg;
    String badgeText;
    if (balance > 0) {
      badgeBg = colorScheme.errorContainer;
      badgeFg = colorScheme.onErrorContainer;
      badgeText = 'Owes ${CurrencyFormatter.format(balance, symbol: currencySymbol)}';
    } else if (balance < 0) {
      badgeBg = colorScheme.tertiaryContainer;
      badgeFg = colorScheme.onTertiaryContainer;
      badgeText = 'Overpaid ${CurrencyFormatter.format(balance.abs(), symbol: currencySymbol)}';
    } else {
      badgeBg = colorScheme.primaryContainer;
      badgeFg = colorScheme.onPrimaryContainer;
      badgeText = 'Settled';
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 3),
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.35)
          : colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: AvatarWidget(name: summary.person.name, radius: 18),
        title: Text(
          summary.person.name,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: (summary.person.phone != null && summary.person.phone!.isNotEmpty)
            ? Text(
                summary.person.phone!,
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: badgeFg,
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle_rounded, color: colorScheme.primary, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
