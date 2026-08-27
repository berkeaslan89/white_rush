import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

import '../game/white_rush_game.dart' show RainbowBall;

/// Menüde arka planda dönen, tamamen dekoratif (dokunulamaz, puansız)
/// bir "oyun vitrini". Gerçek WhiteRushGame ile hiçbir bağlantısı yok.
class MenuBackgroundGame extends FlameGame {
  final _random = Random();

  @override
  Color backgroundColor() => const Color(0xff111111);

  @override
  Future<void> onLoad() async {
    for (int i = 0; i < 9; i++) {
      add(_buildDecoSquare());
    }

    add(
      TimerComponent(
        period: 4.0,
        repeat: true,
        onTick: () => add(_buildDecoBall()),
      ),
    );

    add(
      TimerComponent(
        period: 3.0,
        repeat: true,
        onTick: () => add(_buildDecoDiamond()),
      ),
    );
  }

  DecoSquare _buildDecoSquare() {
    final colors = [
      Colors.white,
      Colors.white,
      Colors.white,
      const Color(0xFF90A4AE),
      Colors.redAccent,
      Colors.lightBlueAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.pinkAccent,
      Colors.amberAccent,
    ];
    final squareSize = 22.0 + _random.nextDouble() * 20;
    return DecoSquare(
      position: Vector2(
        _random.nextDouble() * size.x,
        _random.nextDouble() * size.y,
      ),
      velocity: Vector2(
        (_random.nextDouble() - 0.5) * 90,
        (_random.nextDouble() - 0.5) * 90,
      ),
      squareSize: squareSize,
      color: colors[_random.nextInt(colors.length)],
    );
  }

  DecoBall _buildDecoBall() {
    return DecoBall(
      position: Vector2(
        _random.nextDouble() * size.x,
        _random.nextDouble() * size.y,
      ),
      velocity: Vector2(
        (_random.nextDouble() - 0.5) * 40,
        (_random.nextDouble() - 0.5) * 40,
      ),
    );
  }

  DecoDiamond _buildDecoDiamond() {
    return DecoDiamond(
      position: Vector2(
        _random.nextDouble() * size.x,
        _random.nextDouble() * size.y,
      ),
      velocity: Vector2(
        (_random.nextDouble() - 0.5) * 70,
        (_random.nextDouble() - 0.5) * 70,
      ),
    );
  }
}

/// Sadece görsel: köşeli, hafif parlak, sekip duran dekoratif kare.
class DecoSquare extends RectangleComponent
    with HasGameReference<MenuBackgroundGame> {
  Vector2 velocity;
  double _age = 0;

  DecoSquare({
    required Vector2 position,
    required this.velocity,
    required double squareSize,
    required Color color,
  }) : super(
         position: position,
         size: Vector2.all(squareSize),
         anchor: Anchor.center,
         paint: Paint()..color = color,
       );

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    position += velocity * dt;

    final gameSize = game.size;
    final half = size.x / 2;
    if (position.x - half < 0) {
      position.x = half;
      velocity.x = velocity.x.abs();
    } else if (position.x + half > gameSize.x) {
      position.x = gameSize.x - half;
      velocity.x = -velocity.x.abs();
    }
    if (position.y - half < 0) {
      position.y = half;
      velocity.y = velocity.y.abs();
    } else if (position.y + half > gameSize.y) {
      position.y = gameSize.y - half;
      velocity.y = -velocity.y.abs();
    }
  }

  @override
  void render(Canvas canvas) {
    final bounce = 1.0 + 0.05 * sin(_age * 4);
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(bounce);
    canvas.translate(-size.x / 2, -size.y / 2);

    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.x * 0.32));

    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(paint.color, Colors.white, 0.4)!,
          paint.color,
          Color.lerp(paint.color, Colors.black, 0.25)!,
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, basePaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.x * 0.06
      ..color = Colors.white.withValues(alpha: 0.35);
    canvas.drawRRect(rrect, borderPaint);

    canvas.restore();
  }
}

