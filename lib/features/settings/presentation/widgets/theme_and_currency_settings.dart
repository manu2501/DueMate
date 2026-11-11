import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/data/providers/app_providers.dart';

class ThemeSettingsCard extends ConsumerWidget {
  const ThemeSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currentThemeMode = ref.watch(themeModeProvider);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Theme Mode',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose how ${AppConstants.appName} looks on your device',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ThemePreviewCard(
                  title: 'System',
                  mode: ThemeMode.system,
                  isSelected: currentThemeMode == ThemeMode.system,
                  onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ThemePreviewCard(
                  title: 'Light',
                  mode: ThemeMode.light,
                  isSelected: currentThemeMode == ThemeMode.light,
                  onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ThemePreviewCard(
                  title: 'Dark',
                  mode: ThemeMode.dark,
                  isSelected: currentThemeMode == ThemeMode.dark,
                  onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CurrencySettingsCard extends ConsumerWidget {
  const CurrencySettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currentCurrency = ref.watch(currencySymbolProvider);

    final currentOption = AppConstants.supportedCurrencies.firstWhere(
      (c) => c.symbol == currentCurrency,
      orElse: () => AppConstants.supportedCurrencies.first,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.currency_exchange_rounded, color: cs.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Display Currency',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Used across balances, reports, and reminders',
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentOption.code,
                isExpanded: true,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: cs.primary),
                dropdownColor: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                items: AppConstants.supportedCurrencies.map((c) {
                  final isSelected = c.code == currentOption.code;
                  return DropdownMenuItem<String>(
                    value: c.code,
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? cs.primary : cs.surfaceContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            c.symbol,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? cs.onPrimary : cs.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${c.code} (${c.symbol})',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  color: isSelected ? cs.primary : cs.onSurface,
                                ),
                              ),
                              Text(
                                c.name,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_rounded, color: cs.primary, size: 18),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (code) {
                  if (code != null) {
                    final selected = AppConstants.supportedCurrencies.firstWhere((c) => c.code == code);
                    ref.read(currencySymbolProvider.notifier).setCurrency(selected.symbol);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  final String title;
  final ThemeMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemePreviewCard({
    required this.title,
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surfaceContainerHigh.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.4),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 52,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? cs.primary.withValues(alpha: 0.3) : cs.outlineVariant,
                  width: 1,
                ),
                gradient: mode == ThemeMode.system
                    ? const LinearGradient(
                        colors: [Color(0xFFF8FAFC), Color(0xFF1E293B)],
                        stops: [0.5, 0.5],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: mode == ThemeMode.light
                    ? const Color(0xFFF8FAFC)
                    : mode == ThemeMode.dark
                        ? const Color(0xFF0F172A)
                        : null,
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      height: 7,
                      decoration: BoxDecoration(
                        color: mode == ThemeMode.dark
                            ? const Color(0xFF334155)
                            : mode == ThemeMode.light
                                ? const Color(0xFFE2E8F0)
                                : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    left: 8,
                    width: 24,
                    height: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 30,
                    left: 8,
                    right: 14,
                    height: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: mode == ThemeMode.dark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  mode == ThemeMode.system
                      ? Icons.brightness_auto_rounded
                      : mode == ThemeMode.light
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                  size: 14,
                  color: isSelected ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? cs.primary : cs.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
