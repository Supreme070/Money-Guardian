import 'package:flutter/material.dart';

class LightColor {
  // Brand Identity: Secure Luxury
  // ---------------------------------------------------------------------------
  
  // Primary Colors
  static const Color guardianCharcoal = Color(0xFF121212); // Background
  static const Color sovereignGold = Color(0xFFCEA734);    // Primary/Accent
  static const Color sovereignGoldHighlight = Color(0xFFD3AC2C); // Hover/Gradient
  
  // Secondary & Functional
  static const Color platinum = Color(0xFFE0E0E0);         // Primary Text
  static const Color slate = Color(0xFF333232);            // Surface/Cards
  static const Color signalGreen = Color(0xFF00E676);      // Success (Android Green)
  static const Color alertRed = Color(0xFFCF6679);         // Error (Material Error)
  static const Color warningOrange = Color(0xFFFFB74D);    // Warning

  // ---------------------------------------------------------------------------
  // Mappings for Backward Compatibility (Refactoring Target)
  // ---------------------------------------------------------------------------

  static const Color background = guardianCharcoal;
  static const Color titleTextColor = platinum;
  static const Color subTitleTextColor = Color(0xFFB0B0B0); // Slightly dimmer platinum

  static const Color navyBlue1 = sovereignGold; // Mapping old primary to new primary
  static const Color navyBlue2 = slate;         // Mapping old secondary to surface

  static const Color yellow = sovereignGold;
  static const Color orange = warningOrange;
  static const Color grey = Color(0xFF9E9E9E);
  static const Color lightGrey = slate;         // Surfaces are now dark slate
  
  static const Color black = Colors.white;      // In dark mode, "black" text is white
  static const Color white = guardianCharcoal;  // In dark mode, "white" backgrounds are dark

  // Semantic mappings
  static const Color accent = sovereignGold;
  static const Color safe = signalGreen;
  static const Color freeze = alertRed;

  // Status colors (for Daily Pulse traffic light)
  static const Color success = signalGreen;       // SAFE status
  static const Color warning = warningOrange;     // CAUTION status
  static const Color caution = warningOrange;     // Alias for warning
  static const Color danger = alertRed;           // FREEZE/error status

  // Additional greys
  static const Color darkgrey = Color(0xFF666666);

  // Gold variants for gradients
  static const Color yellow2 = Color(0xFFB8941F);  // Darker gold for gradients

  // Blue variants (for decorative elements in cards)
  static const Color lightBlue1 = Color(0x22CEA734); // Translucent gold
  static const Color lightBlue2 = Color(0x11CEA734); // More translucent gold
}
