import 'package:flutter/material.dart';

class CodexPalette extends ThemeExtension<CodexPalette> {
  const CodexPalette({
    required this.sidebar,
    required this.sidebarBorder,
    required this.previewBase,
    required this.tagBackground,
    required this.tagSelected,
  });

  final Color sidebar;
  final Color sidebarBorder;
  final Color previewBase;
  final Color tagBackground;
  final Color tagSelected;

  @override
  CodexPalette copyWith({
    Color? sidebar,
    Color? sidebarBorder,
    Color? previewBase,
    Color? tagBackground,
    Color? tagSelected,
  }) {
    return CodexPalette(
      sidebar: sidebar ?? this.sidebar,
      sidebarBorder: sidebarBorder ?? this.sidebarBorder,
      previewBase: previewBase ?? this.previewBase,
      tagBackground: tagBackground ?? this.tagBackground,
      tagSelected: tagSelected ?? this.tagSelected,
    );
  }

  @override
  CodexPalette lerp(ThemeExtension<CodexPalette>? other, double t) {
    if (other is! CodexPalette) return this;
    return CodexPalette(
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      sidebarBorder: Color.lerp(sidebarBorder, other.sidebarBorder, t)!,
      previewBase: Color.lerp(previewBase, other.previewBase, t)!,
      tagBackground: Color.lerp(tagBackground, other.tagBackground, t)!,
      tagSelected: Color.lerp(tagSelected, other.tagSelected, t)!,
    );
  }
}

ThemeData buildCodexTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF8DA2FF),
        brightness: brightness,
      ).copyWith(
        primary: isDark ? const Color(0xFFAEBBFF) : const Color(0xFF4057C8),
        secondary: isDark ? const Color(0xFFD9B17E) : const Color(0xFF7E5930),
        surface: isDark ? const Color(0xFF111315) : const Color(0xFFF7F7F4),
        surfaceContainer: isDark
            ? const Color(0xFF17191C)
            : const Color(0xFFEDEDEA),
        surfaceContainerHigh: isDark
            ? const Color(0xFF202328)
            : const Color(0xFFE2E2DF),
        outline: isDark ? const Color(0xFF373B42) : const Color(0xFFC8C8C4),
      );

  final textTheme = Typography.material2021().black.apply(
    fontFamily: 'Inter',
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: textTheme,
    extensions: [
      CodexPalette(
        sidebar: isDark ? const Color(0xFF0F1113) : const Color(0xFFEEEEEB),
        sidebarBorder: isDark
            ? const Color(0xFF2E3238)
            : const Color(0xFFD6D6D2),
        previewBase: isDark ? const Color(0xFF0B0C0E) : const Color(0xFFE8E8E4),
        tagBackground: isDark
            ? const Color(0xFF1A1D21)
            : const Color(0xFFF2F2EF),
        tagSelected: isDark ? const Color(0xFF2B3146) : const Color(0xFFE3E7FF),
      ),
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.55)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: isDark
          ? const Color(0xFF1A1D21)
          : const Color(0xFFF2F2EF),
      selectedColor: isDark ? const Color(0xFF2B3146) : const Color(0xFFE3E7FF),
      checkmarkColor: scheme.primary,
      side: BorderSide(color: scheme.outline.withValues(alpha: 0.55)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: TextStyle(color: scheme.onSurface),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.7)),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: scheme.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.primary),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      thumbColor: scheme.primary,
      inactiveTrackColor: scheme.outline.withValues(alpha: 0.35),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outline.withValues(alpha: 0.5),
      space: 1,
      thickness: 1,
    ),
  );
}
