import 'package:flutter/material.dart';

/// Corner radii. Use these instead of literal numbers.
class AppRadius {
  AppRadius._();
  static const double sm = 8; // chips, small badges, inputs' inner elements
  static const double md = 14; // buttons, inputs, list tiles, small cards
  static const double lg = 20; // cards
  static const double xl = 28; // sheets, dialogs
}

/// Spacing scale (dp).
class AppSpace {
  AppSpace._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double screenGutter = 20;
}

/// Money semantics. Positive-for-you is green, negative-for-you is red;
/// the colour is never the only signal (amounts also carry +/− or wording).
@immutable
class LedgerColors extends ThemeExtension<LedgerColors> {
  const LedgerColors({
    required this.owedToYou,
    required this.youOwe,
    required this.cashIn,
    required this.cashOut,
    required this.settled,
    required this.overpaid,
  });

  /// Someone owes you (an asset).
  final Color owedToYou;

  /// You owe someone.
  final Color youOwe;

  /// Payment received (cash in).
  final Color cashIn;

  /// Money given / paid out (cash out).
  final Color cashOut;
  final Color settled;
  final Color overpaid;

  static const light = LedgerColors(
    owedToYou: Color(0xFF15803D),
    youOwe: Color(0xFFB91C1C),
    cashIn: Color(0xFF15803D),
    cashOut: Color(0xFFB45309),
    settled: Color(0xFF0F766E),
    overpaid: Color(0xFF6D28D9),
  );

  static const dark = LedgerColors(
    owedToYou: Color(0xFF4ADE80),
    youOwe: Color(0xFFF87171),
    cashIn: Color(0xFF4ADE80),
    cashOut: Color(0xFFFBBF24),
    settled: Color(0xFF2DD4BF),
    overpaid: Color(0xFFA78BFA),
  );

  static LedgerColors of(BuildContext context) =>
      Theme.of(context).extension<LedgerColors>() ?? light;

  @override
  LedgerColors copyWith({
    Color? owedToYou,
    Color? youOwe,
    Color? cashIn,
    Color? cashOut,
    Color? settled,
    Color? overpaid,
  }) {
    return LedgerColors(
      owedToYou: owedToYou ?? this.owedToYou,
      youOwe: youOwe ?? this.youOwe,
      cashIn: cashIn ?? this.cashIn,
      cashOut: cashOut ?? this.cashOut,
      settled: settled ?? this.settled,
      overpaid: overpaid ?? this.overpaid,
    );
  }

  @override
  LedgerColors lerp(ThemeExtension<LedgerColors>? other, double t) {
    if (other is! LedgerColors) return this;
    return LedgerColors(
      owedToYou: Color.lerp(owedToYou, other.owedToYou, t)!,
      youOwe: Color.lerp(youOwe, other.youOwe, t)!,
      cashIn: Color.lerp(cashIn, other.cashIn, t)!,
      cashOut: Color.lerp(cashOut, other.cashOut, t)!,
      settled: Color.lerp(settled, other.settled, t)!,
      overpaid: Color.lerp(overpaid, other.overpaid, t)!,
    );
  }
}

class AppTheme {
  AppTheme._();

  // ── Palette: one accent (teal) on neutral surfaces ───────────────────
  static const Color _accent = Color(0xFF0F766E);
  static const Color _accentLight = Color(0xFF2DD4BF);
  static const Color _danger = Color(0xFFB91C1C);

  // Legacy static colours, kept so existing call sites compile. Prefer
  // LedgerColors.of(context) in new code.
  static const Color givenColor = Color(0xFFB45309);
  static const Color receivedColor = Color(0xFF15803D);
  static const Color settledColor = _accent;
  static const Color overpaidColor = Color(0xFF6D28D9);

  // Legacy banner/peach tokens, now neutralised.
  static const Color darkBannerBackground = Color(0xFF0F1F1D);
  static const Color darkBannerSubtitle = Color(0xFFB7C7C4);
  static const Color peachAccent = Color(0xFFFEF2F2);
  static const Color peachAccentText = Color(0xFF7F1D1D);
  static const Color peachBadge = Color(0xFFFEE2E2);
  static const Color peachBadgeText = Color(0xFFB91C1C);
  static const Color cardBorderColor = Color(0xFFE6E6E1);
  static const Color mutedLabel = Color(0xFF62656B);

