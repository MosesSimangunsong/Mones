import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/category_icon_mapper.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/transaction_source_label.dart';
import '../../../data/models/money_transaction.dart';
import '../../../shared/widgets/app_icon_container.dart';

/// Rincian lengkap satu transaksi.
class TransactionDetailSheet extends StatelessWidget {
  const TransactionDetailSheet({
    super.key,
    required this.transaction,
    this.onEdit,
  });

  final MoneyTransaction transaction;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final bool isIncome = transaction.type == 'income';
    final Color amountColor = isIncome ? AppColors.success : AppColors.danger;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String? note = transaction.note?.trim();

    final String dateLabel = TransactionSourceLabel.hasTimeOfDay(
          transaction.source,
        )
        ? DateFormatter.formatDateTime(transaction.transactionDate)
        : DateFormatter.formatWeekdayDate(transaction.transactionDate);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                AppIconContainer(
                  icon: CategoryIconMapper.fromCategoryName(
                    transaction.categoryNameSnapshot,
                  ),
                  foregroundColor: amountColor,
                  backgroundColor: isIncome
                      ? AppColors.successSoft
                      : AppColors.dangerSoft,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    transaction.title,
                    style: textTheme.titleMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '${isIncome ? '+' : '-'}${CurrencyFormatter.formatRupiah(transaction.amount)}',
              style: textTheme.headlineSmall?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _DetailRow(label: 'Tipe', value: isIncome ? 'Pemasukan' : 'Pengeluaran'),
            _DetailRow(label: 'Kategori', value: transaction.categoryNameSnapshot),
            _DetailRow(label: 'Metode pembayaran', value: transaction.paymentMethod),
            _DetailRow(label: 'Tanggal', value: dateLabel),
            _DetailRow(
              label: 'Sumber',
              value: TransactionSourceLabel.of(transaction.source),
            ),
            if (note != null && note.isNotEmpty)
              _DetailRow(label: 'Catatan', value: note),
            if (onEdit != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(LucideIcons.pencil, size: 18),
                  label: const Text('Edit transaksi'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
