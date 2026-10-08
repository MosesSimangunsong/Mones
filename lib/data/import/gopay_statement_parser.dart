import 'imported_transaction_draft.dart';
import 'import_category_suggester.dart';
import 'positioned_word.dart';
import 'statement_parsing_utils.dart';

/// Parser e-statement "GoPay Transaction History" (PDF).
///
/// Tabel terdiri dari kolom Tanggal | Transaksi | ID transaksi | Metode
/// pembayaran | Jumlah. Satu transaksi menempati dua baris visual (tanggal di
/// atas jam, ID terpotong ke baris kedua), sehingga baris dikelompokkan dari
/// posisi kolom, bukan dari urutan teks.
class GoPayStatementParser {
  const GoPayStatementParser();

  static const String sourceTag = 'import_gopay';

  static final RegExp _dateWord = RegExp(r'^\d{2}/\d{2}/\d{4}$');
  static final RegExp _timeWord = RegExp(r'^\d{2}:\d{2}$');

  static bool canParse(List<List<PositionedWord>> pages) {
    if (pages.isEmpty) {
      return false;
    }
    final String text = WordRows.pageText(pages.first).toLowerCase();
    return text.contains('e-statement') &&
        text.contains('metode pembayaran') &&
        text.contains('total pengeluaran');
  }

  ImportedStatement parse(List<List<PositionedWord>> pages) {
    final List<ImportedTransactionDraft> drafts = <ImportedTransactionDraft>[];
    final List<String> warnings = <String>[];
    final Set<String> seenKeys = <String>{};
    int skipped = 0;

    for (final List<PositionedWord> page in pages) {
      final _Columns? columns = _findColumns(page);
      if (columns == null) {
        continue;
      }

      final List<PositionedWord> body = page
          .where((PositionedWord w) => w.top > columns.headerTop + 4)
          .toList();
      final List<PositionedWord> anchors =
          body
              .where(
                (PositionedWord w) =>
                    w.left < columns.titleX - 5 && _dateWord.hasMatch(w.text),
              )
              .toList()
            ..sort((PositionedWord a, PositionedWord b) => a.top.compareTo(b.top));

      for (int index = 0; index < anchors.length; index++) {
        final PositionedWord anchor = anchors[index];
        final double start = anchor.top - 2;
        final double end = index + 1 < anchors.length
            ? anchors[index + 1].top - 2
            : double.infinity;
        final List<PositionedWord> row = body
            .where((PositionedWord w) => w.top >= start && w.top < end)
            .toList();

        final _GoPayRow? parsed = _parseRow(anchor, row, columns);
        if (parsed == null) {
          warnings.add('Satu baris pada ${anchor.text} tidak bisa dibaca.');
          continue;
        }
        if (parsed.isCoins) {
          skipped++;
          continue;
        }

        String key = 'gopay:${parsed.externalId}';
        int duplicate = 1;
        while (!seenKeys.add(key)) {
          duplicate++;
          key = 'gopay:${parsed.externalId}#$duplicate';
        }

        final String type = parsed.amount < 0 ? 'expense' : 'income';
        drafts.add(
          ImportedTransactionDraft(
            externalKey: key,
            sourceTag: sourceTag,
            transactionDate: parsed.date,
            title: parsed.title,
            amount: parsed.amount.abs(),
            type: type,
            paymentMethod: 'GoPay',
            suggestedCategoryName: ImportCategorySuggester.suggest(
              title: parsed.title,
              type: type,
            ),
            note: 'Import GoPay ${parsed.externalId}',
            hint: _isTopUp(parsed.title)
                ? 'Top up saldo: kemungkinan perpindahan dana dari rekening '
                      'sendiri. Cek agar tidak tercatat dobel.'
                : null,
          ),
        );
      }
    }

    final _Totals? totals = _readTotals(pages.isEmpty ? const [] : pages.first);
    if (totals != null) {
      final ImportedStatement draftResult = ImportedStatement(
        providerLabel: 'GoPay',
        drafts: drafts,
      );
      if ((draftResult.incomeTotal - totals.income).abs() > 0.5) {
        warnings.add(
          'Total pemasukan hasil baca tidak sama dengan total di dokumen.',
        );
      }
      if ((draftResult.expenseTotal - totals.expense).abs() > 0.5) {
        warnings.add(
          'Total pengeluaran hasil baca tidak sama dengan total di dokumen.',
        );
      }
    }

    return ImportedStatement(
      providerLabel: 'GoPay',
      periodLabel: _readPeriod(pages.isEmpty ? const [] : pages.first),
      drafts: drafts,
      warnings: warnings,
      skippedCount: skipped,
    );
  }

  bool _isTopUp(String title) => title.toLowerCase().contains('top up');

