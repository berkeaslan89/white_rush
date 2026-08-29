import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/events.dart'; // BİR TEK BUNU EKLEDİN
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'package:flame/effects.dart';
import 'package:flame/collisions.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../components/fog_overlay.dart';
import '../components/moving_square.dart';
import '../managers/game_manager.dart';
import '../managers/score_manager.dart';
import '../managers/difficulty_manager.dart';
import '../models/square_type.dart';
import '../data/level_data.dart';
import '../data/levels_repository.dart';
import '../services/app_strings.dart';

class WhiteRushGame extends FlameGame with HasCollisionDetection {
  final random = Random();
  final scoreManager = ScoreManager();
  final gameManager = GameManager();
  final levelsRepository = LevelsRepository();
  List<LevelData> get gameLevels =>
      levelsRepository.byCategory(selectedCategory);
  List<String> currentOptions = [];
  // --- ULTIMATE GÜÇ BARI DEĞİŞKENLERİ ---
  double ultimatePower = 0.0;
  final double maxUltimatePower =
      100.0; // Barın tamamen dolması için gereken puan

  bool isFreezeActive = false; // Süper güç devrede mi?
  double freezeTimer = 0.0; // Ekranda yazacak olan 3 saniyelik sayaç

  late TextComponent scoreText;
  late TextComponent levelText;
  late TextComponent comboText;
  late SpriteComponent backgroundImage;
  late FogOverlay fogOverlay;

  int currentLevelIndex = 0;
  String selectedCategory = 'karakter';
  int tilesRevealedThisLevel = 0;
  int currentCombo = 0;
  int roundsCompleted = 0; // hiç sıfırlanmayan zorluk/resume sayacı
  int lastEarnedPoints = 0;

  bool get isGameOver => gameManager.gameOver;
  VoidCallback? onReturnToMenu;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  void update(double dt) {
    super.update(dt);

    // EĞER SÜPER GÜÇ AKTİFSE SÜREYİ AZALT
    if (isFreezeActive) {
      freezeTimer -= dt;
      if (freezeTimer <= 0) {
        // Süre Bitti! Normale dön.
        isFreezeActive = false;
        freezeTimer = 0.0;
        ultimatePower = 0.0;
      }
    }
  }

  DifficultyManager get difficulty => DifficultyManager(roundsCompleted);

  bool _soundOn = true;
  late AudioPool _tapPool;

