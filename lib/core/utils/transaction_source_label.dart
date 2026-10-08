/// Label ramah pengguna untuk nilai `MoneyTransaction.source`.
class TransactionSourceLabel {
  const TransactionSourceLabel._();

  static String of(String source) {
    switch (source) {
      case 'manual':
        return 'Input manual';
      case 'voice':
        return 'Input suara';
      case 'import_gopay':
        return 'Import GoPay';
      case 'import_seabank':
        return 'Import SeaBank';
      case 'import_dana':
        return 'Import DANA';
      case 'portfolio_dividend':
        return 'Dividen portofolio';
      default:
        return source;
    }
  }

  /// Import dari mutasi bank/laporan hanya memuat tanggal, tanpa jam.
  static bool hasTimeOfDay(String source) {
    return source != 'import_seabank' && source != 'import_dana';
  }
}