/// Ekranda süzülen, dönen, bir süre sonra küçük bir parıltıyla kaybolan
/// dekoratif gökkuşağı topu.
class DecoBall extends PositionComponent
    with HasGameReference<MenuBackgroundGame> {
  final Vector2 velocity;
  double _rotation = 0;
  double _life = 0;
  final double _maxLife = 6.0;

  DecoBall({required Vector2 position, required this.velocity})
    : super(position: position, size: Vector2.all(46), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    scale = Vector2.zero();
    add(
      ScaleEffect.to(
        Vector2.all(1.0),
        EffectController(duration: 0.5, curve: Curves.elasticOut),
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _rotation += dt * 2.5;
    _life += dt;
    position += velocity * dt;

    final gameSize = game.size;
    final half = size.x / 2;
    if (position.x - half < 0 || position.x + half > gameSize.x) {
      velocity.x = -velocity.x;
    }
    if (position.y - half < 0 || position.y + half > gameSize.y) {
      velocity.y = -velocity.y;
    }

    if (_life >= _maxLife) {
      _burst();
      removeFromParent();
    }
  }

  void _burst() {
    final rnd = Random();
    game.add(
      ParticleSystemComponent(
        position: position,
        particle: Particle.generate(
          count: 16,
          lifespan: 0.5,
          generator: (i) {
            final angle = rnd.nextDouble() * 2 * pi;
            final speed = rnd.nextDouble() * 140 + 60;
            return AcceleratedParticle(
              speed: Vector2(cos(angle), sin(angle)) * speed,
              child: CircleParticle(
                radius: 2.5 + rnd.nextDouble() * 2.5,
                paint: Paint()..color = Colors.white.withValues(alpha: 0.8),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final fadeIn = (_life / 0.4).clamp(0.0, 1.0);
    final fadeOut = _life > _maxLife - 1.0
        ? (_maxLife - _life).clamp(0.0, 1.0)
        : 1.0;
    final opacity = fadeIn * fadeOut;

    final layerRect = Rect.fromLTWH(-size.x, -size.y, size.x * 3, size.y * 3);
    canvas.saveLayer(
      layerRect,
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
    RainbowBall.drawCandyBomb(
      canvas,
      Offset(size.x / 2, size.y / 2),
      size.x / 2,
      _rotation,
    );
    canvas.restore();
  }
}

/// Menüde ara sıra beliren dekoratif elmas — gerçek oyundaki gibi
/// parlıyor ama geri sayımı/tıklanabilirliği yok.
class DecoDiamond extends PositionComponent
    with HasGameReference<MenuBackgroundGame> {
  final Vector2 velocity;
  double _life = 0;
  final double _maxLife = 5.0;

  DecoDiamond({required Vector2 position, required this.velocity})
    : super(position: position, size: Vector2.all(34), anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    position += velocity * dt;

    final gameSize = game.size;
    final half = size.x / 2;
    if (position.x - half < 0 || position.x + half > gameSize.x) {
      velocity.x = -velocity.x;
    }
    if (position.y - half < 0 || position.y + half > gameSize.y) {
      velocity.y = -velocity.y;
    }

    if (_life >= _maxLife) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final fadeIn = (_life / 0.4).clamp(0.0, 1.0);
    final fadeOut = _life > _maxLife - 1.0
        ? (_maxLife - _life).clamp(0.0, 1.0)
        : 1.0;
    final opacity = fadeIn * fadeOut;

    final glowPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.4 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x * 0.6, glowPaint);

    final diamondSpan = TextSpan(
      text: '💎',
      style: TextStyle(
        fontSize: size.x * 0.85,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
    final painter = TextPainter(
      text: diamondSpan,
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    painter.paint(
      canvas,
      Offset((size.x - painter.width) / 2, (size.y - painter.height) / 2),
    );
  }
}