  // ── Typography ───────────────────────────────────────────────────────
  static TextTheme _buildTextTheme(Brightness brightness) {
    final Color base =
        brightness == Brightness.light ? const Color(0xFF1C1917) : const Color(0xFFFAFAF9);

    final headlineStyle = TextStyle(color: base);
    final bodyStyle = TextStyle(color: base);

    return TextTheme(
      displayLarge: headlineStyle.copyWith(fontSize: 57, fontWeight: FontWeight.w600, letterSpacing: -1.5),
      displayMedium: headlineStyle.copyWith(fontSize: 45, fontWeight: FontWeight.w600, letterSpacing: -1.0),
      displaySmall: headlineStyle.copyWith(fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineLarge: headlineStyle.copyWith(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineMedium: headlineStyle.copyWith(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      headlineSmall: headlineStyle.copyWith(fontSize: 24, fontWeight: FontWeight.w600),
      titleLarge: bodyStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
      titleMedium: bodyStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: bodyStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: bodyStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: bodyStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall: bodyStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w400),
      labelLarge: bodyStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      labelMedium: bodyStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      labelSmall: bodyStyle.copyWith(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
    );
  }

  // ── Light theme ──────────────────────────────────────────────────────
  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: _accent,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFD7F0EC),
      onPrimaryContainer: Color(0xFF053D38),
      secondary: Color(0xFF475569),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE8ECF1),
      onSecondaryContainer: Color(0xFF1E293B),
      tertiary: Color(0xFFB45309),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFFEF3C7),
      onTertiaryContainer: Color(0xFF78350F),
      error: _danger,
      onError: Colors.white,
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF7F1D1D),
      surface: Color(0xFFF7F7F4),
      onSurface: Color(0xFF16181D),
      onSurfaceVariant: Color(0xFF62656B),
      outline: Color(0xFFCFCFC8),
      outlineVariant: Color(0xFFE6E6E1),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: Color(0xFFF0F0EC),
      surfaceContainerHigh: Color(0xFFE8E8E3),
      surfaceContainerHighest: Color(0xFFDFDFD9),
    );

    return _buildTheme(colorScheme, Brightness.light);
  }

  // ── Dark theme ───────────────────────────────────────────────────────
  static ThemeData dark() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _accentLight,
      onPrimary: Color(0xFF042F2B),
      primaryContainer: Color(0xFF0B4A44),
      onPrimaryContainer: Color(0xFFB5F0E8),
      secondary: Color(0xFFA8B3C2),
      onSecondary: Color(0xFF16181D),
      secondaryContainer: Color(0xFF2B323C),
      onSecondaryContainer: Color(0xFFDCE3EC),
      tertiary: Color(0xFFFBBF24),
      onTertiary: Color(0xFF1C1917),
      tertiaryContainer: Color(0xFF78350F),
      onTertiaryContainer: Color(0xFFFDE68A),
      error: Color(0xFFFB7185),
      onError: Color(0xFF1C1917),
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Color(0xFFFECACA),
      surface: Color(0xFF0C0A09),
      onSurface: Color(0xFFFAFAF9),
      onSurfaceVariant: Color(0xFFA8A29E),
      outline: Color(0xFF44403C),
      outlineVariant: Color(0xFF292524),
      surfaceContainerLowest: Color(0xFF0C0A09),
      surfaceContainerLow: Color(0xFF1C1917),
      surfaceContainer: Color(0xFF292524),
      surfaceContainerHigh: Color(0xFF44403C),
      surfaceContainerHighest: Color(0xFF57534E),
    );

    return _buildTheme(colorScheme, Brightness.dark);
  }

  // ── Shared builder ───────────────────────────────────────────────────
  static ThemeData _buildTheme(ColorScheme cs, Brightness brightness) {
    final textTheme = _buildTextTheme(brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: cs,
      textTheme: textTheme,
      scaffoldBackgroundColor: cs.surface,
      extensions: [brightness == Brightness.dark ? LedgerColors.dark : LedgerColors.light],

      // App bar
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: cs.onSurface),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: cs.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),

      // Navigation bar
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: cs.primary.withValues(alpha: 0.12),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: cs.primary, size: 24);
          }
          return IconThemeData(color: cs.onSurfaceVariant, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final style = TextStyle(fontSize: 12);
          if (states.contains(WidgetState.selected)) {
            return style.copyWith(fontWeight: FontWeight.w700, color: cs.primary);
          }
          return style.copyWith(fontWeight: FontWeight.w500, color: cs.onSurfaceVariant);
        }),
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 1,
        highlightElevation: 2,
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHigh.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        elevation: 8,
        backgroundColor: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),

      // Bottom sheets
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        showDragHandle: true,
        backgroundColor: cs.surfaceContainerLow,
        modalBackgroundColor: cs.surfaceContainerLow,
        dragHandleColor: cs.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),

      // Segmented button
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(color: cs.outlineVariant, thickness: 1),

      // Chips
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Filled Button
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