  _Columns? _findColumns(List<PositionedWord> page) {
    for (final PositionedWord tanggal in page.where(
      (PositionedWord w) => w.text == 'Tanggal',
    )) {
      final List<PositionedWord> header = page
          .where((PositionedWord w) => (w.top - tanggal.top).abs() < 2)
          .toList();
      PositionedWord? find(String text) {
        for (final PositionedWord w in header) {
          if (w.text == text) {
            return w;
          }
        }
        return null;
      }

      final PositionedWord? transaksi = find('Transaksi');
      final PositionedWord? id = find('ID');
      final PositionedWord? metode = find('Metode');
      final PositionedWord? jumlah = find('Jumlah');
      if (transaksi != null && id != null && metode != null && jumlah != null) {
        return _Columns(
          headerTop: tanggal.top,
          titleX: transaksi.left,
          idX: id.left,
          methodX: metode.left,
          amountX: jumlah.left,
        );
      }
    }
    return null;
  }

  _GoPayRow? _parseRow(
    PositionedWord anchor,
    List<PositionedWord> row,
    _Columns columns,
  ) {
    final List<String> dateParts = anchor.text.split('/');
    final int? day = int.tryParse(dateParts[0]);
    final int? month = int.tryParse(dateParts[1]);
    final int? year = int.tryParse(dateParts[2]);
    if (day == null || month == null || year == null) {
      return null;
    }

    int hour = 12;
    int minute = 0;
    for (final PositionedWord w in row) {
      if (w.left < columns.titleX - 5 && _timeWord.hasMatch(w.text)) {
        hour = int.parse(w.text.substring(0, 2));
        minute = int.parse(w.text.substring(3, 5));
        break;
      }
    }

    int byPosition(PositionedWord a, PositionedWord b) {
      final int vertical = a.top.compareTo(b.top);
      return (a.top - b.top).abs() < 2 ? a.left.compareTo(b.left) : vertical;
    }

    final List<PositionedWord> titleWords =
        row
            .where(
              (PositionedWord w) =>
                  w.left >= columns.titleX - 2 && w.left < columns.idX - 1,
            )
            .toList()
          ..sort(byPosition);
    final List<PositionedWord> idWords =
        row
            .where(
              (PositionedWord w) =>
                  w.left >= columns.idX - 1 && w.left < columns.methodX - 1,
            )
            .toList()
          ..sort(byPosition);
    final List<PositionedWord> rest = row
        .where((PositionedWord w) => w.left >= columns.methodX - 1)
        .toList();
    final List<PositionedWord> methodWords =
        rest.where((PositionedWord w) => w.right <= columns.amountX - 5).toList()
          ..sort(byPosition);
    final List<PositionedWord> amountWords =
        rest.where((PositionedWord w) => w.right > columns.amountX - 5).toList()
          ..sort(byPosition);

    final String title = titleWords.map((PositionedWord w) => w.text).join(' ');
    final String externalId = idWords.map((PositionedWord w) => w.text).join();
    final String method = methodWords
        .map((PositionedWord w) => w.text)
        .join(' ');
    final bool isCoins = method.toLowerCase().contains('coins');
    final double? amount = StatementParsingUtils.parseRupiah(
      amountWords.map((PositionedWord w) => w.text).join(),
    );
    if (!isCoins && (amount == null || externalId.isEmpty)) {
      return null;
    }

    return _GoPayRow(
      date: DateTime(year, month, day, hour, minute),
      title: title.isEmpty ? 'Transaksi GoPay' : title,
      externalId: externalId,
      amount: amount ?? 0,
      isCoins: isCoins,
    );
  }

  _Totals? _readTotals(List<PositionedWord> firstPage) {
    final _Columns? columns = _findColumns(firstPage);
    final double limit = columns?.headerTop ?? double.infinity;
    final List<PositionedWord> rupiah =
        firstPage
            .where(
              (PositionedWord w) =>
                  w.top < limit && RegExp(r'^Rp[\d.]+$').hasMatch(w.text),
            )
            .toList()
          ..sort((PositionedWord a, PositionedWord b) => a.left.compareTo(b.left));
    if (rupiah.length < 2) {
      return null;
    }
    final double? income = StatementParsingUtils.parseRupiah(rupiah[0].text);
    final double? expense = StatementParsingUtils.parseRupiah(rupiah[1].text);
    if (income == null || expense == null) {
      return null;
    }
    return _Totals(income: income, expense: expense);
  }

  String? _readPeriod(List<PositionedWord> firstPage) {
    final RegExpMatch? match = RegExp(
      r'Periode transaksi\s*:\s*(\d{1,2} \w+ \d{4}) - (\d{1,2} \w+ \d{4})',
    ).firstMatch(WordRows.pageText(firstPage));
    if (match == null) {
      return null;
    }
    return '${match.group(1)} - ${match.group(2)}';
  }
}

class _Columns {
  const _Columns({
    required this.headerTop,
    required this.titleX,
    required this.idX,
    required this.methodX,
    required this.amountX,
  });

  final double headerTop;
  final double titleX;
  final double idX;
  final double methodX;
  final double amountX;
}

class _GoPayRow {
  const _GoPayRow({
    required this.date,
    required this.title,
    required this.externalId,
    required this.amount,
    required this.isCoins,
  });

  final DateTime date;
  final String title;
  final String externalId;
  final double amount;
  final bool isCoins;
}

class _Totals {
  const _Totals({required this.income, required this.expense});

  final double income;
  final double expense;
}
