
import 'package:flutter/material.dart';
import 'package:duemate/core/theme/app_motion.dart';

/// Corner radii. Use these instead of literal numbers.
class AppRadius {
  AppRadius._();
  static const double sm = 8; // chips, badges
  static const double md = 12; // buttons, inputs, tiles
  static const double lg = 16; // cards
  static const double xl = 24; // sheets, dialogs
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

/// What money colours mean, everywhere in the app:
///  * green  – money coming to you (they owe you, you received)
///  * red    – money you owe
///  * ink    – everything else (spending, lending out); the sign carries it
/// Colour is never the only signal: amounts also carry +/− or words.
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

  final Color owedToYou;
  final Color youOwe;
  final Color cashIn;

  /// Money going out that is not a debt (lending, spending): neutral.
  final Color cashOut;
  final Color settled;
  final Color overpaid;

  static const light = LedgerColors(
    owedToYou: Color(0xFF0A7440),
    youOwe: Color(0xFFB42318),
    cashIn: Color(0xFF0A7440),
    cashOut: Color(0xFF2C3531),
    settled: Color(0xFF5B635F),
    overpaid: Color(0xFFB42318),
  );

  static const dark = LedgerColors(
    owedToYou: Color(0xFF6BD69A),
    youOwe: Color(0xFFFF8A7A),
    cashIn: Color(0xFF6BD69A),
    cashOut: Color(0xFFDCE3DF),
    settled: Color(0xFFA2ABA6),
    overpaid: Color(0xFFFF8A7A),
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

  /// Brand colour, also the launcher icon background.
  static const Color brand = Color(0xFF0E6B55);
  static const Color brandAccent = Color(0xFF9BE7CF);

  // Kept for a few remaining call sites; prefer colorScheme / LedgerColors.
  static const Color receivedColor = Color(0xFF0A7440);
  static const Color mutedLabel = Color(0xFF5B635F);
  static const Color darkBannerBackground = Color(0xFF13201C);
  static const Color peachAccent = Color(0xFFFDECEA);
  static const Color peachAccentText = Color(0xFF7A1A12);

  static const String _font = 'Roboto';
  static const _tabular = [FontFeature.tabularFigures()];

  static TextTheme _textTheme(Color ink) {
    TextStyle s(double size, FontWeight w, {double? height, double spacing = 0, bool numbers = false}) =>
        TextStyle(
          fontFamily: _font,
          fontSize: size,
          fontWeight: w,
          height: height,
          letterSpacing: spacing,
          color: ink,
          fontFeatures: numbers ? _tabular : null,
        );
    return TextTheme(
      displayLarge: s(48, FontWeight.w600, height: 1.1, spacing: -1, numbers: true),
      displayMedium: s(40, FontWeight.w600, height: 1.1, spacing: -0.8, numbers: true),
      displaySmall: s(34, FontWeight.w600, height: 1.15, spacing: -0.6, numbers: true),
      headlineLarge: s(30, FontWeight.w600, height: 1.2, spacing: -0.4, numbers: true),
      headlineMedium: s(26, FontWeight.w600, height: 1.2, spacing: -0.3, numbers: true),
      headlineSmall: s(22, FontWeight.w600, height: 1.25, spacing: -0.2, numbers: true),
      titleLarge: s(20, FontWeight.w600, height: 1.3),
      titleMedium: s(16, FontWeight.w600, height: 1.35, numbers: true),
      titleSmall: s(14, FontWeight.w600, height: 1.35, numbers: true),
      bodyLarge: s(16, FontWeight.w400, height: 1.45),
      bodyMedium: s(14, FontWeight.w400, height: 1.45),
      bodySmall: s(12.5, FontWeight.w400, height: 1.4),
      labelLarge: s(14, FontWeight.w500, height: 1.3),
      labelMedium: s(12.5, FontWeight.w500, height: 1.3),
      labelSmall: s(11, FontWeight.w500, height: 1.3, spacing: 0.2),
    );
  }

  static ThemeData light() {
    const cs = ColorScheme(
      brightness: Brightness.light,
      primary: brand,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFD4EFE5),
      onPrimaryContainer: Color(0xFF033A2D),
      secondary: Color(0xFF4A5751),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE3E9E5),
      onSecondaryContainer: Color(0xFF1B2521),
      tertiary: Color(0xFF8A5A00),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFF8E9C7),
      onTertiaryContainer: Color(0xFF3B2A00),
      error: Color(0xFFB42318),
      onError: Colors.white,
      errorContainer: Color(0xFFFDECEA),
      onErrorContainer: Color(0xFF7A1A12),
      surface: Color(0xFFF6F7F5),
      onSurface: Color(0xFF111614),
      onSurfaceVariant: Color(0xFF5B635F),
      outline: Color(0xFFC6CCC8),
      outlineVariant: Color(0xFFE3E7E4),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: Color(0xFFEEF1EE),
      surfaceContainerHigh: Color(0xFFE6EAE7),
      surfaceContainerHighest: Color(0xFFDDE2DF),
      inverseSurface: Color(0xFF1E2421),
      onInverseSurface: Color(0xFFF0F3F1),
      inversePrimary: Color(0xFF7FD9BC),
    );
    return _build(cs, LedgerColors.light);
  }

  static ThemeData dark() {
    const cs = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF6FD6B5),
      onPrimary: Color(0xFF00382A),
      primaryContainer: Color(0xFF0C4D3E),
      onPrimaryContainer: Color(0xFFBDF2DF),
      secondary: Color(0xFFB4C1BA),
      onSecondary: Color(0xFF1E2925),
      secondaryContainer: Color(0xFF2A3430),
      onSecondaryContainer: Color(0xFFD9E3DE),
      tertiary: Color(0xFFE9C46A),
      onTertiary: Color(0xFF3B2A00),
      tertiaryContainer: Color(0xFF574100),
      onTertiaryContainer: Color(0xFFF8E9C7),
      error: Color(0xFFFF8A7A),
      onError: Color(0xFF4A0B05),
      errorContainer: Color(0xFF5C1710),
      onErrorContainer: Color(0xFFFFDAD4),
      surface: Color(0xFF0F1211),
      onSurface: Color(0xFFE9EEEB),
      onSurfaceVariant: Color(0xFFA2ABA6),
      outline: Color(0xFF4A524E),
      outlineVariant: Color(0xFF2A302D),
      surfaceContainerLowest: Color(0xFF0B0E0D),
      surfaceContainerLow: Color(0xFF171B19),
      surfaceContainer: Color(0xFF1D2220),
      surfaceContainerHigh: Color(0xFF262C29),
      surfaceContainerHighest: Color(0xFF313834),
      inverseSurface: Color(0xFFE9EEEB),
      onInverseSurface: Color(0xFF1E2421),
      inversePrimary: brand,
    );
    return _build(cs, LedgerColors.dark);
  }

  static ThemeData _build(ColorScheme cs, LedgerColors ledger) {
    final text = _textTheme(cs.onSurface);
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md));
    final buttonText = text.labelLarge!.copyWith(fontWeight: FontWeight.w600, fontSize: 15);

    return ThemeData(
      useMaterial3: true,
      brightness: cs.brightness,
      colorScheme: cs,
      fontFamily: _font,
      textTheme: text,
      scaffoldBackgroundColor: cs.surface,
      extensions: [ledger],
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SharedAxisPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.screenGutter),
        minVerticalPadding: 10,
        iconColor: cs.onSurfaceVariant,
        titleTextStyle: text.bodyLarge!.copyWith(fontWeight: FontWeight.w500),
        subtitleTextStyle: text.bodySmall!.copyWith(color: cs.onSurfaceVariant),
        leadingAndTrailingTextStyle: text.titleSmall,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: cs.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              size: 24,
              color: s.contains(WidgetState.selected) ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => text.labelMedium!.copyWith(
              color: s.contains(WidgetState.selected) ? cs.onSurface : cs.onSurfaceVariant,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            )),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 3,
        highlightElevation: 3,
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        extendedTextStyle: buttonText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
          shape: rounded,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
          shape: rounded,
          side: BorderSide(color: cs.outline),
          foregroundColor: cs.onSurface,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: rounded,
          textStyle: text.labelLarge!.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: cs.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: 14),
        labelStyle: text.bodyLarge!.copyWith(color: cs.onSurfaceVariant),
        floatingLabelStyle: text.bodyMedium!.copyWith(color: cs.primary, fontWeight: FontWeight.w500),
        hintStyle: text.bodyLarge!.copyWith(color: cs.outline),
        helperStyle: text.bodySmall!.copyWith(color: cs.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: cs.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: cs.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: cs.error),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        side: BorderSide(color: cs.outlineVariant),
        backgroundColor: cs.surfaceContainerLow,
        selectedColor: cs.primaryContainer,
        labelStyle: text.labelLarge,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 6),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: rounded,
          selectedBackgroundColor: cs.primaryContainer,
          selectedForegroundColor: cs.onPrimaryContainer,
          side: BorderSide(color: cs.outline),
          textStyle: text.labelLarge,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbIcon: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? const Icon(Icons.check, size: 16) : null),
      ),
      dividerTheme: DividerThemeData(color: cs.outlineVariant, thickness: 1, space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium!.copyWith(color: cs.onSurfaceVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        showDragHandle: true,
        backgroundColor: cs.surfaceContainerLow,
        modalBackgroundColor: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: cs.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: text.bodyMedium!.copyWith(color: cs.onInverseSurface),
        actionTextColor: cs.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        linearTrackColor: cs.surfaceContainerHigh,
        linearMinHeight: 6,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: cs.onSurface,
        unselectedLabelColor: cs.onSurfaceVariant,
        labelStyle: text.labelLarge!.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: text.labelLarge,
        indicatorColor: cs.primary,
        dividerColor: cs.outlineVariant,
      ),
    );
  }
}
