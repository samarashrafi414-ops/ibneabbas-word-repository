// پریمیم ڈیزائن: deep navy + vivid green، بڑے گول کارڈز (24px)، floating nav
import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF0A1F33);
  static const navyDeep = Color(0xFF07182B);
  static const navyPanel = Color(0xFF0E2A47);
  static const green = Color(0xFF35C759);
  static const greenBright = Color(0xFF4ADE80);
  static const greenDark = Color(0xFF0A5C36);
  static const bg = Color(0xFFF4F7F5);
  static const ink = Color(0xFF142238);
  static const inkSoft = Color(0xFF5A6B82);
  static const gold = Color(0xFFD9A441);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.green,
      primary: AppColors.greenDark,
      secondary: AppColors.green,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'Noto Nastaliq Urdu',
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shadowColor: AppColors.navy.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.green,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18))),
    ),
    dialogTheme: DialogTheme(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD8E2DC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD8E2DC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.green, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// گہرا navy پینل (ہیڈر/کارڈ) — reference تصویر کا خمیدہ گہرا انداز
class NavyPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const NavyPanel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20)});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navyDeep],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: AppColors.navy.withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}
