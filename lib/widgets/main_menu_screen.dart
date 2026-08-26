import 'how_to_play_dialog.dart';
import 'package:flutter/material.dart';
import '../services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flame_audio/flame_audio.dart';
import 'dart:math';
import '../data/levels_repository.dart';

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
  String? _backgroundImagePath;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _playClick() {
    if (_soundOn) FlameAudio.play('ui_click.mp3');
  }

  Future<void> _loadData() async {
    final repo = LevelsRepository();
    await repo.load();
    if (repo.levels.isNotEmpty) {
      final randomLevel = repo.levels[Random().nextInt(repo.levels.length)];
      _backgroundImagePath = 'assets/images/${randomLevel.imagePath}';
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

    // YENİ: İlk açılışta kuralları otomatik göster
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
        if (_backgroundImagePath != null)
          Image.asset(_backgroundImagePath!, fit: BoxFit.cover),
        Container(color: Colors.black.withValues(alpha: 0.65)),
        Center(
          child: _loading
              ? const CircularProgressIndicator(color: Colors.white)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "WHITE RUSH",
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "En Yüksek Puan: $_bestScore",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
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
                        isNewPlayer ? "OYNA" : "DEVAM ET — Bölüm $_savedLevel",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () {
                        _playClick();
                        HowToPlayDialog.show(context);
                      },
                      icon: const Icon(
                        Icons.help_outline,
                        color: Colors.white70,
                      ),
                      label: const Text(
                        "Nasıl Oynanır?",
                        style: TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        setState(() => _soundOn = !_soundOn);
                        await prefs.setBool('soundOn', _soundOn);
                      },
                      icon: Icon(
                        _soundOn ? Icons.volume_up : Icons.volume_off,
                        color: Colors.white70,
                      ),
                      label: Text(
                        _soundOn ? "Ses Açık" : "Ses Kapalı",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
