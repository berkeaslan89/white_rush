import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/white_rush_game.dart';
import 'widgets/game_over_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final game = WhiteRushGame();

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: GameWidget(
          game: game,
          overlayBuilderMap: {
            'gameOver': (context, WhiteRushGame g) => GameOverOverlay(game: g),

            // 1. YENİ ŞIK TAHMİN ET BUTONU (Sürekli ekranda duran HUD)
            'hudButton': (context, WhiteRushGame g) {
              return Positioned(
                top: 20,
                right: 20,
                child: GestureDetector(
                  onTap: g.openGuessMenu,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.purple, Colors.blue],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 5,
                          offset: Offset(2, 2),
                        ),
                      ],
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Tahmin Et!",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },

            // 2. PROFESYONELLEŞTİRİLMİŞ ŞIKLAR MENÜSÜ
            'guessMenu': (context, WhiteRushGame g) {
              return Center(
                child: Container(
                  padding: const EdgeInsets.all(25),
                  margin: const EdgeInsets.symmetric(horizontal: 30),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 15,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.help_outline,
                        size: 50,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Resimdeki Kim/Ne?",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 25),

                      ...g.currentOptions.map((option) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: InkWell(
                            onTap: () => g.submitGuess(option),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF42A5F5),
                                    Color(0xFF1E88E5),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  option,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),

                      const SizedBox(height: 20),
                      TextButton.icon(
                        icon: const Icon(Icons.arrow_back, color: Colors.grey),
                        label: const Text(
                          "Vazgeç, kazımaya devam et",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        onPressed: () {
                          g.overlays.remove('guessMenu');
                          g.overlays.add('hudButton'); // Butonu geri getir
                          g.resumeEngine();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },

            // 3. YENİ BİLİNCE ÇIKAN TEBRİKLER EFEKTİ / EKRANI
            'successOverlay': (context, WhiteRushGame g) {
              return Center(
                child: TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 500),
                  tween: Tween<double>(begin: 0.5, end: 1.0),
                  builder: (context, double val, child) {
                    return Transform.scale(
                      scale: val,
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.shade700.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.green,
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.yellow,
                              size: 80,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "HARİKA!",
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              "+${g.lastEarnedPoints} Puan Kazandın",
                              style: const TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          },
        ),
      ),
    ),
  );
}
