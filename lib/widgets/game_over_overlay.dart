import 'package:flutter/material.dart';
import '../game/white_rush_game.dart';
import '../services/app_strings.dart';

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
            Text(
              AppStrings.get('game_over_title'),
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.get('game_over_score', {
                'puan': '${game.scoreManager.score}',
              }),
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            Text(
              AppStrings.get('game_over_combo', {
                'sayı': '${game.scoreManager.bestCombo}',
              }),
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: game.restart,
              child: Text(AppStrings.get('restart')),
            ),
          ],
        ),
      ),
    );
  }
}
