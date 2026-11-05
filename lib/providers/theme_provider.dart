import 'package:flutter/material.dart';

/// The app is light-only. Kept as a (very small) ChangeNotifier because main.dart's
/// MultiProvider and MaterialApp.themeMode still reference it.
/// (The old festival / Diwali switches have been removed completely.)
class ThemeProvider extends ChangeNotifier {
  bool get isDark => false;
  ThemeMode get themeMode => ThemeMode.light;
  String get festivalBackgroundAsset => 'assets/diwali_bg.png';
}
