class GameConstants {
  // Spawn (Çıkma) Olasılıkları
  static const double chanceWhite = 0.60;
  static const double chanceFakeWhite = 0.82;
  static const double chanceRed = 0.985;

  // Boyut Ayarları
  static const double baseSquareSize = 42.0;
  static const double minSquareSize = 18.0;
  static const double sizeDecreasePerLevel = 0.20;

  // Hız Ayarları
  static const double baseSpeed = 140.0;
  static const double speedIncreasePerLevel = 4.0;
  static const double maxSpeed =
      350.0; // Oyunun ulaşabileceği en yüksek hız sınırı

  // Altın Kare Özel Hız Ayarları
  static const double goldBaseSpeed = 80.0;
  static const double goldSpeedIncreasePerLevel = 2.0;
  static const double goldMaxSpeed = 200.0;
}
