import 'package:flutter/material.dart';

abstract final class StudioColors {
  static const canvas = Color(0xFF111113);
  static const surface = Color(0xFF19191C);
  static const raised = Color(0xFF232326);
  static const selected = Color(0xFF382923);
  static const accent = Color(0xFFF4A27C);
  static const text = Color(0xFFF2F2F3);
  static const muted = Color(0xFFB1B1BA);
  static const border = Color(0xFF38383F);
  static const success = Color(0xFF86D9AC);
}

abstract final class StudioTheme {
  static ThemeData get dark {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: StudioColors.accent,
          brightness: Brightness.dark,
          surface: StudioColors.surface,
        ).copyWith(
          primary: StudioColors.accent,
          onPrimary: StudioColors.canvas,
          onSurface: StudioColors.text,
          onSurfaceVariant: StudioColors.muted,
        );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: StudioColors.canvas,
      textTheme: base.textTheme.apply(
        bodyColor: StudioColors.text,
        displayColor: StudioColors.text,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: StudioColors.surface,
        hintStyle: const TextStyle(color: StudioColors.muted),
        errorMaxLines: 3,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.all(16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: .25),
      ),
      dividerTheme: const DividerThemeData(
        color: StudioColors.border,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: StudioColors.muted,
        textColor: StudioColors.muted,
        selectedColor: StudioColors.accent,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: StudioColors.surface,
        indicatorColor: StudioColors.selected,
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: StudioColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: StudioColors.border),
        ),
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 400),
      ),
    );
  }
}
