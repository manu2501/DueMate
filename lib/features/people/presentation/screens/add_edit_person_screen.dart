import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:duemate/core/utils/contacts_helper.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/widgets/confirm_dialog.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/person_matcher.dart';
import 'package:duemate/domain/entities/person.dart';

class AddEditPersonScreen extends ConsumerStatefulWidget {
  final Person? personToEdit;

  const AddEditPersonScreen({super.key, this.personToEdit});

  static Future<bool?> show(BuildContext context, {Person? personToEdit}) {
    return Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditPersonScreen(personToEdit: personToEdit),
      ),
    );
  }

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

    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
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
      if (contact == null) return;

      final people = (await ref.read(allPersonSummariesProvider.future)).map((s) => s.person);
      final existing = PersonMatcher.findDuplicate(
        people,
        name: contact.name,
        phone: contact.phone,
        excludeId: widget.personToEdit?.id,
      );
      if (existing != null) {
        if (mounted && await showAlreadyInLedgerDialog(context, existing) && mounted) {
          _navigateBack();
          context.push('/people/${existing.id}');
        }
        return;
      }

      if (mounted) {
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
            content: Text('Filled in details for ${contact.name}'),
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
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _navigateBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/people');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final inputName = _nameController.text.trim();
    final inputPhone = _phoneController.text.trim();
    final normPhone = PersonMatcher.normalizePhone(inputPhone);

    final people = (await ref.read(allPersonSummariesProvider.future)).map((s) => s.person);
    final existing = PersonMatcher.findDuplicate(
      people,
      name: inputName,
      phone: inputPhone,
      excludeId: widget.personToEdit?.id,
    );
    if (existing != null) {
      if (!mounted) return;
      final samePhone =
          normPhone.isNotEmpty && PersonMatcher.normalizePhone(existing.phone) == normPhone;
      if (await showAlreadyInLedgerDialog(context, existing, samePhone: samePhone) && mounted) {
        _navigateBack();
        context.push('/people/${existing.id}');
      }
      return;
    }

    setState(() => _isSaving = true);
    final now = DateTime.now();

    try {
      if (isEditing) {
        final updated = widget.personToEdit!.copyWith(
          name: inputName,
          phone: inputPhone.isEmpty ? null : inputPhone,
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          updatedAt: now,
        );
        await ref.read(personRepositoryProvider).updatePerson(updated);
      } else {
        final newPerson = Person(
          id: const Uuid().v4(),
          name: inputName,
          phone: inputPhone.isEmpty ? null : inputPhone,
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          createdAt: now,
          updatedAt: now,
        );
        await ref.read(personRepositoryProvider).createPerson(newPerson);
      }

      if (mounted) {
        _navigateBack();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Changes saved' : 'Person added'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save. Please try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final name = _nameController.text.trim();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _navigateBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: _navigateBack,
          ),
          title: Text(isEditing ? 'Edit person' : 'Add person'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.screenGutter, AppSpace.sm, AppSpace.screenGutter, AppSpace.xxl),
            children: [
              Center(child: AvatarWidget(name: name.isEmpty ? '?' : name, radius: 36)),
              const SizedBox(height: AppSpace.xl),
              if (!isEditing) ...[
                OutlinedButton.icon(
                  onPressed: _isImporting ? null : _importFromContacts,
                  icon: _isImporting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.contacts_outlined),
                  label: const Text('Pick from contacts'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
                  child: Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                        child: Text('or type it in', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                ),
              ],
              TextFormField(
                controller: _nameController,
                autofocus: !isEditing,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outline_rounded)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: AppSpace.lg),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                  helperText: 'Needed for WhatsApp reminders',
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email (optional)', prefixIcon: Icon(Icons.mail_outline_rounded)),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t) ? null : 'Check the email address';
                },
              ),
              const SizedBox(height: AppSpace.lg),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes_rounded),
                  hintText: 'e.g. Roommate, colleague',
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                    : Text(isEditing ? 'Save changes' : 'Add person'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
