import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

import 'level_data.dart';

class LevelsRepository {
  static const _jsonPath = 'assets/data/levels.json';
  final Random _random = Random();

  List<LevelData> _levels = [];
  List<LevelData> get levels => _levels;

  Future<void> load() async {
    final raw = await rootBundle.loadString(_jsonPath);
    final List<dynamic> data = jsonDecode(raw) as List<dynamic>;
    _levels = data
        .map((e) => LevelData.fromJson(e as Map<String, dynamic>))
        .toList();
    _levels.shuffle(_random); // YENİ: her açılışta farklı sırayla gelsin
  }

  /// Doğru cevabı da içeren, karıştırılmış [count] şıklık liste.
  /// Yanlış şıklar öncelikle aynı kategoriden seçilir.
  List<String> buildOptions(LevelData level, {int count = 3}) {
    final sameCategory =
        _levels
            .where(
              (l) =>
                  l.category == level.category &&
                  l.correctAnswer != level.correctAnswer,
            )
            .map((l) => l.correctAnswer)
            .toSet()
            .toList()
          ..shuffle(_random);

    final otherCategory =
        _levels
            .where(
              (l) =>
                  l.category != level.category &&
                  l.correctAnswer != level.correctAnswer,
            )
            .map((l) => l.correctAnswer)
            .toSet()
            .toList()
          ..shuffle(_random);

    final wrongOptions = <String>[...sameCategory.take(count - 1)];
    if (wrongOptions.length < count - 1) {
      wrongOptions.addAll(
        otherCategory.take((count - 1) - wrongOptions.length),
      );
    }

    final options = [level.correctAnswer, ...wrongOptions];
    options.shuffle(_random);
    return options;
  }
}
