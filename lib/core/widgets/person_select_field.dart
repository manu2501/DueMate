import 'package:flutter/material.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/domain/entities/person.dart';

/// Tappable field that shows the chosen person, or a prompt to choose one.
class PersonSelectField extends StatelessWidget {
  final Person? person;
  final String placeholder;
  final VoidCallback onTap;

  const PersonSelectField({
    super.key,
    required this.person,
    required this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final p = person;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: p == null ? cs.outlineVariant : cs.primary.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            if (p != null) ...[
              AvatarWidget(name: p.name, radius: 20),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: theme.textTheme.titleMedium),
                    if (p.phone != null && p.phone!.isNotEmpty)
                      Text(p.phone!, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              TextButton(onPressed: onTap, child: const Text('Change')),
            ] else ...[
              Icon(Icons.person_add_alt_outlined, color: cs.primary),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(placeholder,
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ],
        ),
      ),
    );
  }
}
