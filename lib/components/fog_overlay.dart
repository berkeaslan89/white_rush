// fog_overlay.dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

// Siste açılan deliği animasyonlu yapmak için yeni bir sınıf
class FogHole {
  final Vector2 center;
  final double targetRadius;
  double currentRadius = 0.0; // 0'dan başlayıp büyüyecek

  FogHole({required this.center, required this.targetRadius});
}

class FogOverlay extends PositionComponent with HasGameRef {
  final List<FogHole> _holes = [];
  final Paint _blackPaint = Paint()..color = const Color(0xff111111);
  late Paint _clearPaint;

  bool hidden = false;

  FogOverlay({required Vector2 size}) : super(size: size) {
    // Sisin kenarlarını yumuşatmak için Blur (Bulanıklık) efekti ekledik!
    _clearPaint = Paint()
      ..blendMode = BlendMode.clear
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
  }

  void revealAt(Rect rect) {
    _holes.add(
      FogHole(
        center: Vector2(rect.center.dx, rect.center.dy),
        targetRadius: rect.width / 1.0, // Deliği biraz daha genişlettik
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (hidden) return;

    // Tıklanan yerlerin yumuşak bir şekilde büyüyerek açılmasını sağlar (Animasyon)
    for (var hole in _holes) {
      if (hole.currentRadius < hole.targetRadius) {
        // Yumuşak geçişli (Ease-out) büyüme formülü
        hole.currentRadius +=
            (hole.targetRadius - hole.currentRadius) * 12 * dt;
      }
    }
  }

  void resetOverlay() {
    _holes.clear();
    hidden = false;
  }

  void hideCompletely() {
    hidden = true;
  }

  @override
  void render(Canvas canvas) {
    if (hidden) return;

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.x, size.y), Paint());
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _blackPaint);

    // Delikleri çiz
    for (final hole in _holes) {
      canvas.drawCircle(
        hole.center.toOffset(),
        hole.currentRadius,
        _clearPaint,
      );
    }

    canvas.restore();
  }
}
