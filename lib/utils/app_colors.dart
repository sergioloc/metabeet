import 'package:flutter/material.dart';

/// Central place for all the app colors.
///
/// The palette follows a Windows 11 dark "Mica" look: cool blue-gray surfaces
/// with a subtle translucent tint layered over a backdrop, crisp 1px borders,
/// and the app's beet accent used on primary roles only.
abstract final class AppColors {
  /// Brand accent (beet/raspberry).
  static const Color accent = Color(0xFFB92A52);

  /// Subtle accent for gradients / highlights.
  static const Color accentSoft = Color(0xFFE0457B);

  // ---- Mica backdrop (the faint tinted base everything sits on) ----
  static const Color micaBackdrop = Color(0xFF202327);

  // ---- Surfaces ----
  static const Color surface = Color(0xFF282A2E);
  static const Color surfaceLow = Color(0xFF22252A);
  static const Color surfaceHigh = Color(0xFF303338);
  static const Color surfaceBright = Color(0xFF3A3D43);
  static const Color surfaceContainerLowest = Color(0xFF1E2024);
  static const Color surfaceContainerLow = Color(0xFF26292E);
  static const Color surfaceContainer = Color(0xFF2B2E33);
  static const Color surfaceContainerHigh = Color(0xFF32353B);
  static const Color surfaceContainerHighest = Color(0xFF3B3F46);
  static const Color surfaceDim = Color(0xFF1A1C20);

  // ---- Text ----
  static const Color onSurface = Color(0xFFF0EFED);
  static const Color onSurfaceVariant = Color(0xFFB7B5B0);
  static const Color onSurfaceMuted = Color(0xFF8E8E8B);

  // ---- Borders / outlines ----
  static const Color outline = Color(0xFF7A7F87);
  static const Color outlineVariant = Color(0xFF3C4046);
  static const Color outlineSubtle = Color(0xFF30343A);
  static const Color borderLight = Color(0xFF464A51);

  // ---- Selection / hover fills ----
  static const Color selectionFill = Color(0xFF4A2132);

  // Format accent colors.
  static const Color mp3 = Color(0xFFE8B35A);
  static const Color flac = Color(0xFF78A9E2);
  static const Color wav = Color(0xFF63C7CE);
  static const Color ogg = Color(0xFFB18BE2);
  static const Color aac = Color(0xFFE27AB0);
  static const Color m4a = Color(0xFF70C7A0);
  static const Color wma = Color(0xFF9BA7E8);
  static const Color aiff = Color(0xFFC7A27A);
}
