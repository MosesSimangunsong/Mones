import '../models/money_transaction.dart';
import 'estatement_data.dart';

/// Menyusun data e-statement bulanan dari transaksi yang tersimpan.
class EStatementBuilder {
  const EStatementBuilder._();

  static const String noMethodLabel = 'Tanpa metode';

  /// [month] cukup diisi tahun dan bulan. [allActive] adalah seluruh transaksi
  /// aktif; filter bulan dan sumber dilakukan di sini.
  ///
  /// Saldo dihitung dari transaksi yang tercatat di MoneyPilot (pemasukan
  /// dikurangi pengeluaran), bukan saldo rekening sebenarnya. Saldo awal adalah
  /// akumulasi seluruh transaksi dalam cakupan sebelum awal bulan.
  static EStatementData build({
    required Iterable<MoneyTransaction> allActive,
    required DateTime month,
    required String ownerName,
    required DateTime generatedAt,
    bool importsOnly = true,
  }) {
    final DateTime start = DateTime(month.year, month.month);
    final DateTime nextMonth = DateTime(month.year, month.month + 1);
    final DateTime end = nextMonth.subtract(const Duration(days: 1));

    final List<MoneyTransaction> scoped = allActive
        .where(
          (MoneyTransaction t) =>
              !t.isDeleted && (!importsOnly || t.source.startsWith('import_')),
        )
        .toList();

    final Map<String, double> opening = <String, double>{};
    final List<MoneyTransaction> inPeriod = <MoneyTransaction>[];

    for (final MoneyTransaction transaction in scoped) {
      final DateTime local = transaction.transactionDate.toLocal();
      if (local.isBefore(start)) {
        opening.update(
          _sourceLabel(transaction),
          (double v) => v + _signed(transaction),
          ifAbsent: () => _signed(transaction),
        );
      } else if (local.isBefore(nextMonth)) {
        inPeriod.add(transaction);
      }
    }

    inPeriod.sort((MoneyTransaction a, MoneyTransaction b) {
      final int byDate = a.transactionDate.compareTo(b.transactionDate);
      return byDate != 0 ? byDate : a.updatedAt.compareTo(b.updatedAt);
    });

    final Map<String, double> expense = <String, double>{};
    final Map<String, double> income = <String, double>{};
    final List<EStatementRow> rows = <EStatementRow>[];
    final Map<String, List<EStatementRow>> rowsBySource =
        <String, List<EStatementRow>>{};
    final Map<String, double> runningBySource = Map<String, double>.of(opening);
    double running = opening.values.fold(0, (double s, double v) => s + v);

    for (final MoneyTransaction transaction in inPeriod) {
      final String label = _sourceLabel(transaction);
      final bool isIncome = transaction.type == 'income';
      running += _signed(transaction);

      if (isIncome) {
        income.update(
          label,
          (double v) => v + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
      } else {
        expense.update(
          label,
          (double v) => v + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
      }

      final double sourceBalance =
          (runningBySource[label] ?? 0) + _signed(transaction);
      runningBySource[label] = sourceBalance;

      EStatementRow rowWith(double balance) => EStatementRow(
        date: transaction.transactionDate.toLocal(),
        title: transaction.title,
        source: label,
        detail: transaction.categoryNameSnapshot,
        expense: isIncome ? 0 : transaction.amount,
        income: isIncome ? transaction.amount : 0,
        balance: balance,
      );

      rows.add(rowWith(running));
      rowsBySource
          .putIfAbsent(label, () => <EStatementRow>[])
          .add(rowWith(sourceBalance));
    }

    final List<String> labels = <String>{
      ...opening.keys,
      ...expense.keys,
      ...income.keys,
    }.toList()..sort();

    return EStatementData(
      ownerName: ownerName.trim().isEmpty ? 'Pengguna Mones' : ownerName.trim(),
      periodStart: start,
      periodEnd: end,
      generatedAt: generatedAt,
      serialNumber: _serial(start, generatedAt),
      importsOnly: importsOnly,
      rows: rows,
      sources: <EStatementSourceSummary>[
        for (final String label in labels)
          EStatementSourceSummary(
            label: label,
            opening: opening[label] ?? 0,
            expense: expense[label] ?? 0,
            income: income[label] ?? 0,
            rows: rowsBySource[label] ?? const <EStatementRow>[],
          ),
      ],
    );
  }

  static double _signed(MoneyTransaction transaction) {
    return transaction.type == 'income'
        ? transaction.amount
        : -transaction.amount;
  }

  static String _sourceLabel(MoneyTransaction transaction) {
    final String method = transaction.paymentMethod.trim();
    if (method.isEmpty || method == 'Tidak Dicatat') {
      return noMethodLabel;
    }
    return method;
  }

  static String _serial(DateTime periodStart, DateTime generatedAt) {
    final String yymm =
        '${(periodStart.year % 100).toString().padLeft(2, '0')}'
        '${periodStart.month.toString().padLeft(2, '0')}';
    final String stamp = generatedAt.millisecondsSinceEpoch
        .toRadixString(36)
        .toUpperCase();
    return 'MP-$yymm-$stamp';
  }
}
