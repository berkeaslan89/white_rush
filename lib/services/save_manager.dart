import 'package:shared_preferences/shared_preferences.dart';

class SaveManager {
  static const _bestScoreKey = "best_score";
  static const _bestComboKey = "best_combo";
  static const _levelKey = "current_level";

  Future<void> saveBestScore(int score) async {
    final prefs = await SharedPreferences.getInstance();

    final current = prefs.getInt(_bestScoreKey) ?? 0;

    if (score > current) {
      await prefs.setInt(_bestScoreKey, score);
    }
  }

  Future<int> loadBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_bestScoreKey) ?? 0;
  }

  Future<void> saveBestCombo(int combo) async {
    final prefs = await SharedPreferences.getInstance();

    final current = prefs.getInt(_bestComboKey) ?? 0;

    if (combo > current) {
      await prefs.setInt(_bestComboKey, combo);
    }
  }

  Future<int> loadBestCombo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_bestComboKey) ?? 0;
  }

  Future<void> saveLevel(int level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_levelKey, level);
  }

  Future<int> loadLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_levelKey) ?? 1;
  }
}
