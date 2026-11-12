import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/services/app_lock_service.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/widgets/app_logo.dart';
import 'package:duemate/data/providers/app_providers.dart';

/// Covers the app while it's locked. Asks for verification as soon as it's
/// shown and whenever the app comes back to the foreground.
class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> with WidgetsBindingObserver {
  bool _busy = false;
  bool _promptWhenResumed = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // On a cold start the first frame can come before the activity is in
      // front; the prompt has nothing to attach to then, so wait.
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
        _unlock();
      } else {
        _promptWhenResumed = true;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _promptWhenResumed) {
      _promptWhenResumed = false;
      _unlock();
    }
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await ref.read(appLockControllerProvider.notifier).unlock();
    if (result == AppLockAuthResult.noScreenLock) {
      messenger?.showSnackBar(const SnackBar(
        content: Text('Your phone has no screen lock any more, so App Lock was turned off.'),
      ));
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = appLockMessage(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appLockControllerProvider.select((s) => s.promptRequest), (_, _) => _unlock());

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.xl, AppSpace.xxl, AppSpace.lg),
          child: Column(
            children: [
              const Spacer(),
              const AppLogo(size: 88),
              const SizedBox(height: AppSpace.xl),
              Text('DueMate is locked', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: AppSpace.sm),
              Text(
                'Unlock with your fingerprint, face or screen lock.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              if (_message != null) ...[
                const SizedBox(height: AppSpace.lg),
                Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _unlock,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: Text(_busy ? 'Waiting for you to verify…' : 'Unlock'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plain cover shown while the app is leaving the foreground, so balances
/// don't appear in the recent-apps thumbnail.
class AppPrivacyCover extends StatelessWidget {
  const AppPrivacyCover({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: const Center(child: AppLogo(size: 88)),
    );
  }
}
