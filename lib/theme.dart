import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ForgeSpacing {
  const ForgeSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double cardGap = 14;
  static const double screenTop = 22;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}

class ForgeTokens extends ThemeExtension<ForgeTokens> {
  const ForgeTokens({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accentTeal,
    required this.accentLime,
    required this.success,
    required this.warning,
    required this.error,
    required this.primaryGradient,
    required this.chartGradient,
    required this.energyGradient,
    required this.strainGradient,
    required this.recoveryGradient,
    required this.cardRadius,
    required this.heroRadius,
    required this.controlRadius,
    required this.pillRadius,
  });

  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accentTeal;
  final Color accentLime;
  final Color success;
  final Color warning;
  final Color error;
  final LinearGradient primaryGradient;
  final LinearGradient chartGradient;
  final LinearGradient energyGradient;
  final LinearGradient strainGradient;
  final LinearGradient recoveryGradient;
  final double cardRadius;
  final double heroRadius;
  final double controlRadius;
  final double pillRadius;

  static const dark = ForgeTokens(
    background: Color(0xFF061210),
    surface: Color(0xFF0D1B19),
    surfaceVariant: Color(0xFF132624),
    border: Color.fromRGBO(140, 255, 225, 0.13),
    textPrimary: Color(0xFFE8F5F1),
    textSecondary: Color(0xFF8AA8A1),
    textMuted: Color(0xFF8AA8A1),
    accentTeal: Color(0xFF62E3C8),
    accentLime: Color(0xFFD4F26E),
    success: Color(0xFF5BE08F),
    warning: Color(0xFFF2C14E),
    error: Color(0xFFEF6B5E),
    primaryGradient: LinearGradient(
      colors: [Color(0xFF62E3C8), Color(0xFFD4F26E)],
    ),
    chartGradient: LinearGradient(
      colors: [Color(0xFF6FB5FF), Color(0xFF62E3C8)],
    ),
    energyGradient: LinearGradient(
      colors: [Color(0xFFF2C14E), Color(0xFFF0925E)],
    ),
    strainGradient: LinearGradient(
      colors: [Color(0xFFF7C26A), Color(0xFFEF6B5E)],
    ),
    recoveryGradient: LinearGradient(
      colors: [Color(0xFFD9A8F5), Color(0xFF8F8CF0)],
    ),
    cardRadius: 26,
    heroRadius: 28,
    controlRadius: 16,
    pillRadius: 999,
  );

