import 'package:flutter/material.dart';

// === Warna Utama Aplikasi ===
const Color kPrimary = Color.fromARGB(255, 65, 44, 110); // Ungu lembut premium
const Color kSecondary = Color(0xFFD9C2FF);
const Color kAccent = Color(0xFFF6EDFF);

// === Warna Teks ===
const Color kDarkText = Color(0xFF1E1E1E);
const Color kLightText = Color(0xFF777777);

// === Warna Pendukung ===
const Color kSuccess = Color(0xFF4CAF50);
const Color kError = Color(0xFFF44336);
const Color kBackground = Color(0xFFFDFBFF);

// === Tema Global ===
ThemeData appTheme = ThemeData(
  scaffoldBackgroundColor: kBackground,
  colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
  useMaterial3: true,
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: kDarkText, fontSize: 14),
    bodySmall: TextStyle(color: kLightText, fontSize: 12),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: kPrimary,
      side: const BorderSide(color: kPrimary),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
  ),
);
