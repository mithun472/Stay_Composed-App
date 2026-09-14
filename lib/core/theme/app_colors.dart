import 'package:flutter/material.dart';

/// Brand palette for Stay Composed.
///
/// Design intent: a calm, trustworthy "campus security" feel rather than a
/// playful consumer-app palette — deep indigo as the anchor (trust,
/// institutional), teal as the secondary action color (TrueOwner /
/// verification), and a warm red reserved strictly for Blood Donation so
/// the two features stay visually distinct at a glance.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF2D3A8C); // deep indigo
  static const Color primaryDark = Color(0xFF1E2762);
  static const Color primaryLight = Color(0xFF5A69C4);

  // Secondary — TrueOwner accent
  static const Color trueOwner = Color(0xFF0F9B8E); // teal
  static const Color trueOwnerLight = Color(0xFFE3F6F4);

  // Secondary — Blood Donation accent
  static const Color blood = Color(0xFFC62828); // deep red
  static const Color bloodLight = Color(0xFFFCE8E8);

  // Neutrals
  static const Color background = Color(0xFFF7F8FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF0F1F8);
  static const Color border = Color(0xFFE2E4EF);

  static const Color textPrimary = Color(0xFF1A1C2E);
  static const Color textSecondary = Color(0xFF5C5F72);
  static const Color textDisabled = Color(0xFFA0A3B5);

  // Status
  static const Color success = Color(0xFF1E8E3E);
  static const Color successLight = Color(0xFFE6F4EA);
  static const Color warning = Color(0xFFB07A00);
  static const Color warningLight = Color(0xFFFFF3DD);
  static const Color error = Color(0xFFC62828);
  static const Color errorLight = Color(0xFFFCE8E8);
  static const Color info = Color(0xFF2D3A8C);
  static const Color infoLight = Color(0xFFE8EAFB);

  // Verification-specific status colors (used across TrueOwner states)
  static const Color pending = Color(0xFFB07A00);
  static const Color verified = Color(0xFF1E8E3E);
  static const Color disputed = Color(0xFFC62828);
  static const Color expired = Color(0xFF5C5F72);
}
