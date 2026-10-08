import 'imported_transaction_draft.dart';

/// Draft yang dipilih pengguna beserta kategori tujuannya.
class ImportSelection {
  const ImportSelection({required this.draft, required this.categoryUuid});

  final ImportedTransactionDraft draft;
  final String categoryUuid;
}

class ImportResult {
  const ImportResult({
    required this.imported,
    required this.duplicates,
    required this.failed,
  });

  final int imported;

  /// Sudah pernah diimport sebelumnya (termasuk yang sudah dihapus).
  final int duplicates;

  /// Gagal, misalnya kategori sudah tidak ada.
  final int failed;
}
