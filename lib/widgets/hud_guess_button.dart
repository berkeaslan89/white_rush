import 'package:flutter/material.dart';

class HudGuessButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const HudGuessButton({super.key, required this.label, required this.onTap});

  @override
  State<HudGuessButton> createState() => _HudGuessButtonState();
}

class _HudGuessButtonState extends State<HudGuessButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final pulse = 1.0 + 0.05 * (1 - (2 * t - 1).abs());
          return Transform.scale(
            scale: pulse,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1 + 2 * t, 0),
                  end: Alignment(1 + 2 * t, 0),
                  colors: const [
                    Colors.purple,
                    Colors.blue,
                    Colors.cyanAccent,
                    Colors.purple,
                  ],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 6,
                    offset: Offset(2, 2),
                  ),
                ],
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
