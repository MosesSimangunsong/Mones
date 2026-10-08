import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/route_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/category_icon_mapper.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/daily_transaction_summary.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/transaction_source_label.dart';
import '../../data/models/money_transaction.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../shared/layouts/app_page.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/app_loading_state.dart';
import '../../shared/widgets/app_metric_tile.dart';
import '../../shared/widgets/transaction_tile.dart';
import 'widgets/month_switcher_card.dart';
import 'widgets/transaction_detail_sheet.dart';

/// Riwayat transaksi per bulan: ringkasan, transaksi per hari, dan rincian.
class RiwayatBulananScreen extends StatefulWidget {
  const RiwayatBulananScreen({
    super.key,
    required this.transactionRepository,
    this.initialMonth,
  });

  final TransactionRepository transactionRepository;
  final DateTime? initialMonth;

  @override
  State<RiwayatBulananScreen> createState() => _RiwayatBulananScreenState();
}

class _RiwayatBulananScreenState extends State<RiwayatBulananScreen> {
  late DateTime _month;
  StreamSubscription<void>? _subscription;
  List<MoneyTransaction>? _transactions;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final DateTime base = widget.initialMonth ?? DateTime.now();
    _month = DateTime(base.year, base.month);
    _subscription = widget.transactionRepository
        .watchTransactions()
        .listen((_) => _load());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  bool get _isCurrentMonth {
    final DateTime now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  Future<void> _load() async {
    final DateTime requested = _month;
    try {
      final List<MoneyTransaction> items = await widget.transactionRepository
          .getTransactionsByLocalMonth(requested);
      if (!mounted || requested != _month) {
        return;
      }
      setState(() {
        _transactions = items;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _transactions = null;
      _error = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final List<MoneyTransaction>? transactions = _transactions;

    return AppPage(
      title: 'Riwayat bulanan',
      description: 'Lihat transaksi per hari beserta rinciannya.',
      actions: <Widget>[
        IconButton(
          tooltip: 'Buat e-statement PDF',
          onPressed: () =>
              context.push(RouteConstants.estatement, extra: _month),
          icon: const Icon(LucideIcons.fileText),
        ),
        IconButton(
          tooltip: 'Import dari PDF atau gambar',
          onPressed: () => context.push(RouteConstants.importTransaksi),
          icon: const Icon(LucideIcons.fileUp),
        ),
      ],
      children: <Widget>[
        MonthSwitcherCard(
          month: _month,
          canGoNext: !_isCurrentMonth,
          onPrevious: () => _changeMonth(-1),
          onNext: () => _changeMonth(1),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_error != null)
          AppErrorState(
            title: 'Riwayat belum bisa ditampilkan',
            description: 'Coba muat ulang. Data lokalmu tetap aman.',
            onRetry: _load,
          )
        else if (transactions == null)
          const AppLoadingState(message: 'Memuat transaksi bulan ini')
        else if (transactions.isEmpty)
          AppEmptyState(
            icon: LucideIcons.calendarX,
            title: 'Belum ada transaksi',
            description:
                'Tidak ada transaksi pada ${DateFormatter.formatLongMonthYear(_month)}. '
                'Catat manual atau import dari PDF/gambar.',
            primaryActionLabel: 'Import PDF/gambar',
            onPrimaryAction: () => context.push(RouteConstants.importTransaksi),
          )
        else
          ..._buildContent(transactions),
      ],
    );
  }

  List<Widget> _buildContent(List<MoneyTransaction> transactions) {
    final List<DailyTransactionSummary> days =
        DailyTransactionAggregator.group(transactions);
    double income = 0;
    double expense = 0;
    for (final DailyTransactionSummary day in days) {
      income += day.incomeTotal;
      expense += day.expenseTotal;
    }

    return <Widget>[
      _MonthSummaryCard(
        income: income,
        expense: expense,
        transactionCount: transactions.length,
        activeDays: days.length,
      ),
      const SizedBox(height: AppSpacing.xl),
      Text('Per hari', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.md),
      for (final DailyTransactionSummary day in days) ...<Widget>[
        _DayCard(
          day: day,
          onTapTransaction: _showDetail,
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    ];
  }

  Future<void> _showDetail(MoneyTransaction transaction) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return TransactionDetailSheet(
          transaction: transaction,
          onEdit: () {
            Navigator.of(sheetContext).pop();
            context.push('${RouteConstants.keuangan}/${transaction.uuid}/edit');
          },
        );
      },
    );
  }
}

class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({
    required this.income,
    required this.expense,
    required this.transactionCount,
    required this.activeDays,
  });

  final double income;
  final double expense;
  final int transactionCount;
  final int activeDays;

  @override
  Widget build(BuildContext context) {
    final double net = income - expense;

    return AppCard(
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.lg,
        children: <Widget>[
          SizedBox(
            width: 140,
            child: AppMetricTile(
              label: 'Pemasukan',
              value: CurrencyFormatter.formatRupiah(income),
              valueColor: AppColors.success,
            ),
          ),
          SizedBox(
            width: 140,
            child: AppMetricTile(
              label: 'Pengeluaran',
              value: CurrencyFormatter.formatRupiah(expense),
              valueColor: AppColors.danger,
            ),
          ),
          SizedBox(
            width: 140,
            child: AppMetricTile(
              label: 'Selisih',
              value: CurrencyFormatter.formatRupiah(net),
              valueColor: net >= 0 ? AppColors.primaryDark : AppColors.danger,
            ),
          ),
          SizedBox(
            width: 140,
            child: AppMetricTile(
              label: 'Transaksi',
              value: '$transactionCount',
              supportingText: 'di $activeDays hari',
              valueColor: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.onTapTransaction});

  final DailyTransactionSummary day;
  final ValueChanged<MoneyTransaction> onTapTransaction;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            DateFormatter.formatWeekdayDate(day.date),
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.md,
            children: <Widget>[
              if (day.incomeTotal > 0)
                Text(
                  '+${CurrencyFormatter.formatRupiah(day.incomeTotal)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (day.expenseTotal > 0)
                Text(
                  '-${CurrencyFormatter.formatRupiah(day.expenseTotal)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              Text(
                '${day.transactions.length} transaksi',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          for (int index = 0; index < day.transactions.length; index++)
            TransactionTile(
              title: day.transactions[index].title,
              category:
                  '${day.transactions[index].categoryNameSnapshot} - ${day.transactions[index].paymentMethod}',
              formattedAmount: CurrencyFormatter.formatRupiah(
                day.transactions[index].amount,
              ),
              isIncome: day.transactions[index].type == 'income',
              categoryIcon: CategoryIconMapper.fromCategoryName(
                day.transactions[index].categoryNameSnapshot,
              ),
              formattedDate:
                  TransactionSourceLabel.hasTimeOfDay(
                    day.transactions[index].source,
                  )
                  ? DateFormatter.formatTime(
                      day.transactions[index].transactionDate,
                    )
                  : 'Tanpa jam',
              onTap: () => onTapTransaction(day.transactions[index]),
              showDivider: index < day.transactions.length - 1,
            ),
        ],
      ),
    );
  }
}
