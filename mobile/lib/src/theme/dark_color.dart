import 'package:flutter/material.dart';

/// Dark mode color palette for Money Guardian.
/// Mirrors the [LightColor] API so widgets can switch between them.
class DarkColor {
  // Brand Colors — dark variants
  // ---------------------------------------------------------------------------

  // Primary Colors
  static const Color navyBlue = Color(0xFF0D1B2E);          // Deeper navy for dark mode
  static const Color accentBlue = Color(0xFF4D72FF);        // Slightly brighter accent for dark bg
  static const Color secondaryBlue = Color(0xFF4466E5);     // Brighter secondary for contrast
  static const Color cardBackground = Color(0xFF1A2332);    // Dark card surfaces
  static const Color mutedBlue = Color(0xFF7B8FA6);         // Slightly brighter muted for dark bg

  // Gold / Highlight
  static const Color gold = Color(0xFFFBBD5C);              // Same gold — high contrast on dark
  static const Color goldDark = Color(0xFFE7AD03);          // Same hover gold

  // Backgrounds & Surfaces
  static const Color appBackground = Color(0xFF0F1419);     // True dark background
  static const Color surfaceColor = Color(0xFF1C2530);      // Elevated surfaces

  // Text
  static const Color textDark = Color(0xFFF0F2F5);          // Inverted — light headlines
  static const Color textBody = Color(0xFFAEB5BD);          // Mid-tone body text
  static const Color textMuted = Color(0xFF5F6B78);         // Dimmed placeholders
  static const Color textBlack = Color(0xFFF7F8FA);         // Strong emphasis (light)

  // Status Colors (Daily Pulse) — same, they read well on dark
  static const Color statusSafe = Color(0xFF22C55E);
  static const Color statusCaution = Color(0xFFFBBD5C);
  static const Color statusFreeze = Color(0xFFEF4444);

  // ---------------------------------------------------------------------------
  // Semantic Aliases
  // ---------------------------------------------------------------------------

  static const Color background = appBackground;
  static const Color titleTextColor = textDark;
  static const Color subTitleTextColor = textBody;
  static const Color primary = navyBlue;
  static const Color accent = accentBlue;
  static const Color navyBlue1 = navyBlue;
  static const Color navyBlue2 = secondaryBlue;
  static const Color yellow = gold;
  static const Color yellow2 = goldDark;
  static const Color sovereignGold = gold;
  static const Color grey = mutedBlue;
  static const Color darkgrey = mutedBlue;
  static const Color lightGrey = surfaceColor;
  static const Color black = textBlack;
  static const Color white = appBackground;
  static const Color orange = statusCaution;
  static const Color safe = statusSafe;
  static const Color success = statusSafe;
  static const Color caution = statusCaution;
  static const Color warning = statusCaution;
  static const Color freeze = statusFreeze;
  static const Color danger = statusFreeze;
  static const Color textPrimary = textDark;
  static const Color textSecondary = textBody;
  static const Color textTertiary = textMuted;
  static const Color surface = surfaceColor;
  static const Color slate = surfaceColor;
  static const Color divider = surfaceColor;
  static const Color primaryDark = goldDark;
  static const Color lightBlue1 = Color(0x224D72FF);
  static const Color lightBlue2 = Color(0x114D72FF);
}
