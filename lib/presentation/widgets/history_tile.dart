import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../data/models/counter_model.dart';
import '../../utils/helpers/date_helper.dart';
import '../../utils/helpers/format_helper.dart';

class HistoryTile extends StatelessWidget {
  final OperationModel operation;

  const HistoryTile({super.key, required this.operation});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = _operationDetails();
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(26),
          child: Icon(icon, color: color),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${FormatHelper.formatNumber(operation.previousValue)} → ${FormatHelper.formatNumber(operation.newValue)}',
        ),
        trailing: Text(
          DateHelper.formatTime(operation.timestamp),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  (IconData, Color, String) _operationDetails() {
    return switch (operation.type) {
      'increment' => (Icons.arrow_upward, AppColors.positive, 'Increment'),
      'decrement' => (Icons.arrow_downward, AppColors.negative, 'Decrement'),
      'reset' => (Icons.refresh, AppColors.reset, 'Reset'),
      'custom' => (Icons.edit, AppColors.primary, 'Custom Value'),
      _ => (Icons.help_outline, AppColors.neutral, 'Unknown'),
    };
  }
}
