import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/utils/permission_manager.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await PermissionManager.checkAndPromptOnStartupOrUpdate(context);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _enterApp() {
    PermissionManager.requestAllPermissions();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Subtle warm gradient accent in background
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    cs.primary.withValues(alpha: isDark ? 0.25 : 0.15),
                    cs.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    cs.secondary.withValues(alpha: isDark ? 0.15 : 0.1),
                    cs.secondary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(flex: 2),

                      // Brand Mark / Logo
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // App Name & Punchy human title
                      Text(
                        AppConstants.appName,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Track what you lend.\nKnow whatâ€™s owed, effortlessly.',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      const Spacer(flex: 3),

                      // Key highlights without rigid card borders
                      _featureRow(
                        icon: Icons.bolt_rounded,
                        accentColor: cs.secondary,
                        title: 'Frictionless log',
                        subtitle: 'Record loans & quick partial repayments in seconds',
                        theme: theme,
                      ),
                      const SizedBox(height: 20),
                      _featureRow(
                        icon: Icons.shield_outlined,
                        accentColor: cs.primary,
                        title: 'Private & offline',
                        subtitle: 'No cloud tracking. Your records stay on your phone',
                        theme: theme,
                      ),
                      const SizedBox(height: 20),
                      _featureRow(
                        icon: Icons.auto_graph_rounded,
                        accentColor: cs.tertiary,
                        title: 'Clear balances',
                        subtitle: 'Audited running totals with statement exports',
                        theme: theme,
                      ),

                      const Spacer(flex: 4),

                      // Main Action CTA
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: _enterApp,
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Get Started',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureRow({
    required IconData icon,
    required Color accentColor,
    required String title,
    required String subtitle,
    required ThemeData theme,
  }) {
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: accentColor, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