  static const light = ForgeTokens(
    background: Color(0xFFF3F7F5),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFE8EFEC),
    border: Color(0xFFC5D2CE),
    textPrimary: Color(0xFF13201D),
    textSecondary: Color(0xFF405750),
    textMuted: Color(0xFF526760),
    accentTeal: Color(0xFF007F73),
    accentLime: Color(0xFFB9E85A),
    success: Color(0xFF137A49),
    warning: Color(0xFF8A5700),
    error: Color(0xFFB3261E),
    primaryGradient: LinearGradient(
      colors: [Color(0xFF007F73), Color(0xFFB9E85A)],
    ),
    chartGradient: LinearGradient(
      colors: [Color(0xFF087D8D), Color(0xFF526FD3)],
    ),
    energyGradient: LinearGradient(
      colors: [Color(0xFF9B5D00), Color(0xFFC94F42)],
    ),
    strainGradient: LinearGradient(
      colors: [Color(0xFF9B5D00), Color(0xFFC94F42)],
    ),
    recoveryGradient: LinearGradient(
      colors: [Color(0xFF6650B5), Color(0xFFAB438D)],
    ),
    cardRadius: 24,
    heroRadius: 28,
    controlRadius: 16,
    pillRadius: 999,
  );

  @override
  ForgeTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accentTeal,
    Color? accentLime,
    Color? success,
    Color? warning,
    Color? error,
    LinearGradient? primaryGradient,
    LinearGradient? chartGradient,
    LinearGradient? energyGradient,
    LinearGradient? strainGradient,
    LinearGradient? recoveryGradient,
    double? cardRadius,
    double? heroRadius,
    double? controlRadius,
    double? pillRadius,
  }) {
    return ForgeTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accentTeal: accentTeal ?? this.accentTeal,
      accentLime: accentLime ?? this.accentLime,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      primaryGradient: primaryGradient ?? this.primaryGradient,
      chartGradient: chartGradient ?? this.chartGradient,
      energyGradient: energyGradient ?? this.energyGradient,
      strainGradient: strainGradient ?? this.strainGradient,
      recoveryGradient: recoveryGradient ?? this.recoveryGradient,
      cardRadius: cardRadius ?? this.cardRadius,
      heroRadius: heroRadius ?? this.heroRadius,
      controlRadius: controlRadius ?? this.controlRadius,
      pillRadius: pillRadius ?? this.pillRadius,
    );
  }

  @override
  ForgeTokens lerp(ThemeExtension<ForgeTokens>? other, double t) {
    if (other is! ForgeTokens) return this;
    return ForgeTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accentTeal: Color.lerp(accentTeal, other.accentTeal, t)!,
      accentLime: Color.lerp(accentLime, other.accentLime, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      primaryGradient: _lerpGradient(primaryGradient, other.primaryGradient, t),
      chartGradient: _lerpGradient(chartGradient, other.chartGradient, t),
      energyGradient: _lerpGradient(energyGradient, other.energyGradient, t),
      strainGradient: _lerpGradient(strainGradient, other.strainGradient, t),
      recoveryGradient: _lerpGradient(
        recoveryGradient,
        other.recoveryGradient,
        t,
      ),
      cardRadius: cardRadius + (other.cardRadius - cardRadius) * t,
      heroRadius: heroRadius + (other.heroRadius - heroRadius) * t,
      controlRadius: controlRadius + (other.controlRadius - controlRadius) * t,
      pillRadius: pillRadius + (other.pillRadius - pillRadius) * t,
    );
  }

  static LinearGradient _lerpGradient(
    LinearGradient a,
    LinearGradient b,
    double t,
  ) {
    return LinearGradient(
      colors: List.generate(
        a.colors.length,
        (index) => Color.lerp(a.colors[index], b.colors[index], t)!,
      ),
      begin: t < 0.5 ? a.begin : b.begin,
      end: t < 0.5 ? a.end : b.end,
    );
  }
}

class AppThemePalette extends ThemeExtension<AppThemePalette> {
  const AppThemePalette({
    required this.scaffoldBackground,
    required this.cardBackground,
    required this.heroGradient,
    required this.primaryText,
    required this.secondaryText,
    required this.statusCompleteFg,
    required this.statusCompleteBg,
    required this.statusProgressFg,
    required this.statusProgressBg,
    required this.statusIncompleteFg,
    required this.statusIncompleteBg,
    required this.cardRadius,
    required this.cardPadding,
  });

  final Color scaffoldBackground;
  final Color cardBackground;
  final LinearGradient heroGradient;
  final Color primaryText;
  final Color secondaryText;
  final Color statusCompleteFg;
  final Color statusCompleteBg;
  final Color statusProgressFg;
  final Color statusProgressBg;
  final Color statusIncompleteFg;
  final Color statusIncompleteBg;
  final double cardRadius;
  final double cardPadding;

  static const AppThemePalette dark = AppThemePalette(
    scaffoldBackground: Color(0xFF061210),
    cardBackground: Color(0xFF0D1B19),
    heroGradient: LinearGradient(
      colors: [Color(0xFF86ECD2), Color(0xFFDCF67F)],
    ),
    primaryText: Color(0xFFE8F5F1),
    secondaryText: Color(0xFF8AA8A1),
    statusCompleteFg: Color(0xFF5BE08F),
    statusCompleteBg: Color(0xFF173326),
    statusProgressFg: Color(0xFFF2C14E),
    statusProgressBg: Color(0xFF382B17),
    statusIncompleteFg: Color(0xFFEF6B5E),
    statusIncompleteBg: Color(0xFF3B2020),
    cardRadius: 24,
    cardPadding: ForgeSpacing.md,
  );

