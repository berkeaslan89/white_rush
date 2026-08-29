class LevelData {
  final String imagePath;
  final Map<String, String> correctAnswer; // {"tr":..., "en":..., "ru":...}
  final String category;

  LevelData({
    required this.imagePath,
    required this.correctAnswer,
    required this.category,
  });

  factory LevelData.fromJson(Map<String, dynamic> json) {
    final raw = json['correctAnswer'];
    Map<String, String> answerMap;
    if (raw is Map) {
      answerMap = raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    } else {
      final s = raw.toString();
      answerMap = {"tr": s, "en": s, "ru": s};
    }
    return LevelData(
      imagePath: json['imagePath'] as String,
      correctAnswer: answerMap,
      category: json['category'] as String,
    );
  }

  String answerFor(String lang) {
    return correctAnswer[lang] ??
        correctAnswer['en'] ??
        correctAnswer.values.first;
  }
}
