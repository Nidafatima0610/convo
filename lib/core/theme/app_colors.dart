import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand Identity Colors
  static const Color primary = Color(0xFF5B4DFF);
  static const Color primaryLight = Color(0xFF7B70FF);
  static const Color primaryDark = Color(0xFF4335E0);

  // Secondary & Signal Mesh Accent
  static const Color accent = Color(0xFF00D2B4);
  static const Color accentLight = Color(0xFF33DDC3);
  static const Color accentDark = Color(0xFF00A890);

  // Creative & Feature Accents
  static const Color accentPurple = Color(0xFF7E3AF2);
  static const Color amberGlow = Color(0xFFFF9F43);
  static const Color coralGlow = Color(0xFFFF5376);
  static const Color violetGlow = Color(0xFF8B5CF6);
  static const Color blueGlow = Color(0xFF3B82F6);

  // Functional Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Light Palette
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSecondary = Color(0xFFF1F5F9);
  static const Color lightSurfaceTertiary = Color(0xFFE2E8F0);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderSubtle = Color(0xFFEEF2F6);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextTertiary = Color(0xFF94A3B8);

  // Dark Palette
  static const Color darkBackground = Color(0xFF090D16);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkSurfaceSecondary = Color(0xFF192233);
  static const Color darkSurfaceTertiary = Color(0xFF222E44);
  static const Color darkBorder = Color(0xFF1F293D);
  static const Color darkBorderSubtle = Color(0xFF161E2E);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);

  // Gradients
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primary, Color(0xFF7E3AF2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient meshGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, Color(0xFF0284C7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [amberGlow, coralGlow],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
