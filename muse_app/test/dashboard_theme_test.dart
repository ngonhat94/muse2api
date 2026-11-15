import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/app/studio_theme.dart';

void main() {
  test('Dashboard uses neutral surfaces and a warm navigation accent', () {
    expect(StudioColors.canvas, const Color(0xFF111113));
    expect(StudioColors.surface, const Color(0xFF19191C));
    expect(StudioColors.accent, const Color(0xFFF4A27C));
    expect(StudioTheme.dark.cardTheme.elevation, 0);
    expect(StudioTheme.dark.colorScheme.onSurfaceVariant, StudioColors.muted);
  });
}
