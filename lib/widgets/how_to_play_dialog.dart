import 'package:flutter/material.dart';

class HowToPlayDialog extends StatelessWidget {
  const HowToPlayDialog({super.key});

  static void show(BuildContext context) {
    showDialog(context: context, builder: (context) => const HowToPlayDialog());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xff1a1a1a),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Nasıl Oynanır?",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _rule(
              "⬜",
              "Beyaz kareye dokun",
              "Puan kazanırsın, resmin bir parçası açılır.",
            ),
            _rule(
              "🔲",
              "Gri (sahte beyaz) veya renkli kareye dokunma",
              "Oyun anında biter.",
            ),
            _rule(
              "💎",
              "Elmasa dokun",
              "Bonus puan! Ama süresi var, süre bitmeden yakala.",
            ),
            _rule(
              "✨",
              "İki beyaz kare çarpışırsa",
              "Renk değiştirebilirler, dikkatli ol.",
            ),
            _rule(
              "🌈",
              "Güç barı dolunca",
              "Gökkuşağı topuna 5 kere dokun, tüm kareler donup beyaza döner!",
            ),
            _rule(
              "🔍",
              "Yeterince kare açtıysan",
              "\"Tahmin Et!\" butonuna bas, resmi bil, bir sonraki bölüme geç.",
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                ),
                child: const Text("Anladım"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rule(String emoji, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
