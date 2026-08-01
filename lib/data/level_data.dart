class LevelData {
  final String imagePath;
  final String correctAnswer;
  final String category;

  LevelData({
    required this.imagePath,
    required this.correctAnswer,
    required this.category,
  });

  factory LevelData.fromJson(Map<String, dynamic> json) {
    return LevelData(
      imagePath: json['imagePath'] as String,
      correctAnswer: json['correctAnswer'] as String,
      category: json['category'] as String,
    );
  }
}
