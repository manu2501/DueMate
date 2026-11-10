import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Hand-picked palette ──────────────────────────────────────────────
  static const Color _indigo = Color(0xFF4F46E5);
  static const Color _indigoLight = Color(0xFF818CF8);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _rose = Color(0xFFEF4444);
  static const Color _emerald = Color(0xFF10B981);
  static const Color _violet = Color(0xFF8B5CF6);

  // Semantic ledger colours (used throughout the app)
  static const Color givenColor = _rose;
  static const Color receivedColor = _emerald;
  static const Color settledColor = _indigo;
  static const Color overpaidColor = _violet;

  // Screenshot inspired styling tokens
  static const Color darkBannerBackground = Color(0xFF131438);
  static const Color darkBannerSubtitle = Color(0xFFB4B3D4);
  static const Color peachAccent = Color(0xFFFDECE7);
  static const Color peachAccentText = Color(0xFF7F1D1D);
  static const Color peachBadge = Color(0xFFFCE3DC);
  static const Color peachBadgeText = Color(0xFFDC2626);
  static const Color cardBorderColor = Color(0xFFECECF6);
  static const Color mutedLabel = Color(0xFF8C8CA8);

  // ── Typography ───────────────────────────────────────────────────────
  static TextTheme _buildTextTheme(Brightness brightness) {
    final Color base =
        brightness == Brightness.light ? const Color(0xFF1C1917) : const Color(0xFFFAFAF9);

    final headlineStyle = GoogleFonts.dmSans(color: base);
    final bodyStyle = GoogleFonts.inter(color: base);

    return TextTheme(
      displayLarge: headlineStyle.copyWith(fontSize: 57, fontWeight: FontWeight.w800, letterSpacing: -1.5),
      displayMedium: headlineStyle.copyWith(fontSize: 45, fontWeight: FontWeight.w800, letterSpacing: -1.0),
      displaySmall: headlineStyle.copyWith(fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineLarge: headlineStyle.copyWith(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineMedium: headlineStyle.copyWith(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      headlineSmall: headlineStyle.copyWith(fontSize: 24, fontWeight: FontWeight.w600),
      titleLarge: bodyStyle.copyWith(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.2),
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
      primary: _indigo,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFEEF2FF),
      onPrimaryContainer: Color(0xFF312E81),
      secondary: _amber,
      onSecondary: Color(0xFF1C1917),
      secondaryContainer: Color(0xFFFEF3C7),
      onSecondaryContainer: Color(0xFF78350F),
      tertiary: _violet,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFF3E8FF),
      onTertiaryContainer: Color(0xFF581C87),
      error: _rose,
      onError: Colors.white,
      errorContainer: Color(0xFFFEF2F2),
      onErrorContainer: Color(0xFF991B1B),
      surface: Color(0xFFF6F7FB),
      onSurface: Color(0xFF111227),
      onSurfaceVariant: Color(0xFF74758C),
      outline: Color(0xFFE2E4F0),
      outlineVariant: Color(0xFFECECF6),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: Color(0xFFEFF1FA),
      surfaceContainerHigh: Color(0xFFE5E7F4),
      surfaceContainerHighest: Color(0xFFDCDFEF),
    );

    return _buildTheme(colorScheme, Brightness.light);
  }

  // ── Dark theme ───────────────────────────────────────────────────────
  static ThemeData dark() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _indigoLight,
      onPrimary: Color(0xFF1E1B4B),
      primaryContainer: Color(0xFF312E81),
      onPrimaryContainer: Color(0xFFC7D2FE),
      secondary: Color(0xFFFBBF24),
      onSecondary: Color(0xFF1C1917),
      secondaryContainer: Color(0xFF78350F),
      onSecondaryContainer: Color(0xFFFDE68A),
      tertiary: Color(0xFFA78BFA),
      onTertiary: Color(0xFF1E1B4B),
      tertiaryContainer: Color(0xFF4C1D95),
      onTertiaryContainer: Color(0xFFDDD6FE),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          final style = GoogleFonts.inter(fontSize: 12);
          if (states.contains(WidgetState.selected)) {
            return style.copyWith(fontWeight: FontWeight.w700, color: cs.primary);
          }
          return style.copyWith(fontWeight: FontWeight.w500, color: cs.onSurfaceVariant);
        }),
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 4,
        highlightElevation: 8,
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
