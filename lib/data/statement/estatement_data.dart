/// Satu baris pada tabel rincian e-statement.
class EStatementRow {
  const EStatementRow({
    required this.date,
    required this.title,
    required this.source,
    required this.detail,
    required this.expense,
    required this.income,
    required this.balance,
  });

  /// Waktu lokal transaksi.
  final DateTime date;
  final String title;
  final String source;

  /// Keterangan kecil di bawah judul (kategori).
  final String detail;

  /// 0 jika baris ini pemasukan.
  final double expense;

  /// 0 jika baris ini pengeluaran.
  final double income;

  /// Saldo tercatat setelah transaksi ini.
  final double balance;

  bool get isIncome => income > 0;
}

/// Ringkasan per sumber dana (GoPay, SeaBank, DANA, dan seterusnya).
class EStatementSourceSummary {
  const EStatementSourceSummary({
    required this.label,
    required this.opening,
    required this.expense,
    required this.income,
    this.rows = const <EStatementRow>[],
  });

  final String label;
  final double opening;
  final double expense;
  final double income;

  /// Rincian milik sumber ini, dengan saldo berjalan sumber itu sendiri.
  final List<EStatementRow> rows;

  double get closing => opening + income - expense;
}

class EStatementData {
  const EStatementData({
    required this.ownerName,
    required this.periodStart,
    required this.periodEnd,
    required this.generatedAt,
    required this.serialNumber,
    required this.importsOnly,
    required this.rows,
    required this.sources,
  });

  final String ownerName;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime generatedAt;
  final String serialNumber;

  /// True bila hanya memuat transaksi hasil import.
  final bool importsOnly;
  final List<EStatementRow> rows;
  final List<EStatementSourceSummary> sources;

  double get openingTotal =>
      sources.fold(0, (double s, EStatementSourceSummary e) => s + e.opening);
  double get expenseTotal =>
      sources.fold(0, (double s, EStatementSourceSummary e) => s + e.expense);
  double get incomeTotal =>
      sources.fold(0, (double s, EStatementSourceSummary e) => s + e.income);
  double get closingTotal => openingTotal + incomeTotal - expenseTotal;

  bool get isEmpty => rows.isEmpty;
}
