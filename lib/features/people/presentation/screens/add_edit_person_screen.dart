import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
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
            content: Text(isEditing ? 'Person updated' : 'Person added successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Person' : 'Add Person'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  hintText: 'e.g. Rahul Kumar',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (Optional)',
                  hintText: 'e.g. +91 98765 43210',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address (Optional)',
                  hintText: 'e.g. rahul@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'e.g. Office friend, neighbor, roommate',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  isEditing ? 'Save Changes' : 'Add Person',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
