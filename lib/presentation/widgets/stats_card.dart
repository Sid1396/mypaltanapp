import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

class StatsCard extends StatelessWidget {
  final int totalIncrements;
  final int totalDecrements;
  final int totalOperations;

  const StatsCard({
    super.key,
    required this.totalIncrements,
    required this.totalDecrements,
    required this.totalOperations,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistics',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Increments',
                  value: totalIncrements,
                  color: AppColors.positive,
                  icon: Icons.arrow_upward,
                ),
                _StatItem(
                  label: 'Decrements',
                  value: totalDecrements,
                  color: AppColors.negative,
                  icon: Icons.arrow_downward,
                ),
                _StatItem(
                  label: 'Total',
                  value: totalOperations,
                  color: AppColors.primary,
                  icon: Icons.bar_chart,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
          ),
        ),
      ],
    );
  }
}
