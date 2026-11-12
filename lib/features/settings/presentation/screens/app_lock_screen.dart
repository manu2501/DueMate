import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/widgets/app_logo.dart';
import 'package:duemate/data/providers/app_providers.dart';

class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerUnlock();
    });
  }

  Future<void> _triggerUnlock() async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);

    try {
      final lockService = ref.read(appLockServiceProvider);
      final success = await lockService.authenticate(
        reason: 'Unlock DueMate to access your financial ledger',
      );

      if (success && mounted) {
        ref.read(appIsLockedProvider.notifier).unlock();
      }
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // App Logo & Shield Badge
              CustomPaint(
                size: const Size(96, 96),
                painter: AppLogoPainter(),
              ),
              const SizedBox(height: 28),

              Text(
                'DueMate is Locked',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Authenticate with Fingerprint, Face ID or PIN to access your financial ledger.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),

              const Spacer(),

              // Unlock Action Button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isAuthenticating ? null : _triggerUnlock,
                  icon: _isAuthenticating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.lock_open_rounded, size: 20),
                  label: Text(_isAuthenticating ? 'Authenticating...' : 'Unlock DueMate'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
