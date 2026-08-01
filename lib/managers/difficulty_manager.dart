class DifficultyManager {
  final int round;

  DifficultyManager(this.round);

  // Kare hızı (ÇOK DAHA YUMUŞAK VE İNSANCIL BİR EĞRİ)
  double get speed {
    // 0 - 9. bölümler: Başlangıç çok yavaş ve rahat (100'den 118'e çıkar)
    if (round < 10) {
      return 100.0 + (round * 2.0);
    }

    // 10 - 29. bölümler: Oyun hafifçe uyanıyor (120'den 158'e çıkar)
    if (round < 30) {
      return 120.0 + ((round - 10) * 2.0);
    }

    // 30 - 59. bölümler: Tatlı bir zorluk başlıyor (160'dan 203.5'e çıkar)
    if (round < 60) {
      return 160.0 + ((round - 30) * 1.5);
    }

    // 60+ bölümler: Artık usta işi. Ancak insan reflekslerini aşmamak için
    // hızı maksimum 280 civarında sınırlıyoruz (Eski kodda oyun başı 200'dü!)
    double maxSpeed = 205.0 + ((round - 60) * 1.0);

    // Hız asla 280'i geçmesin (Level 100+ olsa bile oynanabilir kalsın)
    return maxSpeed > 280.0 ? 280.0 : maxSpeed;
  }

  // Kare boyutu
  double get squareSize {
    if (round < 20) {
      return 45 - round * 0.4;
    }

    if (round < 50) {
      return 37 - (round - 20) * 0.2;
    }

    return 31;
  }

  // Aynı anda ekrandaki kare sayısı
  int get squareCount {
    if (round < 20) {
      return 18;
    }

    if (round < 40) {
      return 20;
    }

    if (round < 70) {
      return 22;
    }

    return 24;
  }

  // YENİ: Seviyeye göre "Ekranda Garanti Olması Gereken" minimum beyaz kare yüzdesi
  double get whiteQuota {
    if (round < 15)
      return 0.50; // İlk 15 bölüm ekranın YARISI (%50) kesin beyaz!
    if (round < 40) return 0.40; // 15-40 arası %40 beyaz
    return 0.30; // Zor seviyelerde %30 beyaz
  }

  // Beyaz kare ihtimali (Eskiden 0.60 ile başlıyordu, şimdi 0.35)
  // Beyaz kare ihtimali (Biraz artırdık ki çarpışmaları daha sık görelim)
  double get whiteChance {
    if (round < 15) return 0.55; // İlk bölümlerde %55 şansla beyaz
    if (round < 40) return 0.45;
    return 0.35;
  }

  // Fake White
  double get fakeChance {
    if (round < 30) return 0.18;
    if (round < 60) return 0.23;
    return 0.28;
  }

  // Elmas (Altın) Çıkma İhtimali
  double get goldChance {
    if (round < 30) return 0.08; // %5'ten %8'e çıkardık
    if (round < 60) return 0.10; // %6'dan %10'a çıkardık
    return 0.15; // %8'den %15'e çıkardık (Zor seviyelerde bol elmas)
  }
}
