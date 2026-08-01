import 'package:flutter/material.dart';

import '../game/white_rush_game.dart';

class GameOverOverlay extends StatelessWidget {
  final WhiteRushGame game;

  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Game Over',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              'Score: ${game.scoreManager.score}',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            Text(
              'Best Combo: ${game.scoreManager.bestCombo}',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: game.restart,
              child: const Text('Restart'),
            ),
          ],
        ),
      ),
    );
  }
}
