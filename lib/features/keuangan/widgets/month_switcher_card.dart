import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/app_card.dart';

/// Pemilih bulan dengan tombol sebelumnya/berikutnya.
class MonthSwitcherCard extends StatelessWidget {
  const MonthSwitcherCard({
    super.key,
    required this.month,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Bulan sebelumnya',
            onPressed: onPrevious,
            icon: const Icon(LucideIcons.chevronLeft),
          ),
          Expanded(
            child: Text(
              DateFormatter.formatLongMonthYear(month),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'Bulan berikutnya',
            onPressed: canGoNext ? onNext : null,
            icon: const Icon(LucideIcons.chevronRight),
          ),
        ],
      ),
    );
  }
}
