import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_enums.dart';

/// Patient-facing palette — warm, icon-and-color driven, for low-literacy users.
class PatientColors {
  static const Color primary = Color(0xFFE85D75);
  static const Color background = Color(0xFFFFF8F6);
}

/// ASHA-facing palette — a professional clinical-field-tool look.
/// Deliberately distinct from the patient palette: teal reads as
/// trustworthy/clinical without being cold, and risk colors are the
/// only saturated accents so they stay meaningful, not decorative.
class AshaColors {
  static const Color ink = Color(0xFF0F172A);
  static const Color inkMuted = Color(0xFF64748B);
  static const Color primary = Color(0xFF0D9488);
  static const Color primaryDark = Color(0xFF0F766E);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
}

/// Shared risk semantics — same three colors regardless of which
/// dashboard is showing them, since risk meaning must stay consistent.
class RiskColors {
  static const Color low = Color(0xFF16A34A);
  static const Color moderate = Color(0xFFEA580C);
  static const Color high = Color(0xFFDC2626);
}

// Kept for any existing code still referencing AppColors (patient screens).
class AppColors {
  static const Color primary = PatientColors.primary;
  static const Color background = PatientColors.background;
  static const Color riskLow = RiskColors.low;
  static const Color riskModerate = RiskColors.moderate;
  static const Color riskHigh = RiskColors.high;
  static const Color textPrimary = Color(0xFF2B2B2B);
  static const Color textSecondary = Color(0xFF6E6E6E);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 18, color: AppColors.textPrimary),
        bodyMedium: TextStyle(fontSize: 16, color: AppColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// A separate, professional theme for ASHA-facing screens.
  /// Uses Inter throughout — weight carries hierarchy, not color or emoji.
  static ThemeData get ashaTheme {
    final base = GoogleFonts.interTextTheme();
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AshaColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AshaColors.primary,
        primary: AshaColors.primary,
      ),
      textTheme: base.copyWith(
        headlineMedium: base.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: AshaColors.ink,
          fontSize: 22,
        ),
        titleMedium: base.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: AshaColors.ink,
        ),
        bodyMedium: base.bodyMedium?.copyWith(
          fontWeight: FontWeight.w400,
          color: AshaColors.inkMuted,
        ),
        labelLarge: base.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: AshaColors.inkMuted,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AshaColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AshaColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AshaColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AshaColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AshaColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

/// Maps Uswa's RiskLevel enum to color + label. No emoji here —
/// icon + color + text label carries the meaning instead.
extension RiskLevelX on RiskLevel {
  Color get color {
    switch (this) {
      case RiskLevel.low:
        return RiskColors.low;
      case RiskLevel.moderate:
        return RiskColors.moderate;
      case RiskLevel.high:
        return RiskColors.high;
    }
  }

  String get label {
    switch (this) {
      case RiskLevel.low:
        return 'Low risk';
      case RiskLevel.moderate:
        return 'Moderate risk';
      case RiskLevel.high:
        return 'High risk';
    }
  }

  IconData get icon {
    switch (this) {
      case RiskLevel.low:
        return Icons.check_circle_outline;
      case RiskLevel.moderate:
        return Icons.error_outline;
      case RiskLevel.high:
        return Icons.warning_amber_rounded;
    }
  }
}