  Future<void> _loadSoundPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _soundOn = prefs.getBool('soundOn') ?? true;
  }

  Future<void> refreshSoundPreference() async {
    await _loadSoundPreference();
  }

  void playSfx(String fileName) {
    if (!_soundOn) return;
    FlameAudio.play('$fileName.mp3');
  }

  Future<Sprite> _loadLevelSprite() async {
    final total = gameLevels.length;
    for (int attempt = 0; attempt < total; attempt++) {
      final idx = (currentLevelIndex + attempt) % total;
      final data = gameLevels[idx];
      try {
        final sprite = await loadSprite(data.imagePath);
        currentLevelIndex = idx;
        return sprite;
      } catch (e) {
        debugPrint('Resim eksik/bozuk, atlanıyor: ${data.imagePath}');
      }
    }
    throw Exception(
      'Bu kategoride yüklenebilir hiç resim yok: $selectedCategory',
    );
  }

  @override
  Future<void> onLoad() async {
    await _loadSoundPreference();
    await FlameAudio.audioCache.loadAll([
      'tap_correct.mp3',
      'diamond_collect.mp3',
      'combo_up.mp3',
      'mutation.mp3',
      'bomb_explode.mp3',
      'game_over.mp3',
      'level_complete.mp3',
      'ultimate_spawn.mp3',
      'ultimate_trigger.mp3',
    ]);
    _tapPool = await FlameAudio.createPool(
      'tap_correct.mp3',
      minPlayers: 4,
      maxPlayers: 8,
    );
    camera.viewfinder.anchor = Anchor.topLeft;
    await levelsRepository.load();
    await scoreManager.load();
    roundsCompleted =
        (await scoreManager.loadLevelForCategory(selectedCategory)) - 1;
    //roundsCompleted = 99; // test için level 100 yapma kodu

    currentLevelIndex = roundsCompleted % gameLevels.length;

    final sprite = await _loadLevelSprite();

    backgroundImage = SpriteComponent(sprite: sprite, size: size);
    add(backgroundImage);

    fogOverlay = FogOverlay(size: size);
    add(fogOverlay);

    add(HudPanel(position: Vector2(8, 8), size: Vector2(210, 100)));

    scoreText = TextComponent(
      text: "Puan: ${scoreManager.score}",
      position: Vector2(15, 15),
      priority: 100,
    );
    levelText = TextComponent(
      text: AppStrings.get('level_label', {
        'bölüm': '${currentLevelIndex + 1}',
      }),
      position: Vector2(15, 45),
      priority: 100,
    );

    // COMBO YAZISI AYARLANDI (Büyürken sağa doğru patlaması için Anchor.centerLeft yapıldı)
    comboText = TextComponent(
      text: AppStrings.get('combo_label', {'sayı': '0'}),
      position: Vector2(
        15,
        85,
      ), // Anchor değiştiği için konumu hafif aşağı alındı
      anchor: Anchor.centerLeft,
      priority: 100,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.orangeAccent,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    add(scoreText);
    add(levelText);
    add(comboText);

    overlays.add('hudButton');

    // ÜST KISIMDAKİ DİĞER EKLENEN KODLAR (scoreText, levelText vb.)
    add(comboText);
    overlays.add('hudButton');

    // YENİ EKLENEN BAR:
    add(UltimatePowerBar());

    _spawnSquares();
  }

  void addUltimatePower(double amount) {
    // Eğer süre (freeze) zaten aktifse bar dolmasın
    if (isFreezeActive) return;

    ultimatePower += amount;

    // Bar doldu mu?
    if (ultimatePower >= maxUltimatePower) {
      ultimatePower = 0.0; // Barı sıfırla

      // EKRANIN ORTASINDA GÖKKUŞAĞI TOPUNU ÇIKAR!
      final spawnX = size.x / 2;
      final spawnY = size.y / 2;

      // Rastgele bir açıyla fırlat
      final angle = random.nextDouble() * 2 * pi;
      final velocity = Vector2(cos(angle), sin(angle)) * 200.0;

      add(RainbowBall(position: Vector2(spawnX, spawnY), velocity: velocity));
      playSfx('ultimate_spawn'); // YENİ

      // Bar dolduğunda hafif bir ekran titremesi (Opsiyonel gerilim efekti)
      camera.viewfinder.add(
        MoveEffect.by(
          Vector2(5, 5),
          EffectController(duration: 0.05, alternate: true, repeatCount: 3),
        ),
      );
    }
  }

  // GÖKKUŞAĞI TOPU PATLADIĞINDA ÇALIŞACAK ANA FONKSİYON
  void triggerRainbowUltimate(Vector2 epicenter) {
    // 1. Devasa bir patlama efekti (Ekranı aydınlat)
    _showWhiteTapEffect(epicenter);

    // YENİ: Geri sayım sayacını aktif et!
    isFreezeActive = true;
    freezeTimer = 3.0; // Ekranda 3 saniye geri sayacak

    // 2. O an ekranda olan TIKLANABİLİR TÜM KARELERİ bul
    final allSquares = children.whereType<MovingSquare>().toList();

    for (var square in allSquares) {
      // Şimşek gönder
      add(LightningBeam(start: epicenter, end: square.position));

      // Eğer Altın değilse Beyaza çevir (Altınları bozmak oyuncuyu üzebilir, istersen altınları da beyaza çevirebilirsin)
      if (square.type != SquareType.gold) {
        square.forceMutateToWhite();
      }

      // Hepsini 3 saniyeliğine dondur
      square.freezeFor(3.0);
    }
  }

  void _spawnSquares() {
    int totalSquares = difficulty.squareCount;

    // Artık sabit bir rakam değil, zorluk seviyesinin kotasını kullanıyoruz!
    int minWhites = (totalSquares * difficulty.whiteQuota).ceil();

    for (int i = 0; i < totalSquares; i++) {
      SquareType initialType = (i < minWhites)
          ? SquareType.white
          : _randomType();
      add(_buildSquare(initialType));
    }

    // AŞAĞIDAKİ SATIRLARI SİLDİK! Artık oyun başında top çıkmayacak.
  }

  MovingSquare _buildSquare(SquareType type) {
    // ARTIK TÜRÜ DIŞARIDAN ALIYOR
    final isGold = type == SquareType.gold;
    // Elmaslar %60 daha büyük
    final actualSize = isGold
        ? difficulty.squareSize * 1.6
        : difficulty.squareSize;

    return MovingSquare(
      type: type,
      // İŞTE HATA VEREN YER BURASIYDI, AŞAĞIDAKİ FONKSİYONU ÇAĞIRIYOR:
      position: _randomPosition(actualSize),
      velocity: _randomVelocity(type),
      squareSize: actualSize,
      color: _colorOf(type),
    );
  }

  Vector2 _randomPosition(double sizeVal) {
    return Vector2(
      (sizeVal / 2) + random.nextDouble() * (size.x - sizeVal),
      (sizeVal / 2) + random.nextDouble() * (size.y - sizeVal),
    );
  }

  void openGuessMenu() {
    pauseEngine();
    overlays.remove('hudButton');
    currentOptions = levelsRepository.buildOptions(
      gameLevels[currentLevelIndex],
      AppStrings.currentLang,
    );
    overlays.add('guessMenu');
  }

  void openPauseMenu() {
    pauseEngine();
    overlays.remove('hudButton');
    overlays.add('pauseMenu');
  }

  void resumeFromPause() {
    overlays.remove('pauseMenu');
    overlays.add('hudButton');
    resumeEngine();
  }

  void resumeIfPaused() {
    if (overlays.isActive('pauseMenu')) {
      overlays.remove('pauseMenu');
      overlays.add('hudButton');
      resumeEngine();
    }
  }

  void exitToMenu() {
    onReturnToMenu?.call();
  }

  void submitGuess(String guessedAnswer) async {
    overlays.remove('guessMenu');

    final correctAnswer = gameLevels[currentLevelIndex].answerFor(
      AppStrings.currentLang,
    );

    if (guessedAnswer == correctAnswer) {
      int maxReward = 500;
      int penaltyPerTile = 15;
      int minReward = 50;

      lastEarnedPoints = maxReward - (tilesRevealedThisLevel * penaltyPerTile);
      if (lastEarnedPoints < minReward) lastEarnedPoints = minReward;

      lastEarnedPoints += (currentCombo * 10);

      await scoreManager.addPoints(lastEarnedPoints);
      playSfx('level_complete'); // YENİ

      // Kareleri temizle, sisi tamamen kaldır: resim tam ekran görünsün
      children.whereType<MovingSquare>().forEach(
        (square) => square.removeFromParent(),
      );
      fogOverlay.hideCompletely();
      resumeEngine(); // konfeti animasyonu ve render için motor çalışmalı

      // Ekranın birkaç noktasından konfeti patlat
      _showConfettiEffect(Vector2(size.x * 0.5, size.y * 0.25));
      _showConfettiEffect(Vector2(size.x * 0.2, size.y * 0.55));
      _showConfettiEffect(Vector2(size.x * 0.8, size.y * 0.55));

      overlays.add('successOverlay');

      Future.delayed(const Duration(milliseconds: 2000), () {
        overlays.remove('successOverlay');
        _nextLevel();
      });
    } else {
      currentCombo = 0;
      _triggerGameOver();
    }
  }

  Future<void> _nextLevel() async {
    roundsCompleted++;
    await scoreManager.updateSavedLevelForCategory(
      selectedCategory,
      roundsCompleted,
    );
    currentLevelIndex = roundsCompleted % gameLevels.length;
    tilesRevealedThisLevel = 0;
    currentCombo = 0;
    _updateTexts();

    backgroundImage.sprite = await _loadLevelSprite();
    fogOverlay.resetOverlay();

    children.whereType<MovingSquare>().forEach(
      (square) => square.removeFromParent(),
    );
    _spawnSquares();

    overlays.add('hudButton');
    resumeEngine();
  }

  void resetCombo() {
    if (currentCombo > 0) {
      currentCombo = 0;
      _updateTexts();

      comboText.removeAll(comboText.children.whereType<Effect>());
      comboText.scale = Vector2.all(1.0);

      comboText.textRenderer = TextPaint(
        style: const TextStyle(
          color: Colors.redAccent,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );

      comboText.add(
        MoveEffect.by(
          Vector2(5, 0),
          EffectController(duration: 0.05, alternate: true, repeatCount: 4),
        ),
      );

      add(
        TimerComponent(
          period: 0.5,
          removeOnFinish: true,
          onTick: () {
            if (comboText.isMounted) {
              comboText.textRenderer = TextPaint(
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              );
            }
          },
        ),
      );
    }
  }

  // GÜNCELLENDİ: Kareleri artık net bir şekilde ekran sınırının içine koyuyoruz.
  int _spawnAtEdge(MovingSquare square) {
    final edge = random.nextInt(4);
    final speed = difficulty.speed * (0.8 + random.nextDouble() * 0.2);
    double angle;

    final margin = 10.0; // Zarın taban noktası

    switch (edge) {
      case 0: // Üst
        square.position = Vector2(random.nextDouble() * size.x, margin);
        angle = (random.nextDouble() * pi / 2) + (pi / 4);
        break;
      case 1: // Sağ
        square.position = Vector2(
          size.x - margin,
          random.nextDouble() * size.y,
        );
        angle = (random.nextDouble() * pi / 2) + (3 * pi / 4);
        break;
      case 2: // Alt
        square.position = Vector2(
          random.nextDouble() * size.x,
          size.y - margin,
        );
        angle = (random.nextDouble() * pi / 2) + (5 * pi / 4);
        break;
      default: // Sol
        square.position = Vector2(margin, random.nextDouble() * size.y);
        angle = (random.nextDouble() * pi / 2) - (pi / 4);
        break;
    }

    // Başlangıçta hareket ETMESİN. Zorlanma animasyonunu manuel yapacağız!
    square.velocity = Vector2.zero();

    // Asıl fırlayacağı hızı ve açıyı (x, y) olarak döndürüyoruz ki hafızada tutalım.
    final targetVelocity = Vector2(cos(angle), sin(angle)) * speed;

    // Fonksiyondan artık hem kenar ID'sini hem de hedef hızı döndürüyoruz
    // (Bunun için Dart'ın dynamic dönüşünü kullanmamak adına Square'e hızı yazıp kenarı döndürüyoruz,
    // ama hızı hemen geri sıfırlayıp hedefi hafızaya alacağız respawn içinde).
    square.velocity = targetVelocity;
    return edge;
  }

  // GÜNCELLENDİ: Gerilim hissi için patlayan parçacıklar daha kalın ve kırmızımsı
  void _showMembraneBurst(Vector2 position) {
    add(
      ParticleSystemComponent(
        position: position,
        particle: Particle.generate(
          count: 15,
          lifespan: 0.4,
          generator: (i) {
            final angle = random.nextDouble() * 2 * pi;
            final speed = random.nextDouble() * 150 + 50;
            return AcceleratedParticle(
              speed: Vector2(cos(angle), sin(angle)) * speed,
              child: CircleParticle(
                radius: 3.0 + random.nextDouble() * 3.0,
                paint: Paint()..color = Colors.redAccent.withValues(alpha: 0.8),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showConfettiEffect(Vector2 position) {
    final colors = [
      Colors.yellow,
      Colors.blue,
      Colors.green,
      Colors.pink,
      Colors.white,
    ];
    add(
      ParticleSystemComponent(
        position: position,
        particle: Particle.generate(
          count: 30,
          lifespan: 1.0,
          generator: (i) {
            final isDiamond = random.nextDouble() < 0.2;
            final angle = random.nextDouble() * 2 * pi;
            final speedValue = random.nextDouble() * 150 + 50;
            final velocityVector = Vector2(cos(angle), sin(angle)) * speedValue;
            final color = colors[random.nextInt(colors.length)];

            return AcceleratedParticle(
              speed: velocityVector,
              acceleration: Vector2(0, 200),
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  final opacity = (1.0 - particle.progress).clamp(0.0, 1.0);

                  if (isDiamond) {
                    final textSpan = TextSpan(
                      text: '💎',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: opacity),
                      ),
                    );
                    final textPainter = TextPainter(
                      text: textSpan,
                      textDirection: TextDirection.ltr,
                    );
                    textPainter.layout();
                    textPainter.paint(
                      canvas,
                      Offset(-textPainter.width / 2, -textPainter.height / 2),
                    );
                  } else {
                    final paint = Paint()
                      ..color = color.withValues(alpha: opacity);
                    canvas.drawCircle(Offset.zero, 4.0, paint);
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }

  // YENİ VE DAHA CANLI: Beyaz kare tıklanma (Şok Dalgası) Efekti
  void _showWhiteTapEffect(Vector2 position) {
    // 1. KATMAN: İçeride patlayan parlak neon mavi/beyaz ışık hüzmesi
    add(
      ParticleSystemComponent(
        position: position,
        priority: 120,
        particle: Particle.generate(
          count: 1,
          lifespan: 0.2,
          generator: (i) {
            return ComputedParticle(
              renderer: (canvas, particle) {
                final radius = 10.0 + (particle.progress * 30.0);
                final opacity = (1.0 - particle.progress).clamp(0.0, 1.0);

                final paint = Paint()
                  ..color = Colors.lightBlueAccent.withValues(
                    alpha: opacity * 0.5,
                  )
                  ..maskFilter = const MaskFilter.blur(
                    BlurStyle.normal,
                    10,
                  ); // Parlama

                canvas.drawCircle(Offset.zero, radius, paint);
              },
            );
          },
        ),
      ),
    );

    // 2. KATMAN: Dışa doğru hızla genişleyen keskin şok dalgası (Çift Halka)
    add(
      ParticleSystemComponent(
        position: position,
        priority: 121,
        particle: Particle.generate(
          count: 2, // İki halka peş peşe büyür
          lifespan: 0.35,
          generator: (i) {
            return ComputedParticle(
              renderer: (canvas, particle) {
                // i == 0 ise büyük halka, i == 1 ise içeriden gelen daha küçük halka
                final delay = i * 0.1;
                var p = particle.progress - delay;
                if (p < 0) return; // İkinci halka biraz gecikmeli başlar
                p = p.clamp(0.0, 1.0);

                final radius = 20.0 + (p * 50.0);
                final opacity = (1.0 - p).clamp(0.0, 1.0);

                final paint = Paint()
                  ..color = Colors.white.withValues(alpha: opacity)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 5.0 - (p * 4); // İncelerek kaybolur

                canvas.drawCircle(Offset.zero, radius, paint);
              },
            );
          },
        ),
      ),
    );

    // 3. KATMAN: Dışarı fırlayan yüksek hızlı enerji kıvılcımları
    add(
      ParticleSystemComponent(
        position: position,
        priority: 122,
        particle: Particle.generate(
          count: 12, // Kıvılcım sayısını artırdık
          lifespan: 0.4,
          generator: (i) {
            final angle = random.nextDouble() * 2 * pi;
            // Kıvılcımlar merkeze doğru değil, dışarı doğru hızla savrulur
            final speed = random.nextDouble() * 200 + 100;

            return AcceleratedParticle(
              speed: Vector2(cos(angle), sin(angle)) * speed,
              // Ufak bir sürtünme ekledik, yavaşlayarak sönerler
              acceleration: Vector2(cos(angle), sin(angle)) * -150,
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  final opacity = (1.0 - particle.progress).clamp(0.0, 1.0);

                  final paint = Paint()
                    ..color = Colors.white.withValues(alpha: opacity)
                    ..strokeCap = StrokeCap.round
                    ..strokeWidth = 3.0;

                  // Nokta yerine, hıza bağlı uzayan çizgiler çiziyoruz (Motion Blur hissi)
                  canvas.drawLine(
                    Offset.zero,
                    Offset(
                      cos(angle) * 8 * (1 - particle.progress),
                      sin(angle) * 8 * (1 - particle.progress),
                    ),
                    paint,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  // YENİ EFEKT: İki beyaz kare çarpışıp renk değiştirdiğinde çıkan ufak duman/kıvılcım
  void showMutationEffect(Vector2 position) {
    // playSfx('mutation'); // Dakikada çok sık tetikleniyor, rahatsız ediyor — kapatıldı
    add(
      ParticleSystemComponent(
        position: position,
        priority: 130,
        particle: Particle.generate(
          count: 8, // Çok abartılı olmayan ufak bir efekt
          lifespan: 0.3,
          generator: (i) {
            final angle = random.nextDouble() * 2 * pi;
            final speed = random.nextDouble() * 80 + 40;
            return AcceleratedParticle(
              speed: Vector2(cos(angle), sin(angle)) * speed,
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  final opacity = (1.0 - particle.progress).clamp(0.0, 1.0);
                  final paint = Paint()
                    ..color = Colors.white.withValues(alpha: opacity)
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2.0;

                  // Ufak beyaz halkacıklar dışarı doğru saçılır
                  canvas.drawCircle(
                    Offset.zero,
                    3.0 + (particle.progress * 5),
                    paint,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  // ATEŞLİ BOMBA EFEKTİ (Duman, Alev ve Kıvılcımlar)
  void showBombExplosionEffect(Vector2 position) {
    // 1. KATMAN: YÜKSEK HIZLI KIVILCIMLAR
    add(
      ParticleSystemComponent(
        position: position,
        priority: 150,
        particle: Particle.generate(
          count: 20,
          lifespan: 0.5,
          generator: (i) {
            final angle = random.nextDouble() * 2 * pi;
            final speed = random.nextDouble() * 300 + 200;
            final velocityVector = Vector2(cos(angle), sin(angle)) * speed;
            return AcceleratedParticle(
              speed: velocityVector,
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  final opacity = (1.0 - particle.progress).clamp(0.0, 1.0);
                  final paint = Paint()
                    ..color = Colors.orangeAccent.withValues(alpha: opacity)
                    ..strokeWidth = 3.0
                    ..strokeCap = StrokeCap.round;

                  canvas.drawLine(
                    Offset.zero,
                    Offset(-velocityVector.x * 0.05, -velocityVector.y * 0.05),
                    paint,
                  );
                },
              ),
            );
          },
        ),
      ),
    );

    // 2. KATMAN: ALEV TOPU VE DUMAN
    add(
      ParticleSystemComponent(
        position: position,
        priority: 149,
        particle: Particle.generate(
          count: 45,
          lifespan: 1.0,
          generator: (i) {
            final angle = random.nextDouble() * 2 * pi;
            final speedValue = random.nextDouble() * 80 + 30;
            final velocityVector = Vector2(cos(angle), sin(angle)) * speedValue;

            return AcceleratedParticle(
              speed: velocityVector,
              acceleration: Vector2(0, -60),
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  final p = particle.progress;

                  Color c;
                  if (p < 0.2) {
                    c = Colors.white;
                  } else if (p < 0.4) {
                    c = Colors.yellowAccent;
                  } else if (p < 0.6) {
                    c = Colors.deepOrange;
                  } else {
                    c = Colors.black87;
                  }

                  final radius = 12.0 * sin(p * pi);
                  final opacity = (1.0 - p).clamp(0.0, 1.0);

                  final paint = Paint()
                    ..color = c.withValues(
                      alpha: p > 0.6 ? opacity * 0.6 : opacity,
                    )
                    ..blendMode = p < 0.6
                        ? BlendMode.screen
                        : BlendMode.srcOver;

                  canvas.drawCircle(
                    Offset.zero,
                    radius + (random.nextDouble() * 6),
                    paint,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  // COMBO BÜYÜME EFEKTİ (Yanlışlıkla silinen fonksiyon)
  void _playComboIncreaseEffect() {
    comboText.removeAll(comboText.children.whereType<Effect>());
    comboText.scale = Vector2.all(1.0);

    // Combo arttıkça devasa boyutlara ulaşır (Maksimum 4 katına kadar çıkar!)
    double targetScale = min(1.8 + (currentCombo * 0.2), 4.0);

    // Önce hızlıca şişer (easeOut), sonra yaylanarak (bounceOut) geri küçülür
    comboText.add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(targetScale),
          EffectController(duration: 0.1, curve: Curves.easeOut),
        ),
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: 0.3, curve: Curves.bounceOut),
        ),
      ]),
    );
  }

  void handleTap(MovingSquare square) async {
    if (square.type == SquareType.gold || square.type == SquareType.white) {
      if (square.type == SquareType.gold) {
        currentCombo++;
        await scoreManager.registerCombo(currentCombo);
        _playComboIncreaseEffect();
        _showConfettiEffect(square.position);
        addUltimatePower(25.0);
        playSfx('combo_up'); // YENİ
        playSfx('diamond_collect'); // YENİ
      }

      int basePoint = square.type == SquareType.gold ? 5 : 1;
      int pointsEarned = basePoint + (currentCombo ~/ 5);

      await scoreManager.addPoints(pointsEarned);

      // BEYAZ KARE TIKLANDIĞINDA
      if (square.type == SquareType.white) {
        double revealSize = 25;
        fogOverlay.revealAt(square.toAbsoluteRect().inflate(revealSize));
        tilesRevealedThisLevel++;
        _showWhiteTapEffect(square.position);
        addUltimatePower(5.0);
        if (_soundOn) _tapPool.start(); // YENİ
      }
    } else {
      currentCombo = 0;
      _triggerGameOver();
      return;
    }

    _updateTexts();
    respawnSquare(square);
  }

  void _updateTexts() {
    scoreText.text = AppStrings.get('score_label', {
      'puan': '${scoreManager.score}',
    });
    final comboBase = AppStrings.get('combo_label', {'sayı': '$currentCombo'});
    comboText.text = currentCombo > 2 ? "$comboBase 🔥" : comboBase;
    levelText.text = AppStrings.get('level_label', {
      'bölüm': '${roundsCompleted + 1}',
    });
  }

  void refreshLanguageTexts() {
    if (!isLoaded) return;
    _updateTexts();
  }

  // GÜNCELLENDİ: scale sıfırlaması
  void respawnSquare(MovingSquare square) {
    // 1. Eski efektleri temizle
    square.removeAll(square.children.whereType<Effect>());
    square.removeAll(square.children.whereType<TimerComponent>());
    square.isFrozen =
        false; // YENİ: yeniden doğuş, eski donma durumunu geçersiz kılar
    // 2. YENİ EKLENEN SATIR: Ne olursa olsun boyutu normale döndür!
    // (Böylece takılı kalan veya büyük/küçük kalan kareler düzelir)
    square.scale = Vector2.all(1.0);

    final type = _getBalancedType(square);
    square.type = type;
    square.paint.color = type == SquareType.gold
        ? Colors.transparent
        : _colorOf(type);
    final isGold = type == SquareType.gold;
    square.size = Vector2.all(
      isGold ? difficulty.squareSize * 1.6 : difficulty.squareSize,
    );

    final edge = _spawnAtEdge(square);
    final targetVelocity = square.velocity.clone();
    square.pendingVelocity = targetVelocity;
    square.isSpawning = true;

    square.velocity = Vector2.zero();

    // DİKKAT: BURADA BULUNAN "square.triggerSpawnAnimation();" SATIRINI SİLİYORSUN!
    // Artık o koda ihtiyacımız yok, zar efekti o işi yapıyor.

    add(CellMembraneEffect(targetSquare: square, edge: edge));

    // 4. İÇERİ DOĞRU FİZİKSEL ZORLANMA ANİMASYONU (Çok Bariz Görünür)
    // Kare, hız vektörünün yönünde ekranın İÇİNE doğru 60 piksel ittirilir.
    final pushDirection = targetVelocity.normalized();
    final pushDistance =
        60.0; // Ne kadar derin ittireceği (Bunu artırırsan daha da uzar)

    square.add(
      MoveEffect.by(
        pushDirection * pushDistance,
        EffectController(
          duration: 0.6,
          curve: Curves.easeInCirc,
        ), // Gittikçe hızlanan gerilim
      ),
    );

    // 5. TİTREME EFEKTİ (Struggle/Zorlanma Hissi)
    // Kare içeri doğru girerken aynı zamanda sağa sola çok hızlı titrer
    square.add(
      MoveEffect.by(
        Vector2(3, -3), // Ufak sarsıntı çapı
        EffectController(duration: 0.05, alternate: true, repeatCount: 12),
      ),
    );

    square.scale = Vector2.all(0.85);
    square.add(
      ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.6)),
    );

    // 6. KOPMA VE FIRLAMA (Tam 0.6 Saniye Sonra)
    square.add(
      TimerComponent(
        period: 0.6,
        removeOnFinish: true,
        onTick: () {
          if (!square.isFrozen) {
            square.velocity = targetVelocity;
            square.pendingVelocity = null;
          }
          // Frozen ise pendingVelocity zaten targetVelocity'yi tutuyor,
          // freeze bittiğinde kendisi uygulayacak.
          square.isSpawning = false;
          square.add(
            ScaleEffect.by(
              Vector2.all(1.12),
              EffectController(
                duration: 0.15,
                alternate: true,
                curve: Curves.elasticOut,
              ),
            ),
          );
        },
      ),
    );
  }

  Vector2 _randomVelocity(SquareType type) {
    final speed = difficulty.speed;

    // 360 derecelik (2*pi) rastgele bir açı (yön) belirliyoruz
    final angle = random.nextDouble() * 2 * pi;

    // Tüm karelerin birebir aynı hızda gitmemesi için %80 ile %100 arası
    // ufak bir rastgelelik (varyasyon) katıyoruz ki doğal dursun.
    final actualSpeed = speed * (0.8 + random.nextDouble() * 0.2);

    // Trigonometri kullanarak yönü hıza çeviriyoruz
    return Vector2(cos(angle), sin(angle)) * actualSpeed;
  }

  void _triggerGameOver() {
    playSfx('game_over'); // YENİ
    gameManager.triggerGameOver();
    pauseEngine();
    overlays.remove('hudButton');
    overlays.add('gameOver');
  }

  void restart() async {
    gameManager.reset();
    scoreManager.reset();
    roundsCompleted =
        (await scoreManager.loadLevelForCategory(selectedCategory)) - 1;
    currentLevelIndex = roundsCompleted % gameLevels.length;
    tilesRevealedThisLevel = 0;
    currentCombo = 0;
    _updateTexts();

    backgroundImage.sprite = await _loadLevelSprite();
    fogOverlay.resetOverlay();

    children.whereType<MovingSquare>().forEach(
      (square) => square.removeFromParent(),
    );
    _spawnSquares();

    overlays.remove('gameOver');
    overlays.add('hudButton');
    resumeEngine();
  }

  Future<void> setCategoryAndReset(String category) async {
    pauseEngine(); // YENİ: değişim sırasında motor kontrollü şekilde dursun
    selectedCategory = category;
    roundsCompleted = (await scoreManager.loadLevelForCategory(category)) - 1;
    currentLevelIndex = roundsCompleted % gameLevels.length;
    tilesRevealedThisLevel = 0;
    currentCombo = 0;
    ultimatePower = 0.0; // YENİ
    isFreezeActive = false; // YENİ
    scoreManager.reset();
    _updateTexts();

    backgroundImage.sprite = await _loadLevelSprite();
    fogOverlay.resetOverlay();

    children.whereType<MovingSquare>().forEach((s) => s.removeFromParent());
    _spawnSquares();
    resumeEngine(); // YENİ: her şey bittikten sonra tek seferde devam
  }

  // YENİ: Ekrandaki beyaz kare sayısını garanti altına alan kota sistemi
  SquareType _getBalancedType([MovingSquare? squareToIgnore]) {
    int currentWhites = children
        .whereType<MovingSquare>()
        .where((s) => s.type == SquareType.white && s != squareToIgnore)
        .length;

    // Kotayı seviyeye göre dinamik hesapla
    int minWhitesRequired = (difficulty.squareCount * difficulty.whiteQuota)
        .ceil();

    if (currentWhites < minWhitesRequired) {
      // Eğer beyazlar bitmek üzereyse, şansa bırakma, kesinlikle BEYAZ ver!
      return SquareType.white;
    }

    // Beyaz kotası doluysa normal şans çarkını çevir
    return _randomType();
  }

  void ensureWhiteQuota({List<MovingSquare> exclude = const []}) {
    final squares = children.whereType<MovingSquare>().toList();
    final currentWhites = squares
        .where((s) => s.type == SquareType.white)
        .length;
    final minWhitesRequired = (difficulty.squareCount * difficulty.whiteQuota)
        .ceil();

    if (currentWhites >= minWhitesRequired) return;

    final candidates =
        squares
            .where((s) => s.type == SquareType.colorful && !exclude.contains(s))
            .toList()
          ..shuffle(random);

    final needed = minWhitesRequired - currentWhites;
    for (final square in candidates.take(needed)) {
      square.type = SquareType.white;
      square.paint.color = Colors.white;

      // YENİ: aynı mutasyon animasyonunu burada da oynat, göze görünür olsun
      square.removeAll(square.children.whereType<ScaleEffect>());
      square.scale = Vector2.all(1.0);
      square.add(
        SequenceEffect([
          ScaleEffect.to(
            Vector2.all(1.3),
            EffectController(duration: 0.1, curve: Curves.easeOut),
          ),
          ScaleEffect.to(
            Vector2.all(1.0),
            EffectController(duration: 0.2, curve: Curves.bounceOut),
          ),
        ]),
      );
      showMutationEffect(square.position);
    }
  }

  SquareType _randomType() {
    final r = random.nextDouble();

    if (r < difficulty.whiteChance) {
      return SquareType.white;
    }

    if (r < difficulty.whiteChance + difficulty.fakeChance) {
      return SquareType.fakeWhite;
    }

    if (r <
        difficulty.whiteChance +
            difficulty.fakeChance +
            difficulty.goldChance) {
      return SquareType.gold;
    }

    return SquareType.colorful;
  }

  // --- BU KISMI BİREBİR DEĞİŞTİR ---

  final List<Color> _allCandyColors = [
    Colors.redAccent, // 1. Başlangıç Rengi
    Colors.lightBlueAccent, // 2. Başlangıç Rengi
    Colors.greenAccent, // 3. Başlangıç Rengi
    Colors.orangeAccent, // 4. Başlangıç Rengi
    Colors.purpleAccent, // 5. Başlangıç Rengi
    Colors.pinkAccent, // 6. Bölüm 3'te gelir
    Colors.amberAccent, // 7. Bölüm 6'da gelir
    Colors.tealAccent, // 8. Bölüm 9'da gelir
    Colors.deepOrangeAccent, // 9. Bölüm 12'de gelir
    Colors.indigoAccent, // 10. Bölüm 15'te gelir
    Colors.cyanAccent, // 11. Bölüm 18'de gelir
    Colors.limeAccent, // 12. Bölüm 21'de gelir
    Colors.deepPurpleAccent, // 13. Bölüm 24'te gelir
    const Color(0xFFFF4081), // 14. Bölüm 27'de gelir (Özel Neon Pembe)
  ];

  // O anki round'a göre aktif renk listesini döndürür
  List<Color> get activeColors {
    // Başlangıçta 5 renk var. HER 2 BÖLÜMDE 1 YENİ RENK EKLENİR!
    int colorCount = 5 + (roundsCompleted ~/ 2);

    // Eğer hesaplanan renk sayısı havuzdaki toplam renkten fazlaysa, maksimumda tut.
    if (colorCount > _allCandyColors.length) {
      colorCount = _allCandyColors.length;
    }

    return _allCandyColors.sublist(0, colorCount);
  }

  Color _colorOf(SquareType type) {
    switch (type) {
      case SquareType.white:
        return Colors.white;
      case SquareType.fakeWhite:
        // YENİ: Sahte beyazları daha koyu, metalik/soğuk bir gri yaptık!
        return const Color(0xFF90A4AE); // BlueGrey(300)
      case SquareType.colorful:
        final currentColors = activeColors;
        return currentColors[random.nextInt(currentColors.length)];
      case SquareType.gold:
        return Colors.transparent;
    }
  }
}

class HudPanel extends PositionComponent {
  HudPanel({required Vector2 position, required Vector2 size})
    : super(position: position, size: size, priority: 99);

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    canvas.drawRRect(rrect, Paint()..color = const Color(0xAA000000));
  }
}

class CellMembraneEffect extends PositionComponent
    with HasGameReference<WhiteRushGame> {
  final int edge;
  final MovingSquare targetSquare;
  double progress = 0.0;
  final double duration = 0.6;

  CellMembraneEffect({required this.targetSquare, required this.edge});

  @override
  Future<void> onLoad() async {
    size = game.size;
    position = Vector2.zero();
  }

  // BURA DÜZELTİLDİ: Sadece zar efektinin kendi mantığı kaldı
  @override
  void update(double dt) {
    super.update(dt);
    progress += dt / duration;

    if (progress >= 1.0) {
      game._showMembraneBurst(targetSquare.position);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (!targetSquare.isMounted) return;

    final currentColor = Color.lerp(
      Colors.cyanAccent,
      Colors.redAccent,
      progress,
    )!;

    final paint = Paint()
      ..color = currentColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0 - (progress * 3)
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 5);

    final path = Path();
    final sqPos = targetSquare.position;
    final spread = targetSquare.size.x * 2.5;
    final margin = 10.0;

    if (edge == 0) {
      path.moveTo(sqPos.x - spread, margin);
      path.quadraticBezierTo(sqPos.x, sqPos.y, sqPos.x + spread, margin);
    } else if (edge == 1) {
      path.moveTo(size.x - margin, sqPos.y - spread);
      path.quadraticBezierTo(
        sqPos.x,
        sqPos.y,
        size.x - margin,
        sqPos.y + spread,
      );
    } else if (edge == 2) {
      path.moveTo(sqPos.x - spread, size.y - margin);
      path.quadraticBezierTo(
        sqPos.x,
        sqPos.y,
        sqPos.x + spread,
        size.y - margin,
      );
    } else {
      path.moveTo(margin, sqPos.y - spread);
      path.quadraticBezierTo(sqPos.x, sqPos.y, margin, sqPos.y + spread);
    }

    canvas.drawPath(path, paint);
  }
}

// Gökkuşağı topu patladığında çıkan elektrik arkı efekti
class LightningBeam extends PositionComponent {
  final Vector2 start;
  final Vector2 end;
  final Random _random = Random();
  double _lifeTime = 0.3; // Şimşeğin ekranda kalma süresi

  LightningBeam({required this.start, required this.end}) {
    position = Vector2.zero();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _lifeTime -= dt;
    if (_lifeTime <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    // Sadece çok kısa süre görünür ve şeffaflaşır
    final opacity = (_lifeTime / 0.3).clamp(0.0, 1.0);

    final paint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 8); // Neon parlama

    final path = Path();
    path.moveTo(start.x, start.y);

    // Düz bir çizgi yerine zikzaklı (elektrik) bir yol hesapla
    int segments = 8;
    for (int i = 1; i <= segments; i++) {
      double t = i / segments;
      Vector2 currentPos = start + (end - start) * t;

      if (i < segments) {
        // Çizgiyi dik eksende rastgele kaydır (zikzak yap)
        double offset = (_random.nextDouble() - 0.5) * 40;
        Vector2 normal = Vector2(
          -(end.y - start.y),
          (end.x - start.x),
        ).normalized();
        currentPos += normal * offset;
      }

      path.lineTo(currentPos.x, currentPos.y);
    }

    canvas.drawPath(path, paint);

    // Beyaz parlak iç çekirdek
    final corePaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, corePaint);
  }
}

class RainbowBall extends PositionComponent
    with TapCallbacks, HasGameReference<WhiteRushGame> {
  int clicksLeft = 5;
  late Vector2 velocity;
  double _rotationAngle = 0;
  final double ballSize = 65.0; // Biraz daha büyük ve görkemli

  RainbowBall({required Vector2 position, required this.velocity}) {
    this.position = position;
    size = Vector2.all(ballSize);
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    // Ekrana girerken havalı bir yaylanma efekti
    scale = Vector2.zero();
    add(
      ScaleEffect.to(
        Vector2.all(1.0),
        EffectController(duration: 0.6, curve: Curves.elasticOut),
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver) return;

    // Top kendi etrafında sürekli dönsün
    _rotationAngle += dt * 3;

    // Ekranın içinde sekerek dolaşsın
    position += velocity * dt;
    final gameSize = game.size;
    final halfSize = ballSize / 2;

    if (position.x - halfSize < 0) {
      position.x = halfSize;
      velocity.x = velocity.x.abs();
    } else if (position.x + halfSize > gameSize.x) {
      position.x = gameSize.x - halfSize;
      velocity.x = -velocity.x.abs();
    }
    if (position.y - halfSize < 0) {
      position.y = halfSize;
      velocity.y = velocity.y.abs();
    } else if (position.y + halfSize > gameSize.y) {
      position.y = gameSize.y - halfSize;
      velocity.y = -velocity.y.abs();
    }
  }

  @override
  void render(Canvas canvas) {
    // HEDEF 3 VE 4: Çizim kodunu statik metottan çağırıyoruz.
    drawCandyBomb(
      canvas,
      Offset(size.x / 2, size.y / 2),
      size.x / 2,
      _rotationAngle,
    );

    // Kalan Tıklama Rakamı Çizimi
    final textSpan = TextSpan(
      text: clicksLeft.toString(),
      style: TextStyle(
        fontSize: size.x * 0.6,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        shadows: const [
          Shadow(blurRadius: 5.0, color: Colors.black, offset: Offset(2, 2)),
          Shadow(blurRadius: 10.0, color: Colors.purple, offset: Offset(0, 0)),
        ],
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.x - textPainter.width) / 2,
        (size.y - textPainter.height) / 2,
      ),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (game.isGameOver) return;

    clicksLeft--;

    // Her tıklandığında titreme/küçülme efekti
    add(
      ScaleEffect.by(
        Vector2.all(0.8),
        EffectController(duration: 0.05, alternate: true),
      ),
    );

    if (clicksLeft <= 0) {
      game.playSfx('ultimate_trigger'); // YENİ
      game.triggerRainbowUltimate(position);
      removeFromParent(); // Topu yok et
    }
  }

  /// HER YERDE KULLANILABİLECEK ORTAK 3D CANDY CRUSH ŞEKER ÇİZİMİ
  static void drawCandyBomb(
    Canvas canvas,
    Offset center,
    double radius,
    double rotation,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // 1. Dış Parlaklık (Glow) Efekti
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset.zero, radius * 1.1, glowPaint);

    // 2. Candy Crush Renk Geçişi (Sarmal Gökkuşağı)
    final sweepPaint = Paint()
      ..shader = const SweepGradient(
        colors: [
          Colors.red,
          Colors.orange,
          Colors.yellow,
          Colors.green,
          Colors.blue,
          Colors.purple,
          Colors.red,
        ],
        stops: [0.0, 0.16, 0.33, 0.5, 0.66, 0.83, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));
    canvas.drawCircle(Offset.zero, radius, sweepPaint);

    // 3. Küresel Derinlik (İç Gölge / 3D Etkisi)
    final shadowPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
        stops: const [0.6, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));
    canvas.drawCircle(Offset.zero, radius, shadowPaint);

    // 4. Cam Parlaması (Jelibon parlaklığı üstte)
    final reflectionRect = Rect.fromLTWH(
      -radius * 0.5,
      -radius * 0.8,
      radius,
      radius * 0.8,
    );
    final reflectionPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: 0.9), Colors.transparent],
      ).createShader(reflectionRect);
    canvas.drawOval(reflectionRect, reflectionPaint);

    // 5. Şeker Çizgileri (Merkezden dışa kıvrımlar - ekstra detay)
    final swirlPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    for (int i = 0; i < 6; i++) {
      canvas.save();
      canvas.rotate((i * 60) * pi / 180);
      final path = Path();
      path.moveTo(0, 0);
      path.quadraticBezierTo(radius * 0.5, radius * 0.5, 0, radius);
      canvas.drawPath(path, swirlPaint);
      canvas.restore();
    }

    canvas.restore();
  }
}

// MORTAL KOMBAT TARZI GÜÇ BARI EKRANI
class UltimatePowerBar extends PositionComponent
    with HasGameReference<WhiteRushGame> {
  double _animationTime = 0.0; // Barın parlaması ve akması için zamanlayıcı

  UltimatePowerBar() {
    priority = 200; // En üstte dursun
  }

  @override
  void update(double dt) {
    super.update(dt);
    _animationTime += dt; // Sürekli artan zaman
  }

  @override
  void render(Canvas canvas) {
    final barWidth = game.size.x * 0.8;
    final barHeight = 26.0; // Biraz daha kalınlaştırdık
    final startX = (game.size.x - barWidth) / 2;
    final startY = 150.0;

    final rect = Rect.fromLTWH(startX, startY, barWidth, barHeight);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(15));

    // 1. ARKA PLAN (3D İç Gölgeli Koyu Yuva)
    final bgPaint = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawRRect(rrect, bgPaint);

    // Barın içine hafif derinlik (İç gölge simülasyonu)
    final innerShadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = Colors.black.withValues(alpha: 0.6);
    canvas.drawRRect(rrect, innerShadowPaint);

    if (game.isFreezeActive) {
      // ---------------------------------------------------
      // MOD 2: SÜPER GÜÇ AKTİF (BUZLANMA VE GERİ SAYIM)
      // ---------------------------------------------------
      final freezeRatio = (game.freezeTimer / 3.0).clamp(0.0, 1.0);
      final freezeRect = Rect.fromLTWH(
        startX,
        startY,
        barWidth * freezeRatio,
        barHeight,
      );
      final freezeRRect = RRect.fromRectAndRadius(
        freezeRect,
        const Radius.circular(15),
      );

      final freezePaint = Paint()
        ..shader = LinearGradient(
          colors: [Colors.lightBlueAccent, Colors.white, Colors.cyan],
          stops: [
            0.0,
            0.5 + 0.5 * sin(_animationTime * 10),
            1.0,
          ], // Hızlı titreyen buz
        ).createShader(freezeRect);
      canvas.drawRRect(freezeRRect, freezePaint);

      // Kalan Saniyeyi Yaz
      final timeText = TextSpan(
        text: "⚡ ${game.freezeTimer.toStringAsFixed(2)} ⚡",
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Colors.black87,
          shadows: [
            Shadow(blurRadius: 4, color: Colors.white, offset: Offset(0, 0)),
          ],
        ),
      );
      final tp = TextPainter(text: timeText, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(startX + (barWidth - tp.width) / 2, startY + 2));
    } else {
      // ---------------------------------------------------
      // MOD 1: NORMAL GÜÇ BİRİKTİRME (HAREKETLİ)
      // ---------------------------------------------------
      final powerRatio = (game.ultimatePower / game.maxUltimatePower).clamp(
        0.0,
        1.0,
      );

      if (powerRatio > 0) {
        final fillWidth = barWidth * powerRatio;
        final fillRect = Rect.fromLTWH(startX, startY, fillWidth, barHeight);
        final fillRRect = RRect.fromRectAndRadius(
          fillRect,
          const Radius.circular(15),
        );

        // Zamanla Akan Animasyonlu Renk Geçişi
        final gradientOffset = sin(_animationTime * 3) * 0.2;

        final fillPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment(-1.0 + gradientOffset, 0),
            end: Alignment(1.0 + gradientOffset, 0),
            colors: powerRatio > 0.75
                ? [
                    Colors.blue,
                    Colors.green,
                    Colors.yellow,
                    Colors.red,
                  ] // Sona yaklaşınca gökkuşağı
                : [
                    Colors.deepOrange,
                    Colors.orangeAccent,
                    Colors.yellowAccent,
                  ], // Ateş rengi
          ).createShader(fillRect);

        canvas.drawRRect(fillRRect, fillPaint);

        // Barın DOLAN UCU için ekstra parlaklık (Leading Edge Glow)
        final edgeGlowRect = Rect.fromLTWH(
          startX + fillWidth - 15,
          startY,
          15,
          barHeight,
        );
        final edgeGlowPaint = Paint()
          ..shader = LinearGradient(
            colors: [Colors.transparent, Colors.white.withValues(alpha: 0.8)],
          ).createShader(edgeGlowRect);

        canvas.save();
        canvas.clipRRect(fillRRect); // Çizimin dışarı taşmasını engeller
        canvas.drawRect(edgeGlowRect, edgeGlowPaint);
        canvas.restore();
      }

      // ---------------------------------------------------
      // YENİ İKON: Barın Ucuna Dönen Candy Bomb Çizimi
      // ---------------------------------------------------
      // Güç doldukça ikon büyür ve döner. Tam dolu değilse şeffaftır ve yavaş döner.
      final targetIconCenter = Offset(
        startX + barWidth + 5,
        startY + (barHeight / 2),
      );
      final iconRadius = barHeight * 0.8;

      canvas.save();
      // Eğer güç %100 değilse ikon biraz daha sönük (Opacity)
      if (powerRatio < 1.0) {
        canvas.saveLayer(
          Rect.fromCircle(center: targetIconCenter, radius: iconRadius * 1.5),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.4 + (powerRatio * 0.6)),
        );
      }

      // RainbowBall sınıfındaki çizim metodunu buraya çağırıyoruz! (Dönüş hızı güce göre artar)
      RainbowBall.drawCandyBomb(
        canvas,
        targetIconCenter,
        iconRadius + (powerRatio * 3), // Güç arttıkça ikon hafif şişer
        _animationTime * (1.0 + powerRatio * 4), // Güç arttıkça dönüş hızlanır
      );

      if (powerRatio < 1.0) {
        canvas.restore();
      }
      canvas.restore();
    }

    // Dış Çerçeve (Stroke) (En son çizilir ki her şeyin üstünü temiz kapatsın)
    final borderPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(rrect, borderPaint);
  }
}