  static const AppThemePalette light = AppThemePalette(
    scaffoldBackground: Color(0xFFF3F7F5),
    cardBackground: Color(0xFFFFFFFF),
    heroGradient: LinearGradient(
      colors: [Color(0xFF007F73), Color(0xFFB9E85A)],
    ),
    primaryText: Color(0xFF13201D),
    secondaryText: Color(0xFF405750),
    statusCompleteFg: Color(0xFF137A49),
    statusCompleteBg: Color(0xFFE1F3E8),
    statusProgressFg: Color(0xFF8A5700),
    statusProgressBg: Color(0xFFFFF0D2),
    statusIncompleteFg: Color(0xFFB3261E),
    statusIncompleteBg: Color(0xFFFBE9E7),
    cardRadius: 24,
    cardPadding: ForgeSpacing.md,
  );

  @override
  AppThemePalette copyWith({
    Color? scaffoldBackground,
    Color? cardBackground,
    LinearGradient? heroGradient,
    Color? primaryText,
    Color? secondaryText,
    Color? statusCompleteFg,
    Color? statusCompleteBg,
    Color? statusProgressFg,
    Color? statusProgressBg,
    Color? statusIncompleteFg,
    Color? statusIncompleteBg,
    double? cardRadius,
    double? cardPadding,
  }) {
    return AppThemePalette(
      scaffoldBackground: scaffoldBackground ?? this.scaffoldBackground,
      cardBackground: cardBackground ?? this.cardBackground,
      heroGradient: heroGradient ?? this.heroGradient,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      statusCompleteFg: statusCompleteFg ?? this.statusCompleteFg,
      statusCompleteBg: statusCompleteBg ?? this.statusCompleteBg,
      statusProgressFg: statusProgressFg ?? this.statusProgressFg,
      statusProgressBg: statusProgressBg ?? this.statusProgressBg,
      statusIncompleteFg: statusIncompleteFg ?? this.statusIncompleteFg,
      statusIncompleteBg: statusIncompleteBg ?? this.statusIncompleteBg,
      cardRadius: cardRadius ?? this.cardRadius,
      cardPadding: cardPadding ?? this.cardPadding,
    );
  }

  @override
  AppThemePalette lerp(ThemeExtension<AppThemePalette>? other, double t) {
    if (other is! AppThemePalette) return this;
    return AppThemePalette(
      scaffoldBackground: Color.lerp(
        scaffoldBackground,
        other.scaffoldBackground,
        t,
      )!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      heroGradient: _lerpGradient(heroGradient, other.heroGradient, t),
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      statusCompleteFg: Color.lerp(
        statusCompleteFg,
        other.statusCompleteFg,
        t,
      )!,
      statusCompleteBg: Color.lerp(
        statusCompleteBg,
        other.statusCompleteBg,
        t,
      )!,
      statusProgressFg: Color.lerp(
        statusProgressFg,
        other.statusProgressFg,
        t,
      )!,
      statusProgressBg: Color.lerp(
        statusProgressBg,
        other.statusProgressBg,
        t,
      )!,
      statusIncompleteFg: Color.lerp(
        statusIncompleteFg,
        other.statusIncompleteFg,
        t,
      )!,
      statusIncompleteBg: Color.lerp(
        statusIncompleteBg,
        other.statusIncompleteBg,
        t,
      )!,
      cardRadius: cardRadius + (other.cardRadius - cardRadius) * t,
      cardPadding: cardPadding + (other.cardPadding - cardPadding) * t,
    );
  }

