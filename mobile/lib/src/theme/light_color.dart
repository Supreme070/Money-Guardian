import 'package:flutter/material.dart';

class LightColor {
  // Brand Colors (from CLAUDE.md Brand Guidelines)
  // ---------------------------------------------------------------------------

  // Primary Colors
  static const Color navyBlue = Color(0xFF15294A);          // Primary brand
  static const Color accentBlue = Color(0xFF375EFD);        // CTAs, links, highlights
  static const Color secondaryBlue = Color(0xFF3554D3);     // Secondary actions
  static const Color cardBackground = Color(0xFF2C405B);    // Card surfaces (dark cards)
  static const Color mutedBlue = Color(0xFF6D7F99);         // Icons, secondary elements

  // Gold / Highlight
  static const Color gold = Color(0xFFFBBD5C);              // Warnings, highlights, premium
  static const Color goldDark = Color(0xFFE7AD03);          // Hover states, accents

  // Backgrounds & Surfaces
  static const Color appBackground = Color(0xFFFFFFFF);     // App background
  static const Color surfaceColor = Color(0xFFF1F1F3);      // Dividers, cards

  // Text
  static const Color textDark = Color(0xFF1D2635);          // Headlines, titles
  static const Color textBody = Color(0xFF797878);           // Body text, subtitles
  static const Color textMuted = Color(0xFFB9B9B9);         // Disabled, placeholders
  static const Color textBlack = Color(0xFF040405);          // Strong emphasis

  // Status Colors (Daily Pulse)
  static const Color statusSafe = Color(0xFF22C55E);        // SAFE - green
  static const Color statusCaution = Color(0xFFFBBD5C);     // CAUTION - gold
  static const Color statusFreeze = Color(0xFFEF4444);      // FREEZE - red

  // ---------------------------------------------------------------------------
  // Semantic Aliases (used across pages & widgets)
  // ---------------------------------------------------------------------------

  // Background
  static const Color background = appBackground;

  // Text hierarchy (legacy names)
  static const Color titleTextColor = textDark;
  static const Color subTitleTextColor = textBody;

  // Primary / Accent
  static const Color primary = navyBlue;
  static const Color accent = accentBlue;

  // Navy blue variants (legacy compatibility)
  static const Color navyBlue1 = navyBlue;
  static const Color navyBlue2 = secondaryBlue;

  // Gold aliases
  static const Color yellow = gold;
  static const Color yellow2 = goldDark;
  static const Color sovereignGold = gold;

  // Greys
  static const Color grey = mutedBlue;
  static const Color darkgrey = mutedBlue;
  static const Color lightGrey = surfaceColor;

  // Inverted/mapped colors
  static const Color black = textBlack;
  static const Color white = appBackground;
  static const Color orange = statusCaution;

  // Status colors
  static const Color safe = statusSafe;
  static const Color success = statusSafe;
  static const Color caution = statusCaution;
  static const Color warning = statusCaution;
  static const Color freeze = statusFreeze;
  static const Color danger = statusFreeze;

  // Text tiers (presentation layer)
  static const Color textPrimary = textDark;
  static const Color textSecondary = textBody;
  static const Color textTertiary = textMuted;

  // Surface / Cards
  static const Color surface = surfaceColor;
  static const Color slate = surfaceColor;
  static const Color divider = surfaceColor;

  // Primary dark (hover/gradient)
  static const Color primaryDark = goldDark;

  // Decorative translucent tints
  static const Color lightBlue1 = Color(0x22375EFD);       // Translucent accent
  static const Color lightBlue2 = Color(0x11375EFD);       // More translucent accent
}
