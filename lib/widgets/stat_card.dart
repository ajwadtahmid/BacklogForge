import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class CompletionGradeCard extends StatelessWidget {
  const CompletionGradeCard({
    super.key,
    required this.percent,
    required this.grade,
  });
  final double percent;
  final String grade;

  Color _color() {
    if (grade.startsWith('A')) {
      if (grade == 'A+') return Colors.green[700]!;
      if (grade == 'A-') return Colors.green[300]!;
      return Colors.green;
    }
    if (grade.startsWith('B')) {
      if (grade == 'B+') return Colors.teal[700]!;
      if (grade == 'B-') return Colors.teal[300]!;
      return Colors.teal;
    }
    if (grade.startsWith('C')) {
      if (grade == 'C+') return Colors.amber[700]!;
      if (grade == 'C-') return Colors.amber[300]!;
      return Colors.amber;
    }
    // D grades: warm orange tones — encouraging, not harsh
    if (grade == 'D+') return Colors.orange[300]!;
    if (grade == 'D') return Colors.orange;
    return Colors.red; // D-
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.workspace_premium,
              size: 22,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 6),
            Text(
              grade,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _color(),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${percent.toStringAsFixed(1)}% · Library Completed',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
