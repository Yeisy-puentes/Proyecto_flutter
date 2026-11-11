import 'package:flutter/material.dart';

/// Design tokens de Interfajas: los MISMOS colores de la app web
/// (src/styles/01-variables.css del proyecto Angular).
class AppColors {
  // ---- Marca ----
  static const navyDarkest = Color(0xFF172554); // fondo del logo en el menú
  static const navy = Color(0xFF1E3A8A); // color principal de marca
  static const blue = Color(0xFF2563EB); // azul de acción / links
  static const blueDark = Color(0xFF1D4ED8);
  static const blueLight = Color(0xFF3B82F6);
  static const cyan = Color(0xFF06B6D4);
  static const cyanDark = Color(0xFF0891B2);
  static const loginDeep = Color(0xFF0B3FB8);
  static const loginLight = Color(0xFFEAF3FF);

  // ---- Grises (slate) ----
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);

  // ---- Semánticos ----
  static const yellow50 = Color(0xFFFEFCE8);
  static const yellow100 = Color(0xFFFEF9C3);
  static const yellow200 = Color(0xFFFEF08A);
  static const yellow400 = Color(0xFFFACC15);
  static const yellow700 = Color(0xFFA16207);
  static const yellow800 = Color(0xFF854D0E);
  static const amber50 = Color(0xFFFFFBEB);
  static const amber700 = Color(0xFFB45309);

  static const green50 = Color(0xFFF0FDF4);
  static const green100 = Color(0xFFDCFCE7);
  static const green200 = Color(0xFFBBF7D0);
  static const green500 = Color(0xFF22C55E);
  static const green600 = Color(0xFF16A34A);
  static const green700 = Color(0xFF15803D);
  static const green800 = Color(0xFF166534);
  static const emerald600 = Color(0xFF059669);

  static const blue50 = Color(0xFFEFF6FF);
  static const blue100 = Color(0xFFDBEAFE);
  static const blue200 = Color(0xFFBFDBFE);
  static const blue300 = Color(0xFF93C5FD);
  static const blue500 = Color(0xFF3B82F6);
  static const blue600 = Color(0xFF2563EB);
  static const blue700 = Color(0xFF1D4ED8);
  static const blue800 = Color(0xFF1E40AF);

  static const red50 = Color(0xFFFEF2F2);
  static const red100 = Color(0xFFFEE2E2);
  static const red200 = Color(0xFFFECACA);
  static const red300 = Color(0xFFFCA5A5);
  static const red500 = Color(0xFFEF4444);
  static const red600 = Color(0xFFDC2626);
  static const red700 = Color(0xFFB91C1C);
  static const red800 = Color(0xFF991B1B);

  static const orange50 = Color(0xFFFFF7ED);
  static const orange100 = Color(0xFFFFEDD5);
  static const orange200 = Color(0xFFFED7AA);
  static const orange300 = Color(0xFFFDBA74);
  static const orange500 = Color(0xFFF97316);
  static const orange700 = Color(0xFFC2410C);

  static const purple50 = Color(0xFFFAF5FF);
  static const purple100 = Color(0xFFF3E8FF);
  static const purple200 = Color(0xFFE9D5FF);
  static const purple400 = Color(0xFFC084FC);
  static const purple500 = Color(0xFFA855F7);
  static const purple600 = Color(0xFF9333EA);
  static const purple700 = Color(0xFF7E22CE);
  static const purple800 = Color(0xFF6B21A8);

  static const cyan50 = Color(0xFFECFEFF);
  static const white = Colors.white;
}

/// Radios de la web (--radius-*).
class AppRadius {
  static const sm = 6.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const xl = 16.0;
  static const xxl = 20.0;
}

/// Sombras de la web (--shadow-*).
class AppShadows {
  static const sm = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const md = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 6, spreadRadius: -1, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x1A000000), blurRadius: 4, spreadRadius: -2, offset: Offset(0, 2)),
  ];
  static const xxl = [
    BoxShadow(color: Color(0x40000000), blurRadius: 50, spreadRadius: -12, offset: Offset(0, 25)),
  ];
}

/// Degradado de los encabezados (navy → azul), igual que .card-header-gradient.
const kGradienteMarca = LinearGradient(
  colors: [AppColors.navy, AppColors.blue],
);

class AppTheme {
  static ThemeData get tema {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.navy,
        primary: AppColors.blue,
        secondary: AppColors.cyan,
        surface: AppColors.white,
      ),
      scaffoldBackgroundColor: AppColors.slate50,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.slate900,
        displayColor: AppColors.slate900,
      ),
      // .input de la web: borde slate-200, radio 12, foco azul 2px
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: const TextStyle(color: AppColors.slate400),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.blue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.red300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.red500, width: 2),
        ),
        prefixIconColor: AppColors.slate400,
      ),
      dividerColor: AppColors.slate100,
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
