import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// Tek merkezi çeviri deposu. Yeni bir metin gerektiğinde tek yapman
/// gereken strings.json'a bir satır eklemek — kodun hiçbir yerine dokunmuyorsun.
class AppStrings {
  static Map<String, dynamic> _data = {};
  static String currentLang = 'tr';

  static Future<void> load() async {
    final raw = await rootBundle.loadString('assets/data/strings.json');
    _data = jsonDecode(raw) as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    currentLang = prefs.getString('appLang') ?? 'tr';
  }

  static Future<void> setLanguage(String lang) async {
    currentLang = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appLang', lang);
  }

  static String get(String key, [Map<String, String>? params]) {
    final entry = _data[key] as Map<String, dynamic>?;
    String text = (entry?[currentLang] ?? entry?['tr'] ?? key) as String;
    params?.forEach((k, v) {
      text = text.replaceAll('{$k}', v);
    });
    return text;
  }
}
