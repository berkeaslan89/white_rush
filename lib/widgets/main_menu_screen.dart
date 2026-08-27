import 'how_to_play_dialog.dart';
import 'package:flutter/material.dart';
import '../services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flame/game.dart';
import 'menu_background_game.dart';
import '../services/app_strings.dart';

class MainMenuScreen extends StatefulWidget {
  final VoidCallback onPlay;
  const MainMenuScreen({super.key, required this.onPlay});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  final _saveManager = SaveManager();
  int _bestScore = 0;
  int _savedLevel = 1;
  bool _loading = true;
  bool _soundOn = true;
  late AudioPool _clickPool;
  final _bgGame = MenuBackgroundGame();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _playClick() {
    if (_soundOn) {
      try {
        _clickPool.start();
      } catch (_) {}
    }
  }

  Future<void> _loadData() async {
    try {
      _clickPool = await FlameAudio.createPool(
        'ui_click.mp3',
        minPlayers: 2,
        maxPlayers: 4,
      );
    } catch (e) {
      debugPrint('Ses havuzu kurulamadı: $e');
    }

    try {
      await AppStrings.load();
    } catch (e) {
      debugPrint('Dil dosyası yüklenemedi: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    _soundOn = prefs.getBool('soundOn') ?? true;
    final bestScore = await _saveManager.loadBestScore();
    final level = await _saveManager.loadLevel();

    setState(() {
      _bestScore = bestScore;
      _savedLevel = level < 1 ? 1 : level;
      _loading = false;
    });

    final seenTutorial = prefs.getBool('seenTutorial') ?? false;
    if (!seenTutorial && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HowToPlayDialog.show(context);
      });
      await prefs.setBool('seenTutorial', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNewPlayer = _savedLevel <= 1 && _bestScore == 0;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xff111111)),
        GameWidget(game: _bgGame),
        Container(color: Colors.black.withValues(alpha: 0.38)),
        Center(
          child: _loading
              ? const CircularProgressIndicator(color: Colors.white)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Colors.white,
                          Colors.purpleAccent,
                          Colors.cyanAccent,
                        ],
                      ).createShader(bounds),
                      child: const Text(
                        "WHITE RUSH",
                        style: TextStyle(
                          fontSize: 46,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 3,
                          shadows: [
                            Shadow(blurRadius: 20, color: Colors.purpleAccent),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.amberAccent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.emoji_events,
                            color: Colors.amberAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppStrings.get('best_score', {
                              'puan': '$_bestScore',
                            }),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 18,
                        ),
                        backgroundColor: Colors.purpleAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () {
                        _playClick();
                        widget.onPlay();
                      },
                      child: Text(
                        isNewPlayer
                            ? AppStrings.get('play')
                            : AppStrings.get('resume', {
                                'bölüm': '$_savedLevel',
                              }),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _pillButton(
                      icon: Icons.help_outline,
                      label: AppStrings.get('how_to_play'),
                      color: Colors.tealAccent.shade400,
                      onPressed: () {
                        _playClick();
                        HowToPlayDialog.show(context);
                      },
                    ),
                    const SizedBox(height: 12),
                    _pillButton(
                      icon: _soundOn ? Icons.volume_up : Icons.volume_off,
                      label: _soundOn
                          ? AppStrings.get('sound_on')
                          : AppStrings.get('sound_off'),
                      color: Colors.tealAccent.shade400,
                      onPressed: () async {
                        _playClick();
                        final prefs = await SharedPreferences.getInstance();
                        setState(() => _soundOn = !_soundOn);
                        await prefs.setBool('soundOn', _soundOn);
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: ['tr', 'en', 'ru'].map((lang) {
                        final isActive = AppStrings.currentLang == lang;
                        const flags = {
                          'tr': '🇹🇷',
                          'en': '🇬🇧',
                          'ru': '🇷🇺',
                        };
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: GestureDetector(
                            onTap: () async {
                              _playClick();
                              await AppStrings.setLanguage(lang);
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Colors.tealAccent.withValues(alpha: 0.25)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isActive
                                      ? Colors.tealAccent
                                      : Colors.white24,
                                ),
                              ),
                              child: Text(
                                '${flags[lang]}  ${lang.toUpperCase()}',
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.tealAccent
                                      : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _pillButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
