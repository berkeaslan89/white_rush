import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flame/effects.dart';
import 'dart:math';
import 'package:flame/collisions.dart'; // Çarpışma eklentisi

import '../game/white_rush_game.dart';
import '../models/square_type.dart';

class MovingSquare extends RectangleComponent
    with TapCallbacks, HasGameReference<WhiteRushGame>, CollisionCallbacks {
  SquareType type;
  late Vector2 velocity;

  double _lifeTimer = 0;
  late double _maxLife;
  final _random = Random();
  Vector2 _savedVelocity = Vector2.zero();
  Vector2? pendingVelocity; // doğum sırasında henüz uygulanmamış hedef hız
  bool isFrozen = false;
  bool isSpawning = false;

  // Sadece BİR TANE _animationTime tanımlıyoruz
  double _animationTime = 0;

  MovingSquare({
    required this.type,
    required Vector2 position,
    required this.velocity,
    required double squareSize,
    required Color color,
  }) : super(
         position: position,
         size: Vector2.all(squareSize),
         anchor: Anchor.center,
         paint: Paint()..color = color,
       ) {
    _resetLife();
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    add(CircleHitbox());

    // YENİ: Başlangıçta kareler ekrana tatlıca büyüyerek girer
    // KÜÇÜK KARE SORUNU: respawnSquare()'deki gibi, büyüme animasyonu
    // bitene kadar çarpışma fiziğini devre dışı bırakıyoruz. Aksi halde
    // kare henüz küçükken (scale < 1.0) diğerleriyle çarpışıp küçük
    // haliyle ekranda dolaşabiliyor.
    isSpawning = true;
    scale = Vector2.zero();
    final growEffect = ScaleEffect.to(
      Vector2.all(1.0),
      EffectController(duration: 0.5, curve: Curves.easeOutBack),
    );
    growEffect.onComplete = () => isSpawning = false;
    add(growEffect);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (other is MovingSquare) {
      // Eğer karelerden birinin hızı sıfırsa (Yani hala zarın içindeyse) çarpışmayı yok say!
      if (this.isSpawning ||
          other.isSpawning ||
          this.isFrozen ||
          other.isFrozen) {
        return;
      }

      // ---------------------------------------------------------
      // YENİ EKLENEN KISIM: SADECE İKİ BEYAZ KARE ÇARPIŞIRSA
      // ---------------------------------------------------------
      if (this.type == SquareType.white && other.type == SquareType.white) {
        this.mutateFromWhite();
        other.mutateFromWhite();
        game.ensureWhiteQuota(exclude: [this, other]);
      }
      // ---------------------------------------------------------

      final collisionNormal = (position - other.position).normalized();
      final relativeVelocity = velocity - other.velocity;
      final speedAlongNormal = relativeVelocity.dot(collisionNormal);

      // Kareler zaten birbirinden uzaklaşıyorsa işlem yapma
      if (speedAlongNormal > 0) return;

      // Hızları çarpışma yönünde aktar (Bilardo sekmesi)
      velocity -= collisionNormal * speedAlongNormal;
      other.velocity += collisionNormal * speedAlongNormal;
    }
  }

  // YENİ FONKSİYON: Beyaz kareyi renkliye çeviren ve efekt oynatan metod
  void mutateFromWhite() {
    // Zaten beyaz değilse işlem yapma (Çarpışmada çift tetiklenmeyi önlemek için)
    if (type != SquareType.white) return;

    // Türünü normal renkli şeker yap
    type = SquareType.colorful;

    // Oyundaki aktif renk havuzundan rastgele bir renk seç ve ata
    final currentColors = game.activeColors;
    paint.color = currentColors[_random.nextInt(currentColors.length)];

    // son eklenen kucuk kare sorunu kodu baslangic
    removeAll(children.whereType<TimerComponent>());
    removeAll(
      children.whereType<ScaleEffect>(),
    ); // YENİ: çakışan eski animasyonu temizle
    scale = Vector2.all(1.0); // YENİ: temiz taban
    isSpawning = false;

    // son eklenen kucuk kare sorunu kodu bitis

    // Oyuncunun bu değişimi fark etmesi için kare anlık olarak büyüyüp küçülsün (Sürpriz efekti)
    add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.3), // %30 büyür
          EffectController(duration: 0.1, curve: Curves.easeOut),
        ),
        ScaleEffect.to(
          Vector2.all(1.0), // Normale döner
          EffectController(duration: 0.2, curve: Curves.bounceOut),
        ),
      ]),
    );

    // Ana oyundaki küçük duman/kıvılcım efektini çağır (Oyuncu bir şey olduğunu anlasın)
    game.showMutationEffect(position);
  }

  // Tüm kareleri BEYAZA çeviren ve efekt oynatan özel fonksiyon
  void forceMutateToWhite() {
    type = SquareType.white;
    paint.color = Colors.white;
    // Mkucuk kare sorunu baslangic
    removeAll(children.whereType<TimerComponent>());
    removeAll(
      children.whereType<ScaleEffect>(),
    ); // YENİ: çakışan eski animasyonu temizle
    scale = Vector2.all(1.0); // YENİ: temiz taban
    isSpawning = false;

    // Mkucuk kare sorunu bitis

    // Mutasyon anında görsel şok (büyüyüp küçülme)
    add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.4),
          EffectController(duration: 0.1, curve: Curves.easeOut),
        ),
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: 0.2, curve: Curves.bounceOut),
        ),
      ]),
    );
  }

  // Kareyi belirli bir süre donduran fonksiyon
  void freezeFor(double seconds) {
    if (isFrozen) return;
    isFrozen = true;
    // Kare hâlâ doğum aşamasındaysa (velocity henüz 0), asıl hedef hızı kaydet
    _savedVelocity = (pendingVelocity ?? velocity).clone();
    velocity = Vector2.zero();

    add(
      TimerComponent(
        period: seconds,
        removeOnFinish: true,
        onTick: () {
          velocity = pendingVelocity ?? _savedVelocity;
          pendingVelocity = null;
          isFrozen = false;
        },
      ),
    );
  }

  void _resetLife() {
    _lifeTimer = 0;
    _maxLife = 5.0 + _random.nextDouble() * 4.0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver) return;

    _animationTime += dt;

    if (isFrozen) return;

    // isSpawning ile ilgili bloğu TAMAMEN SİLDİK.
    // Kare artık sadece kendi hızıyla hareket edecek.
    position += velocity * dt;

    if (type == SquareType.gold) {
      _lifeTimer += dt;
      if (_lifeTimer >= _maxLife) {
        game.showBombExplosionEffect(position);
        game.resetCombo();
        game.respawnSquare(this);
        _resetLife();
      }
    }

    // Ekrandan sekme veya karşıdan çıkma mantığı (Burası bir önceki mesajda yaptığımız gibi aynı kalacak)
    final gameSize = game.size;

    if (type == SquareType.gold) {
      final halfSize = size.x / 2;
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
    } else {
      if (position.x > gameSize.x + size.x) {
        position.x = -size.x;
      } else if (position.x < -size.x) {
        position.x = gameSize.x + size.x;
      }
      if (position.y > gameSize.y + size.y) {
        position.y = -size.y;
      } else if (position.y < -size.y) {
        position.y = gameSize.y + size.y;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (type == SquareType.gold) {
      // ALTIN / ELMAS ÇİZİMİ (Değişmedi)
      final glowPaint = Paint()
        ..color = Colors.cyanAccent.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x * 0.6,
        glowPaint,
      );

      final diamondSpan = TextSpan(
        text: '💎',
        style: TextStyle(
          fontSize: size.x * 0.85,
          shadows: const [
            Shadow(
              blurRadius: 5.0,
              color: Colors.black54,
              offset: Offset(2, 2),
            ),
          ],
        ),
      );
      final diamondPainter = TextPainter(
        text: diamondSpan,
        textDirection: TextDirection.ltr,
      );
      diamondPainter.layout();
      diamondPainter.paint(
        canvas,
        Offset(
          (size.x - diamondPainter.width) / 2,
          (size.y - diamondPainter.height) / 2,
        ),
      );

      double timeLeft = max(0.0, _maxLife - _lifeTimer);
      final timeSpan = TextSpan(
        text: timeLeft.toStringAsFixed(2),
        style: TextStyle(
          fontSize: size.x * 0.28,
          fontWeight: FontWeight.w900,
          color: timeLeft <= 2.0 ? Colors.redAccent : Colors.white,
          shadows: const [
            Shadow(blurRadius: 2.0, color: Colors.black, offset: Offset(1, 1)),
            Shadow(blurRadius: 10.0, color: Colors.black, offset: Offset(0, 0)),
          ],
        ),
      );
      final timePainter = TextPainter(
        text: timeSpan,
        textDirection: TextDirection.ltr,
      );
      timePainter.layout();
      timePainter.paint(
        canvas,
        Offset(
          (size.x - timePainter.width) / 2,
          (size.y - timePainter.height) / 2,
        ),
      );
    } else {
      // ----------------------------------------------------
      // YENİ VE GELİŞMİŞ 3 BOYUTLU ŞEKER (CANDY) ÇİZİMİ
      // ----------------------------------------------------

      // JELİBON NEFES ALMA ANİMASYONU: Sinüs dalgası ile sürekli hafifçe büyüyüp küçülür
      final bounceScale = 1.0 + 0.04 * sin(_animationTime * 5);

      canvas.save();
      // Çizimi karenin merkezinden büyütmek için matris kaydırması yapıyoruz
      canvas.translate(size.x / 2, size.y / 2);
      canvas.scale(bounceScale, bounceScale);
      canvas.translate(-size.x / 2, -size.y / 2);

      final rect = Rect.fromLTWH(0, 0, size.x, size.y);
      final radius = Radius.circular(
        size.x * 0.35,
      ); // Biraz daha yuvarlak (3.5)
      final rrect = RRect.fromRectAndRadius(rect, radius);

      Color topColor;
      Color bottomColor;

      // Beyaz ve Gri için renkleri elle veriyoruz ki karışmasınlar!
      if (type == SquareType.white) {
        topColor = Colors.white;
        bottomColor = const Color(0xFFD6D6D6); // Hafif gümüş gölge
      } else if (type == SquareType.fakeWhite) {
        topColor = const Color(0xFFB0BEC5); // Açık metalik gri
        bottomColor = const Color(0xFF546E7A); // Koyu metalik gri
      } else {
        // Renkliler için otomatik 3D gradyan hesaplama
        final hsl = HSLColor.fromColor(paint.color);
        topColor = hsl
            .withLightness(clampDouble(hsl.lightness + 0.15, 0.0, 1.0))
            .toColor();
        bottomColor = hsl
            .withLightness(clampDouble(hsl.lightness - 0.20, 0.0, 1.0))
            .toColor();
      }

      // 1. ZEMİN (Üstten alta 3D Renk Geçişi)
      final basePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [topColor, paint.color, bottomColor],
        ).createShader(rect);
      canvas.drawRRect(rrect, basePaint);

      // 2. PARLAK DIŞ ÇERÇEVE (Kaliteyi artıran detay)
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.x * 0.06
        ..color = Colors.white.withValues(
          alpha: 0.4,
        ); // Yarı saydam beyaz çerçeve
      canvas.drawRRect(rrect, borderPaint);

      // 3. İÇ GÖLGE (Sağ altta toplanan koyuluk)
      final shadowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.x * 0.08
        ..color = Colors.black.withValues(alpha: 0.2);

      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRRect(
        rrect.shift(Offset(size.x * 0.06, size.y * 0.06)),
        shadowPaint,
      );
      canvas.restore();

      // 4. CAM PARLAMASI (Üstteki beyaz parlama)
      final reflectionRect = Rect.fromLTWH(
        size.x * 0.15,
        size.y * 0.08,
        size.x * 0.7,
        size.y * 0.35,
      );

      final reflectionPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.85),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(reflectionRect);

      canvas.drawOval(reflectionRect, reflectionPaint);

      // Animasyon için canvas'ı eski haline getir
      canvas.restore();
    }
  }

  double clampDouble(double x, double min, double max) {
    if (x < min) return min;
    if (x > max) return max;
    return x;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (game.isGameOver) return;

    add(
      ScaleEffect.to(
        Vector2.all(0.90),
        EffectController(duration: 0.05, reverseDuration: 0.05),
      ),
    );

    _resetLife();
    game.handleTap(this);
  }
}