  static LinearGradient _lerpGradient(
    LinearGradient a,
    LinearGradient b,
    double t,
  ) {
    return LinearGradient(
      colors: List.generate(
        a.colors.length,
        (index) => Color.lerp(a.colors[index], b.colors[index], t)!,
      ),
      begin: t < 0.5 ? a.begin : b.begin,
      end: t < 0.5 ? a.end : b.end,
    );
  }
}

class ForgeTheme {
  static const Color seedColor = Color(0xFF62E3C8);

  static ThemeMode themeModeFromStorageValue(Object? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      case null:
      default:
        return ThemeMode.system;
    }
  }

  static String storageValueForThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static final ThemeData lightTheme = _buildTheme(
    brightness: Brightness.light,
    tokens: ForgeTokens.light,
    legacyPalette: AppThemePalette.light,
  );

  static final ThemeData darkTheme = _buildTheme(
    brightness: Brightness.dark,
    tokens: ForgeTokens.dark,
    legacyPalette: AppThemePalette.dark,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ForgeTokens tokens,
    required AppThemePalette legacyPalette,
  }) {
    final isDark = brightness == Brightness.dark;
    final onAccent = isDark ? const Color(0xFF06221C) : Colors.white;
    final baseTextTheme = GoogleFonts.figtreeTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );
    final textTheme = baseTextTheme
        .copyWith(
          displayLarge: GoogleFonts.bricolageGrotesque(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.8,
            height: 1.05,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          headlineLarge: GoogleFonts.bricolageGrotesque(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.64,
            height: 1.15,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          titleLarge: GoogleFonts.bricolageGrotesque(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            height: 1.25,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          bodyLarge: GoogleFonts.figtree(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
          bodyMedium: GoogleFonts.figtree(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
          labelLarge: GoogleFonts.figtree(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
          labelSmall: GoogleFonts.figtree(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        )
        .apply(bodyColor: tokens.textPrimary, displayColor: tokens.textPrimary)
        .copyWith(
          bodySmall: baseTextTheme.bodySmall?.copyWith(
            color: tokens.textSecondary,
            fontSize: 12,
            height: 1.4,
          ),
          labelSmall: GoogleFonts.figtree(
            color: tokens.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        );

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: tokens.accentTeal,
          brightness: brightness,
        ).copyWith(
          primary: tokens.accentTeal,
          onPrimary: onAccent,
          secondary: tokens.accentLime,
          onSecondary: const Color(0xFF102019),
          surface: tokens.surface,
          onSurface: tokens.textPrimary,
          error: tokens.error,
          onError: Colors.white,
          outline: tokens.border,
          outlineVariant: tokens.surfaceVariant,
          surfaceContainerHighest: tokens.surfaceVariant,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xFF070C0B)
          : tokens.background,
      canvasColor: tokens.background,
      cardColor: tokens.surface,
      dividerColor: tokens.border,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: tokens.background,
        foregroundColor: tokens.textPrimary,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: tokens.textPrimary, size: 24),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.cardRadius),
          side: BorderSide(color: tokens.border, width: 0.7),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ForgeSpacing.md,
          vertical: ForgeSpacing.sm,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: tokens.textMuted),
        labelStyle: textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.controlRadius),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.controlRadius),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.controlRadius),
          borderSide: BorderSide(color: tokens.accentTeal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.controlRadius),
          borderSide: BorderSide(color: tokens.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.controlRadius),
          borderSide: BorderSide(color: tokens.error, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: tokens.accentTeal,
          foregroundColor: onAccent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.controlRadius),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: tokens.accentTeal,
          foregroundColor: onAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.controlRadius),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: tokens.textPrimary,
          side: BorderSide(color: tokens.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.controlRadius),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: tokens.textSecondary,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.heroRadius),
          side: BorderSide(color: tokens.border),
        ),
      ),
      extensions: [tokens, legacyPalette],
    );
  }
}
