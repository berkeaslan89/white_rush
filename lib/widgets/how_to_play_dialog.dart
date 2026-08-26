import 'package:flutter/material.dart';
import '../services/app_strings.dart';

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
            Text(
              AppStrings.get('how_to_play_title'),
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _rule(
              "⬜",
              AppStrings.get('rule1_title'),
              AppStrings.get('rule1_desc'),
            ),
            _rule(
              "🔲",
              AppStrings.get('rule2_title'),
              AppStrings.get('rule2_desc'),
            ),
            _rule(
              "💎",
              AppStrings.get('rule3_title'),
              AppStrings.get('rule3_desc'),
            ),
            _rule(
              "✨",
              AppStrings.get('rule4_title'),
              AppStrings.get('rule4_desc'),
            ),
            _rule(
              "🌈",
              AppStrings.get('rule5_title'),
              AppStrings.get('rule5_desc'),
            ),
            _rule(
              "🔍",
              AppStrings.get('rule6_title'),
              AppStrings.get('rule6_desc'),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                ),
                child: Text(AppStrings.get('got_it')),
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
