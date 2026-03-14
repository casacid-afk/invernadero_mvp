import 'package:flutter/material.dart';

/// Colores de texto para legibilidad (contraste alto en toda la app)
class AppColors {
  static const Color textPrimary = Color(0xFF1C1C1C);
  static const Color textSecondary = Color(0xFF424242);
  static const Color cardBorder = Color(0xFFE8E8E8);
  /// Fondo general: gris muy suave, ligeramente cálido
  static const Color scaffoldBackground = Color(0xFFF4F3F1);
}

/// Paleta pastel por tipo de módulo. Fondo suave + borde en la misma familia + acento para icono/título.
class PastelVariant {
  const PastelVariant({
    required this.background,
    required this.border,
    required this.accent,
  });
  final Color background;
  final Color border;
  final Color accent;
}

/// Colores pastel suaves para tarjetas y módulos (estética sobria, moderna, sin saturar).
class AppPastel {
  AppPastel._();

  /// Siembras: verde salvia muy suave
  static const PastelVariant siembras = PastelVariant(
    background: Color(0xFFEAF6EC),
    border: Color(0xFFC8E0CC),
    accent: Color(0xFF2E7D32),
  );

  /// Ventas / cobro / resumen económico: durazno o arena suave
  static const PastelVariant ventas = PastelVariant(
    background: Color(0xFFFFF1E8),
    border: Color(0xFFF5D9C8),
    accent: Color(0xFFBF6B3A),
  );

  /// Stock / movimientos / alertas: azul grisáceo suave
  static const PastelVariant stock = PastelVariant(
    background: Color(0xFFEEF4FB),
    border: Color(0xFFD4E2F0),
    accent: Color(0xFF3D6A9E),
  );

  /// Sugerencias / apoyo / info: lavanda o menta suave
  static const PastelVariant sugerencia = PastelVariant(
    background: Color(0xFFF3EEFB),
    border: Color(0xFFE2D8F0),
    accent: Color(0xFF5E4B7A),
  );

  /// Neutral: para accesos rápidos o módulos genéricos
  static const PastelVariant neutral = PastelVariant(
    background: Color(0xFFF7F6F5),
    border: Color(0xFFE8E6E4),
    accent: Color(0xFF5C5A58),
  );
}

/// Tema global de la app: tipografía legible, contraste alto, componentes coherentes.
/// Aplicado en MaterialApp para que todas las pantallas hereden estos estilos.
ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: Colors.green,
    brightness: Brightness.light,
    primary: Colors.green.shade700,
  ).copyWith(
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    surface: Colors.white,
    inversePrimary: Colors.white,
  );

  final textTheme = _buildTextTheme(colorScheme);

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.scaffoldBackground,
    textTheme: textTheme,
    primaryTextTheme: textTheme,

    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.titleLarge!.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        fontSize: 20,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary, size: 24),
    ),

    cardTheme: CardThemeData(
      color: AppPastel.neutral.background,
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppPastel.neutral.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: const OutlineInputBorder(),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      labelStyle: TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
      floatingLabelStyle: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
      hintStyle: TextStyle(
        color: AppColors.textSecondary.withOpacity(0.9),
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      prefixIconColor: AppColors.textSecondary,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        minimumSize: const Size(64, 48),
        textStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        minimumSize: const Size(64, 48),
        textStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        minimumSize: const Size(64, 48),
        textStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        minimumSize: const Size(48, 40),
        textStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),

    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      titleTextStyle: textTheme.bodyLarge!.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        fontSize: 16,
      ),
      subtitleTextStyle: textTheme.bodyMedium!.copyWith(
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        fontSize: 14,
      ),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      unselectedLabelStyle: textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        color: AppColors.textSecondary,
      ),
    ),

    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      textStyle: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
    ),
  );
}

TextTheme _buildTextTheme(ColorScheme colorScheme) {
  const Color primary = AppColors.textPrimary;
  const Color secondary = AppColors.textSecondary;

  return TextTheme(
    displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: primary),
    displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: primary),
    displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: primary),
    headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: primary),
    headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: primary),
    headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: primary),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: primary),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: primary),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primary),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: primary),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: secondary),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: secondary),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: secondary),
  );
}
