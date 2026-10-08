/// Satu transaksi hasil baca dokumen, belum disimpan ke database.
class ImportedTransactionDraft {
  const ImportedTransactionDraft({
    required this.externalKey,
    required this.sourceTag,
    required this.transactionDate,
    required this.title,
    required this.amount,
    required this.type,
    required this.paymentMethod,
    required this.suggestedCategoryName,
    this.note,
    this.hint,
  });

  /// Kunci unik dari dokumen asal. Dipakai agar import ulang tidak ganda.
  final String externalKey;

  /// Nilai `source` pada transaksi, misalnya `import_gopay`.
  final String sourceTag;

  /// Waktu lokal sesuai dokumen.
  final DateTime transactionDate;
  final String title;

  /// Selalu positif. Arah ditentukan oleh [type].
  final double amount;

  /// `income` atau `expense`.
  final String type;
  final String paymentMethod;
  final String suggestedCategoryName;
  final String? note;

  /// Catatan untuk pengguna di layar pratinjau.
  final String? hint;

  bool get isIncome => type == 'income';
}

/// Hasil pembacaan satu dokumen.
class ImportedStatement {
  const ImportedStatement({
    required this.providerLabel,
    required this.drafts,
    this.periodLabel,
    this.warnings = const <String>[],
    this.skippedCount = 0,
  });

  final String providerLabel;
  final String? periodLabel;
  final List<ImportedTransactionDraft> drafts;
  final List<String> warnings;

  /// Baris yang sengaja dilewati, misalnya poin Coins GoPay.
  final int skippedCount;

  double get incomeTotal => drafts
      .where((ImportedTransactionDraft d) => d.isIncome)
      .fold(0, (double sum, ImportedTransactionDraft d) => sum + d.amount);

  double get expenseTotal => drafts
      .where((ImportedTransactionDraft d) => !d.isIncome)
      .fold(0, (double sum, ImportedTransactionDraft d) => sum + d.amount);
}
