import 'package:flutter/material.dart';

class AppColors {
  // Brand & Accent Colors (Ultra-Modern Indigo / Dark Slate / Emerald)
  static const Color primary = Color(0xFF0F172A);          // Deep Midnight Slate
  static const Color primaryBrand = Color(0xFF4F46E5);     // Electric Indigo Accent
  static const Color primaryLight = Color(0xFF6366F1);     // Bright Iris
  static const Color secondary = Color(0xFF0EA5E9);        // Sky Cyan
  static const Color emerald = Color(0xFF10B981);          // Vibrant Emerald Green
  static const Color teal = Color(0xFF0D9488);             // Clean Teal
  static const Color accent = Color(0xFFF43F5E);           // Rose Accent

  // Background & Surfaces
  static const Color background = Color(0xFFF8FAFC);       // Enterprise Slate-50 Canvas
  static const Color surface = Color(0xFFFFFFFF);          // Crisp White
  static const Color surfaceSubtle = Color(0xFFF1F5F9);    // Muted Slate-100 Container / Table Header
  static const Color surfaceVariant = Color(0xFFE2E8F0);   // Slate-200
  static const Color border = Color(0xFFE2E8F0);           // Clean 1px Card Border
  static const Color borderStrong = Color(0xFFCBD5E1);     // Input & Active Control Border (Slate-300)
  static const Color cardBorder = Color(0xFFE2E8F0);       // Alias for Card Border
  static const Color surfaceDark = Color(0xFF1E293B);      // Slate-800 Card
  static const Color primaryBrandSoft = Color(0xFFEEF2FF); // Soft Indigo Tint

  // Typography
  static const Color textPrimary = Color(0xFF0F172A);      // Slate-900 High Contrast
  static const Color textSecondary = Color(0xFF475569);    // Slate-600
  static const Color textMuted = Color(0xFF64748B);        // Slate-500

  // Semantic Status Colors
  static const Color success = Color(0xFF10B981);          // Green
  static const Color successBg = Color(0xFFF0FDF4);
  static const Color successBorder = Color(0xFFBBF7D0);
  static const Color successText = Color(0xFF15803D);

  static const Color warning = Color(0xFFF59E0B);          // Amber
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color warningBorder = Color(0xFFFDE68A);
  static const Color warningText = Color(0xFFB45309);

  static const Color error = Color(0xFFEF4444);            // Red
  static const Color errorBg = Color(0xFFFEF2F2);
  static const Color errorBorder = Color(0xFFFECACA);
  static const Color errorText = Color(0xFFB91C1C);

  static const Color info = Color(0xFF3B82F6);             // Blue
  static const Color infoBg = Color(0xFFEFF6FF);
  static const Color infoBorder = Color(0xFFBFDBFE);
  static const Color infoText = Color(0xFF1D4ED8);

  // Premium Gradients (Preserved for Brand Identity)
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient indigoGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient amberGradient = LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Micro-Elevation Shadows (Layered Flat 60fps - GPU friendly)
  static const List<BoxShadow> microShadow = [
    BoxShadow(
      color: Color(0x060F172A),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
}
