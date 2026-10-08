import 'imported_transaction_draft.dart';
import 'import_category_suggester.dart';
import 'statement_parsing_utils.dart';

/// Parser tangkapan layar "Laporan DANA" (hasil OCR).
///
/// Laporan DANA hanya memuat total per kategori untuk satu bulan, bukan
/// transaksi satuan. Tiap kategori diimpor sebagai satu transaksi bertanggal
/// akhir periode, dan keterangannya menyebut hal itu.
class DanaReportParser {
  const DanaReportParser();

  static const String sourceTag = 'import_dana';

  static final RegExp _amountPattern = RegExp(r'Rp\s?([0-9][0-9.,]*)');
  static final RegExp _periodPattern = RegExp(
    r'(\d{1,2})\s*([A-Za-z]{3,9})\s*-\s*(\d{1,2})\s*([A-Za-z]{3,9})\s*(\d{4})',
  );

  static bool canParse(String text) {
    final String lower = text.toLowerCase();
    return lower.contains('laporan dana') ||
        (lower.contains('powered by') &&
            lower.contains('dana') &&
            lower.contains('uang masuk'));
  }

  ImportedStatement parse(String text) {
    final List<String> lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();

    final RegExpMatch? period = _periodPattern.firstMatch(text);
    final int? endMonth = period == null
        ? null
        : StatementParsingUtils.monthNumber(period.group(4)!);
    final int? year = period == null ? null : int.tryParse(period.group(5)!);

    if (period == null || endMonth == null || year == null) {
      return const ImportedStatement(
        providerLabel: 'DANA',
        drafts: <ImportedTransactionDraft>[],
        warnings: <String>[
          'Periode laporan tidak terbaca. Pastikan tangkapan layar utuh '
              '(judul bulan dan rentang tanggal terlihat).',
        ],
      );
    }

    final int endDay = int.parse(period.group(3)!);
    final String periodLabel =
        '${period.group(1)} ${period.group(2)} - $endDay ${period.group(4)} $year';

    final List<double> headlineTotals = <double>[];
    final List<ImportedTransactionDraft> drafts = <ImportedTransactionDraft>[];
    String? section;
    String? pendingLabel;
    int sequence = 0;

    for (final String line in lines) {
      final String lower = line.toLowerCase();
      if (lower == 'income' || lower == 'pemasukan') {
        section = 'income';
        pendingLabel = null;
        continue;
      }
      if (lower == 'expense' || lower == 'pengeluaran') {
        section = 'expense';
        pendingLabel = null;
        continue;
      }
      if (lower.startsWith('powered by')) {
        break;
      }

      final RegExpMatch? amountMatch = _amountPattern.firstMatch(line);
      final double? amount = amountMatch == null
          ? null
          : StatementParsingUtils.parseRupiah('Rp${amountMatch.group(1)}');

      if (section == null) {
        // Dua kartu (Uang Masuk, Uang Keluar) bisa terbaca dalam satu baris.
        for (final RegExpMatch match in _amountPattern.allMatches(line)) {
          final double? value = StatementParsingUtils.parseRupiah(
            'Rp${match.group(1)}',
          );
          if (value != null) {
            headlineTotals.add(value);
          }
        }
        continue;
      }

      if (amount == null) {
        pendingLabel = line;
        continue;
      }

      final String inlineLabel = line
          .substring(0, amountMatch!.start)
          .trim();
      final String label = inlineLabel.isNotEmpty ? inlineLabel : pendingLabel ?? '';
      pendingLabel = null;
      if (label.isEmpty || amount <= 0) {
        continue;
      }

      final String type = section;
      drafts.add(
        ImportedTransactionDraft(
          externalKey:
              'dana:$year-$endMonth:$type:${label.toLowerCase().replaceAll(RegExp(r'\s+'), ' ')}',
          sourceTag: sourceTag,
          transactionDate: StatementParsingUtils.dateOnly(
            year,
            endMonth,
            endDay,
            sequence: sequence++,
          ),
          title: 'DANA - $label',
          amount: amount,
          type: type,
          paymentMethod: 'DANA',
          suggestedCategoryName: ImportCategorySuggester.suggest(
            title: label,
            type: type,
          ),
          note:
              'Ringkasan laporan DANA $periodLabel. Ini total per kategori, '
              'bukan transaksi satuan.',
          hint: _isInternalMove(label)
              ? 'Kemungkinan perpindahan dana dari rekening sendiri. Cek agar '
                    'tidak tercatat dobel dengan mutasi bank.'
              : null,
        ),
      );
    }

    final List<String> warnings = <String>[
      'Laporan DANA hanya berisi total per kategori, bukan transaksi satuan.',
    ];

    if (drafts.isEmpty) {
      warnings.add('Tidak ada baris income/expense yang terbaca.');
    } else if (headlineTotals.length >= 2) {
      final ImportedStatement probe = ImportedStatement(
        providerLabel: 'DANA',
        drafts: drafts,
      );
      final Set<double> expected = <double>{
        headlineTotals[0],
        headlineTotals[1],
      };
      final Set<double> actual = <double>{probe.incomeTotal, probe.expenseTotal};
      if (expected.difference(actual).isNotEmpty) {
        warnings.add(
          'Total hasil baca tidak sama dengan Uang Masuk/Uang Keluar pada '
          'laporan. Periksa angka sebelum disimpan.',
        );
      }
    }

    return ImportedStatement(
      providerLabel: 'DANA',
      periodLabel: periodLabel,
      drafts: drafts,
      warnings: warnings,
    );
  }

  bool _isInternalMove(String label) {
    final String lower = label.toLowerCase();
    return lower.contains('isi saldo') || lower.contains('top up');
  }
}
