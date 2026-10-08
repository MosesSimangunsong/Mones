import '../../data/models/money_transaction.dart';

/// Transaksi pada satu hari kalender (zona waktu perangkat) beserta totalnya.
class DailyTransactionSummary {
  const DailyTransactionSummary({
    required this.date,
    required this.transactions,
    required this.incomeTotal,
    required this.expenseTotal,
  });

  /// Tengah malam lokal pada hari tersebut.
  final DateTime date;

  /// Terbaru lebih dulu.
  final List<MoneyTransaction> transactions;
  final double incomeTotal;
  final double expenseTotal;

  double get net => incomeTotal - expenseTotal;
}

class DailyTransactionAggregator {
  const DailyTransactionAggregator._();

  /// Mengelompokkan transaksi per hari, hari terbaru lebih dulu.
  static List<DailyTransactionSummary> group(
    Iterable<MoneyTransaction> transactions,
  ) {
    final Map<DateTime, List<MoneyTransaction>> byDay =
        <DateTime, List<MoneyTransaction>>{};

    for (final MoneyTransaction transaction in transactions) {
      final DateTime local = transaction.transactionDate.toLocal();
      final DateTime day = DateTime(local.year, local.month, local.day);
      byDay.putIfAbsent(day, () => <MoneyTransaction>[]).add(transaction);
    }

    final List<DateTime> days = byDay.keys.toList()
      ..sort((DateTime a, DateTime b) => b.compareTo(a));

    return <DailyTransactionSummary>[
      for (final DateTime day in days) _summarize(day, byDay[day]!),
    ];
  }

  static DailyTransactionSummary _summarize(
    DateTime day,
    List<MoneyTransaction> items,
  ) {
    items.sort(
      (MoneyTransaction a, MoneyTransaction b) =>
          b.transactionDate.compareTo(a.transactionDate),
    );

    double income = 0;
    double expense = 0;
    for (final MoneyTransaction item in items) {
      if (item.type == 'income') {
        income += item.amount;
      } else if (item.type == 'expense') {
        expense += item.amount;
      }
    }

    return DailyTransactionSummary(
      date: day,
      transactions: items,
      incomeTotal: income,
      expenseTotal: expense,
    );
  }
}
