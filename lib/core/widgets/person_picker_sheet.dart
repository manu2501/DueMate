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

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0x28FFFFFF) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.people_outline_rounded, color: Color(0xFF10B981), size: 22),
                const SizedBox(width: 10),
                Text(
                  'Select Person',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
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
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search people by name...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),
          const SizedBox(height: 12),

          // Import From Contacts Action Pill
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: InkWell(
              onTap: _isImportingContact ? null : _pickFromContacts,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    _isImportingContact
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                          )
                        : const Icon(Icons.contacts_rounded, color: Color(0xFF10B981), size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose from Phone Contacts',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          Text(
                            'Select from device address book directly',
                            style: TextStyle(fontSize: 11, color: Color(0xFF71717A)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF10B981)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          const Divider(height: 1, thickness: 1, color: Color(0x18FFFFFF)),

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
    final balance = summary.balance;

    Color badgeColor;
    String badgeText;
    if (balance > 0) {
      badgeColor = const Color(0xFFF43F5E); // Rose
      badgeText = 'Owes ${CurrencyFormatter.format(balance, symbol: currencySymbol)}';
    } else if (balance < 0) {
      badgeColor = const Color(0xFF8B5CF6); // Purple
      badgeText = 'Overpaid ${CurrencyFormatter.format(balance.abs(), symbol: currencySymbol)}';
    } else {
      badgeColor = const Color(0xFF10B981); // Emerald
      badgeText = 'Settled';
    }

    return Material(
      color: isSelected
          ? const Color(0xFF10B981).withValues(alpha: 0.12)
          : isDark
              ? const Color(0xFF27272A).withValues(alpha: 0.4)
              : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF10B981)
                  : isDark
                      ? const Color(0x18FFFFFF)
                      : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              AvatarWidget(name: summary.person.name, radius: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.person.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (summary.person.phone != null && summary.person.phone!.isNotEmpty)
                      Text(
                        summary.person.phone!,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF71717A)),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.25), width: 1),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
