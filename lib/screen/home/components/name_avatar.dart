import 'package:flutter/material.dart';

class NameAvatar extends StatelessWidget {
  final String name;
  final double radius;

  const NameAvatar({
    super.key,
    required this.name,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: colorForName(name),
      child: Text(
        _initials(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final words = trimmed.split(RegExp(r'\s+'));

    if (words.length == 1) {
      return words.first.substring(0, words.first.length >= 2 ? 2 : 1).toUpperCase();
    }

    return (words.first[0] + words.last[0]).toUpperCase();
  }

  static Color colorForName(String text) {
    const colors = [
      Color(0xFFE57373),
      Color(0xFF64B5F6),
      Color(0xFF81C784),
      Color(0xFFFFB74D),
      Color(0xFF9575CD),
      Color(0xFF4DB6AC),
      Color(0xFF90A4AE),
      Color(0xFFA1887F),
    ];

    return colors[text.hashCode.abs() % colors.length];
  }
}
