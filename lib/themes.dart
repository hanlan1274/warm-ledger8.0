import 'package:flutter/material.dart';

class LedgerTheme {
  const LedgerTheme(
    this.id,
    this.name,
    this.description,
    this.background,
    this.surface,
    this.text,
    this.secondary,
    this.accent,
    this.soft, {
    this.dark = false,
    this.retro = false,
    this.colorful = false,
  });
  final String id, name, description;
  final Color background, surface, text, secondary, accent, soft;
  final bool dark, retro, colorful;
  static const all = [
    LedgerTheme(
      'warm',
      '温暖日常',
      '最初的米白界面，柔和、简洁',
      Color(0xFFFAF7EF),
      Color(0xFFFFFDF8),
      Color(0xFF3C3A34),
      Color(0xFF6F6A5E),
      Color(0xFF596C55),
      Color(0xFFEDEEDF),
    ),
    LedgerTheme(
      'lively',
      '缤纷奶油',
      '桃色资产卡、绿预算卡与淡紫目标卡',
      Color(0xFFF7F1E6),
      Color(0xFFFFFDF7),
      Color(0xFF3C3A34),
      Color(0xFF645C4D),
      Color(0xFF476751),
      Color(0xFFE3EADC),
      colorful: true,
    ),
    LedgerTheme(
      'blue',
      '晴空蓝',
      '浅灰白底，清爽蓝色',
      Color(0xFFF2F6FA),
      Color(0xFFFFFFFF),
      Color(0xFF293A4A),
      Color(0xFF5A6D80),
      Color(0xFF356A95),
      Color(0xFFE4EEF7),
    ),
    LedgerTheme(
      'night',
      '静谧夜间',
      '深色背景，降低夜间亮度',
      Color(0xFF171C22),
      Color(0xFF232B33),
      Color(0xFFE8ECED),
      Color(0xFFADB9C0),
      Color(0xFFA6C5B4),
      Color(0xFF303F3B),
      dark: true,
    ),
    LedgerTheme(
      'lcd',
      '液晶手账',
      '墨绿屏幕、等宽文字与轻浮雕卡片',
      Color(0xFFEEEFE5),
      Color(0xFFFAFBF2),
      Color(0xFF334733),
      Color(0xFF5A6A52),
      Color(0xFF405C40),
      Color(0xFFDEE7CE),
      retro: true,
    ),
  ];
  static LedgerTheme resolve(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => all.first);
  static LedgerTheme of(BuildContext context) =>
      resolve(Theme.of(context).extension<LedgerAppearance>()?.id ?? 'warm');
  Color get orange => dark ? const Color(0xFFE6B58C) : const Color(0xFFB87A4A);
  Color get purple => dark ? const Color(0xFFB7A8CD) : const Color(0xFF8B78A1);
  Color get gold => dark ? const Color(0xFFCEBB80) : const Color(0xFFA68B42);
  Color get onAccent =>
      dark ? const Color(0xFF17251E) : const Color(0xFFFFFFFF);
  Color get field => Color.lerp(background, surface, .55)!;
  Color get outline => Color.lerp(secondary, surface, .22)!;
  Color get divider => secondary.withValues(alpha: .18);
  TextStyle amountStyle(double size, {Color? color}) => TextStyle(
    fontFamily: retro ? 'monospace' : 'Manrope',
    fontFamilyFallback: const ['LedgerSans'],
    fontSize: size,
    fontWeight: FontWeight.w600,
    color: color ?? text,
    fontFeatures: const [FontFeature.tabularFigures()],
    letterSpacing: -.6,
    height: 1.25,
  );
  Color get onBudget => const Color(0xFFFFFDF3);
  List<Color> get assetGradient => colorful
      ? const [Color(0xFFECD3AD), Color(0xFFF7E9CF), Color(0xFFE3E8CF)]
      : [soft, surface];
  List<Color> get budgetGradient => retro
      ? const [Color(0xFF304B3B), Color(0xFF203B2E)]
      : dark
      ? const [Color(0xFF365247), Color(0xFF294037)]
      : [accent, Color.lerp(accent, const Color(0xFF000000), .2)!];
  Color get budgetText => retro ? const Color(0xFFC4D7A3) : onBudget;
  Color get goalSurface => colorful ? const Color(0xFFEDE8F2) : soft;
  ThemeData get data {
    final brightness = dark ? Brightness.dark : Brightness.light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
          surface: surface,
        ).copyWith(
          primary: accent,
          onPrimary: onAccent,
          onSurface: text,
          onSurfaceVariant: secondary,
          outline: outline,
          outlineVariant: divider,
        );
    final baseText = (dark ? ThemeData.dark() : ThemeData.light()).textTheme
        .apply(bodyColor: text, displayColor: text, fontFamily: 'LedgerSans');
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      extensions: [LedgerAppearance(id)],
      fontFamily: 'LedgerSans',
      textTheme: baseText.copyWith(
        bodyLarge: TextStyle(
          fontFamily: 'LedgerSans',
          fontSize: 16,
          height: 1.5,
          color: text,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'LedgerSans',
          fontSize: 14,
          height: 1.5,
          color: text,
        ),
        bodySmall: TextStyle(
          fontFamily: 'LedgerSans',
          fontSize: 12,
          height: 1.5,
          color: secondary,
        ),
        titleMedium: TextStyle(
          fontFamily: 'LedgerSans',
          fontSize: 16,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        hintStyle: TextStyle(color: secondary),
        labelStyle: TextStyle(color: secondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(retro ? 8 : 16),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(retro ? 8 : 16),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(retro ? 8 : 16),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'LedgerSans',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: BorderSide(color: outline),
          foregroundColor: text,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: accent,
        ),
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 24),
      listTileTheme: ListTileThemeData(
        iconColor: secondary,
        textColor: text,
        titleTextStyle: TextStyle(
          fontFamily: 'LedgerSans',
          fontSize: 15,
          color: text,
          height: 1.5,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'LedgerSans',
          fontSize: 12,
          color: secondary,
          height: 1.5,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: text,
        contentTextStyle: TextStyle(fontFamily: 'LedgerSans', color: surface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: soft,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontFamily: 'LedgerSans', fontSize: 12, color: text),
        ),
      ),
    );
  }
}

class LedgerAppearance extends ThemeExtension<LedgerAppearance> {
  const LedgerAppearance(this.id);
  final String id;
  @override
  LedgerAppearance copyWith({String? id}) => LedgerAppearance(id ?? this.id);
  @override
  LedgerAppearance lerp(covariant LedgerAppearance? other, double t) =>
      t < .5 ? this : other ?? this;
}
