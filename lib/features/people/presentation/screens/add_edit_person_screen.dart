import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:smarava/core/utils/contacts_helper.dart';
import 'package:smarava/data/providers/app_providers.dart';
import 'package:smarava/domain/entities/person.dart';

class AddEditPersonScreen extends ConsumerStatefulWidget {
  final Person? personToEdit;

  const AddEditPersonScreen({super.key, this.personToEdit});

  @override
  ConsumerState<AddEditPersonScreen> createState() => _AddEditPersonScreenState();
}

class _AddEditPersonScreenState extends ConsumerState<AddEditPersonScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _notesController;
  bool _isSaving = false;
  bool _isImporting = false;

  bool get isEditing => widget.personToEdit != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.personToEdit?.name ?? '');
    _phoneController = TextEditingController(text: widget.personToEdit?.phone ?? '');
    _emailController = TextEditingController(text: widget.personToEdit?.email ?? '');
    _notesController = TextEditingController(text: widget.personToEdit?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _importFromContacts() async {
    setState(() => _isImporting = true);
    try {
      final contact = await ContactsHelper.pickContact();
      if (contact != null && mounted) {
        _nameController.text = contact.name;
        if (contact.phone != null && contact.phone!.isNotEmpty) {
          _phoneController.text = contact.phone!;
        }
        if (contact.email != null && contact.email!.isNotEmpty) {
          _emailController.text = contact.email!;
        }
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported ${contact.name} from contacts'),
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
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final now = DateTime.now();

    try {
      if (isEditing) {
        final updated = widget.personToEdit!.copyWith(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          updatedAt: now,
        );
        await ref.read(personRepositoryProvider).updatePerson(updated);
      } else {
        final newPerson = Person(
          id: const Uuid().v4(),
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          createdAt: now,
          updatedAt: now,
        );
        await ref.read(personRepositoryProvider).createPerson(newPerson);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Details updated' : 'Added to ledger'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Details' : 'Add Person'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Auto-fill from Contacts Card
              Card(
                elevation: 0,
                color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: ListTile(
                  onTap: _isImporting ? null : _importFromContacts,
                  leading: _isImporting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
                        )
                      : Icon(Icons.contacts_rounded, color: colorScheme.primary, size: 22),
                  title: Text(
                    'Import from Phone Contacts',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                  ),
                  subtitle: Text(
                    'Auto-populate name and contact number',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colorScheme.primary),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name *',
                          hintText: 'e.g. Rahul Kumar',
                          prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a name';
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number (Optional)',
                          hintText: 'e.g. +91 98765 43210',
                          prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email Address (Optional)',
                          hintText: 'e.g. rahul@example.com',
                          prefixIcon: Icon(Icons.email_outlined, size: 20),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (Optional)',
                          hintText: 'e.g. Office friend, neighbor, roommate',
                          prefixIcon: Icon(Icons.notes_rounded, size: 20),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  isEditing ? 'Save Changes' : 'Create Person Entry',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
