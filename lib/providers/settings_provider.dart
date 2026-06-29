import 'package:flutter/material.dart';
import 'package:lore_keeper/utils/enum.dart';

class SettingsProvider extends ChangeNotifier {

  // Thème de l'application
  AppTheme appTheme = AppTheme.light;

  void setTheme(AppTheme theme) {
    appTheme = theme;
    notifyListeners();
  }
}