import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

@immutable
class ConvoCustomColors extends ThemeExtension<ConvoCustomColors> {
  const ConvoCustomColors({
    required this.cardBackground,
    required this.cardBorder,
    required this.surfaceSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accentGlow,
    required this.chipBackground,
    required this.radarRingColor,
    required this.radarFillColor,
  });

  final Color cardBackground;
  final Color cardBorder;
  final Color surfaceSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accentGlow;
  final Color chipBackground;
  final Color radarRingColor;
  final Color radarFillColor;

  static const light = ConvoCustomColors(
    cardBackground: AppColors.lightSurface,
    cardBorder: AppColors.lightBorder,
    surfaceSubtle: AppColors.lightSurfaceSecondary,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textTertiary: AppColors.lightTextTertiary,
    accentGlow: Color(0x3300D2B4),
    chipBackground: AppColors.lightSurfaceSecondary,
    radarRingColor: Color(0x225B4DFF),
    radarFillColor: Color(0x0C5B4DFF),
  );

  static const dark = ConvoCustomColors(
    cardBackground: AppColors.darkSurface,
    cardBorder: AppColors.darkBorder,
    surfaceSubtle: AppColors.darkSurfaceSecondary,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textTertiary: AppColors.darkTextTertiary,
    accentGlow: Color(0x3300D2B4),
    chipBackground: AppColors.darkSurfaceSecondary,
    radarRingColor: Color(0x3300D2B4),
    radarFillColor: Color(0x1000D2B4),
  );

  @override
  ConvoCustomColors copyWith({
    Color? cardBackground,
    Color? cardBorder,
    Color? surfaceSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accentGlow,
    Color? chipBackground,
    Color? radarRingColor,
    Color? radarFillColor,
  }) {
    return ConvoCustomColors(
      cardBackground: cardBackground ?? this.cardBackground,
      cardBorder: cardBorder ?? this.cardBorder,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accentGlow: accentGlow ?? this.accentGlow,
      chipBackground: chipBackground ?? this.chipBackground,
      radarRingColor: radarRingColor ?? this.radarRingColor,
      radarFillColor: radarFillColor ?? this.radarFillColor,
    );
  }

  @override
  ConvoCustomColors lerp(ThemeExtension<ConvoCustomColors>? other, double t) {
    if (other is! ConvoCustomColors) return this;
    return ConvoCustomColors(
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accentGlow: Color.lerp(accentGlow, other.accentGlow, t)!,
      chipBackground: Color.lerp(chipBackground, other.chipBackground, t)!,
      radarRingColor: Color.lerp(radarRingColor, other.radarRingColor, t)!,
      radarFillColor: Color.lerp(radarFillColor, other.radarFillColor, t)!,
    );
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final baseColorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFECEBFF),
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFD7FBF4),
      onSecondaryContainer: AppColors.accentDark,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      surfaceContainerLowest: AppColors.lightBackground,
      surfaceContainerLow: AppColors.lightSurfaceSecondary,
      surfaceContainer: AppColors.lightSurfaceSecondary,
      surfaceContainerHigh: AppColors.lightSurfaceTertiary,
      outline: AppColors.lightBorder,
      outlineVariant: AppColors.lightBorderSubtle,
      error: AppColors.error,
      onError: Colors.white,
    );

    return _buildTheme(
      colorScheme: baseColorScheme,
      scaffoldBg: AppColors.lightBackground,
      customColors: ConvoCustomColors.light,
      brightness: Brightness.light,
    );
  }

  static ThemeData get darkTheme {
    final baseColorScheme = ColorScheme.dark(
      primary: AppColors.primaryLight,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF2E2777),
      onPrimaryContainer: const Color(0xFFDEDCFF),
      secondary: AppColors.accent,
      onSecondary: const Color(0xFF003830),
      secondaryContainer: const Color(0xFF005146),
      onSecondaryContainer: const Color(0xFF86F8E8),
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      surfaceContainerLowest: AppColors.darkBackground,
      surfaceContainerLow: AppColors.darkSurfaceSecondary,
      surfaceContainer: AppColors.darkSurfaceSecondary,
      surfaceContainerHigh: AppColors.darkSurfaceTertiary,
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkBorderSubtle,
      error: AppColors.error,
      onError: Colors.white,
    );

    return _buildTheme(
      colorScheme: baseColorScheme,
      scaffoldBg: AppColors.darkBackground,
      customColors: ConvoCustomColors.dark,
      brightness: Brightness.dark,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Color scaffoldBg,
    required ConvoCustomColors customColors,
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;
    final primaryTextColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final textTheme = TextTheme(
      displayLarge: AppTypography.displayLarge.copyWith(
        color: primaryTextColor,
      ),
      displayMedium: AppTypography.displayMedium.copyWith(
        color: primaryTextColor,
      ),
      headlineLarge: AppTypography.headlineLarge.copyWith(
        color: primaryTextColor,
      ),
      headlineMedium: AppTypography.headlineMedium.copyWith(
        color: primaryTextColor,
      ),
      titleLarge: AppTypography.titleLarge.copyWith(color: primaryTextColor),
      titleMedium: AppTypography.titleMedium.copyWith(color: primaryTextColor),
      bodyLarge: AppTypography.bodyLarge.copyWith(color: primaryTextColor),
      bodyMedium: AppTypography.bodyMedium.copyWith(color: secondaryTextColor),
      bodySmall: AppTypography.bodySmall.copyWith(
        color: isDark
            ? AppColors.darkTextTertiary
            : AppColors.lightTextTertiary,
      ),
      labelLarge: AppTypography.labelLarge.copyWith(color: primaryTextColor),
      labelMedium: AppTypography.labelMedium.copyWith(
        color: secondaryTextColor,
      ),
      labelSmall: AppTypography.labelSmall.copyWith(color: secondaryTextColor),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: textTheme,
      extensions: [customColors],
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: scaffoldBg,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: scaffoldBg,
              ),
        iconTheme: IconThemeData(color: primaryTextColor),
        titleTextStyle: AppTypography.headlineMedium.copyWith(
          color: primaryTextColor,
          fontWeight: FontWeight.w700,
        ),
      ),

      cardTheme: CardThemeData(
        color: customColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderLg,
          side: BorderSide(color: customColors.cardBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          textStyle: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.md,
          ),
          side: BorderSide(color: colorScheme.outline, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          textStyle: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
          textStyle: AppTypography.labelLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: customColors.surfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: isDark
              ? AppColors.darkTextTertiary
              : AppColors.lightTextTertiary,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: customColors.cardBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: customColors.cardBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
