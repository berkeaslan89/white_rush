import 'package:flutter/material.dart';
import '../services/app_strings.dart';

class CategorySelectScreen extends StatelessWidget {
  final String currentCategory;
  const CategorySelectScreen({super.key, required this.currentCategory});

  static const categories = [
    {'value': 'karakter', 'icon': Icons.face},
    {'value': 'bayrak', 'icon': Icons.flag},
    {'value': 'hayvan', 'icon': Icons.pets},
    {'value': 'nesne', 'icon': Icons.category},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff111111),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(AppStrings.get('choose_category')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final value = categories[i]['value'] as String;
          final icon = categories[i]['icon'] as IconData;
          final isActive = value == currentCategory;
          return GestureDetector(
            onTap: () => Navigator.pop(context, value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.purpleAccent.withValues(alpha: 0.2)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive ? Colors.purpleAccent : Colors.white24,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: isActive ? Colors.purpleAccent : Colors.white70,
                    size: 26,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    AppStrings.get('category_$value'),
                    style: TextStyle(
                      color: isActive ? Colors.purpleAccent : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const Spacer(),
                  if (isActive)
                    const Icon(Icons.check_circle, color: Colors.purpleAccent),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
