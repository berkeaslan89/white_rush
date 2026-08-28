import '../services/save_manager.dart';

class ScoreManager {
  final SaveManager saveManager = SaveManager();

  int score = 0;
  int bestScore = 0;
  int bestCombo = 0;

  // En son ulaşılan seviye/round (1-tabanlı). Resume'un temeli.
  int savedLevel = 1;

  Future<void> load() async {
    bestScore = await saveManager.loadBestScore();
    bestCombo = await saveManager.loadBestCombo();
    savedLevel = await saveManager.loadLevel();
    if (savedLevel < 1) savedLevel = 1;
  }

  Future<void> addPoints(int value) async {
    score += value;
    if (score > bestScore) {
      bestScore = score;
      await saveManager.saveBestScore(bestScore);
    }
  }

  Future<int> loadLevelForCategory(String category) {
    return saveManager.loadLevelForCategory(category);
  }

  Future<void> updateSavedLevelForCategory(
    String category,
    int roundsCompleted,
  ) async {
    final current = await saveManager.loadLevelForCategory(category);
    if (roundsCompleted + 1 > current) {
      await saveManager.saveLevelForCategory(category, roundsCompleted + 1);
    }
  }

  // Elmas serisi (currentCombo) her arttığında WhiteRushGame'den çağrılır.
  Future<void> registerCombo(int combo) async {
    if (combo > bestCombo) {
      bestCombo = combo;
      await saveManager.saveBestCombo(bestCombo);
    }
  }

  Future<void> updateSavedLevel(int roundsCompleted) async {
    if (roundsCompleted + 1 > savedLevel) {
      savedLevel = roundsCompleted + 1;
      await saveManager.saveLevel(savedLevel);
    }
  }

  void reset() {
    score = 0;
  }
}
