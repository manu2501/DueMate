import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smarava/core/constants/app_constants.dart';
import 'package:smarava/core/utils/permission_manager.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();

    // Ask for permissions needed at start of app or on update
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await PermissionManager.checkAndPromptOnStartupOrUpdate(context);
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _enterApp() {
    PermissionManager.requestAllPermissions();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),

                  // Material 3 App Icon Container
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tagline & App Name
                  Text(
                    AppConstants.appName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Personal Lending & Repayment Tracker',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Feature Cards
                  _featureCard(
                    icon: Icons.flash_on_rounded,
                    iconBg: colorScheme.secondaryContainer,
                    iconFg: colorScheme.onSecondaryContainer,
                    title: 'Fast Entry',
                    description: 'Record loans and ad-hoc partial repayments in under 10 seconds.',
                    theme: theme,
                  ),
                  const SizedBox(height: 12),
                  _featureCard(
                    icon: Icons.lock_outline_rounded,
                    iconBg: colorScheme.primaryContainer,
                    iconFg: colorScheme.onPrimaryContainer,
                    title: '100% Offline & Private',
                    description: 'All ledger data and contacts remain strictly on your local device.',
                    theme: theme,
                  ),
                  const SizedBox(height: 12),
                  _featureCard(
                    icon: Icons.history_edu_rounded,
                    iconBg: colorScheme.tertiaryContainer,
                    iconFg: colorScheme.onTertiaryContainer,
                    title: 'Always Accurate',
                    description: 'Outstanding balances are derived directly from immutable transaction history.',
                    theme: theme,
                  ),

                  const Spacer(),

                  // Material 3 Primary Action Button
                  FilledButton(
                    onPressed: _enterApp,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Open Ledger',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureCard({
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required String title,
    required String description,
    required ThemeData theme,
  }) {
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconFg, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
