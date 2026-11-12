import 'package:flutter/material.dart';
import 'package:duemate/core/theme/app_theme.dart';

class Suggestion {
  /// Shown on the chip / list row.
  final String label;

  /// Written into the field when picked.
  final String fillValue;
  final IconData icon;

  /// Optional brand colour for the icon only; text stays neutral.
  final Color? iconColor;

  const Suggestion({
    required this.label,
    required this.fillValue,
    required this.icon,
    this.iconColor,
  });

  bool matches(String query) =>
      label.toLowerCase().contains(query) || fillValue.toLowerCase().contains(query);
}

/// A text field with suggestions underneath: quick-pick chips while empty,
/// and a short list of matches while typing.
class SuggestTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;
  final List<Suggestion> suggestions;

  /// Heading above the quick-pick chips.
  final String quickPickTitle;

  const SuggestTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.suggestions,
    required this.quickPickTitle,
    this.hint,
    this.prefixIcon,
    this.validator,
  });

  @override
  State<SuggestTextField> createState() => _SuggestTextFieldState();
}

class _SuggestTextFieldState extends State<SuggestTextField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(SuggestTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _pick(Suggestion s) {
    widget.controller.text = s.fillValue;
    widget.controller.selection = TextSelection.collapsed(offset: s.fillValue.length);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final query = widget.controller.text.trim().toLowerCase();
    final matches = query.isEmpty
        ? const <Suggestion>[]
        : widget.suggestions.where((s) => s.matches(query)).toList();
    final exact = matches.any((m) => m.fillValue.toLowerCase() == query);

    Widget icon(Suggestion s, double size) =>
        Icon(s.icon, size: size, color: s.iconColor ?? cs.primary);

    final Widget below;
    if (matches.isNotEmpty && !exact) {
      // A Material (not a coloured Container) so the ListTiles' ink shows.
      below = Padding(
        padding: const EdgeInsets.only(top: AppSpace.sm),
        child: Material(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final m in matches.take(5))
                ListTile(
                  dense: true,
                  leading: icon(m, 18),
                  title: Text(m.fillValue),
                  trailing: Icon(Icons.north_west_rounded, size: 14, color: cs.onSurfaceVariant),
                  onTap: () => _pick(m),
                ),
            ],
          ),
        ),
      );
    } else if (query.isEmpty) {
      below = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpace.sm),
          Text(widget.quickPickTitle,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in widget.suggestions)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpace.sm),
                    child: ActionChip(
                      avatar: icon(s, 16),
                      label: Text(s.label),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _pick(s),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    } else {
      below = const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
            suffixIcon: widget.controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: widget.controller.clear,
                  ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
          validator: widget.validator,
        ),
        below,
      ],
    );
  }
}
