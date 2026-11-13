import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/widgets/empty_state_widget.dart';
import 'package:duemate/core/widgets/ui_kit.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/changelog.dart';

/// What changed in each version, newest first, from CHANGELOG.md. Opening it
/// marks this version's notes as seen.
class ChangelogScreen extends ConsumerStatefulWidget {
  const ChangelogScreen({super.key});

  @override
  ConsumerState<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends ConsumerState<ChangelogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(seenReleaseProvider.notifier).markSeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final releases = ref.watch(changelogProvider);
    return Scaffold(
      appBar: AppBar(title: const Text("What's new")),
      body: releases.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyStateWidget(
          icon: Icons.history_rounded,
          title: "Couldn't load the list of changes",
          description: 'Try again after restarting the app.',
        ),
        data: (list) => ListView(
          padding: const EdgeInsets.only(bottom: AppSpace.xxl),
          children: [for (final r in list) _ReleaseCard(r)],
        ),
      ),
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  final Release release;
  const _ReleaseCard(this.release);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final installed = release.version == AppConstants.appVersion;
    final when = release.date == null ? null : DateFormatter.formatDate(release.date!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(installed ? 'Version ${release.version} · installed' : 'Version ${release.version}'),
        GroupCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (when != null)
                    Text('Released $when', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  for (final s in release.sections) ...[
                    const SizedBox(height: AppSpace.md),
                    Text(s.title, style: theme.textTheme.titleSmall?.copyWith(color: cs.primary)),
                    const SizedBox(height: AppSpace.xs),
                    for (final item in s.items)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.xs),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('•  ', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                            Expanded(child: Text(item, style: theme.textTheme.bodyMedium)),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
