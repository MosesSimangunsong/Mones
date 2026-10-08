import 'imported_transaction_draft.dart';
import 'import_category_suggester.dart';
import 'positioned_word.dart';
import 'statement_parsing_utils.dart';

/// Parser "Rekening Koran" SeaBank (PDF).
///
/// Kolom tabel: TANGGAL | TRANSAKSI | KELUAR (IDR) | MASUK (IDR) | SALDO AKHIR.
/// Keterangan transaksi berada di kolom TRANSAKSI dan bisa memakai beberapa
/// baris di atas dan di bawah baris tanggal. Arah uang ditentukan dari kolom
/// tempat nominal berada (rata kanan pada header kolom).
class SeaBankStatementParser {
  const SeaBankStatementParser();

  static const String sourceTag = 'import_seabank';

  static final RegExp _numberWord = RegExp(r'^\d{1,3}(?:\.\d{3})*$');
  static final RegExp _dayWord = RegExp(r'^\d{1,2}$');
  static final RegExp _footerRow = RegExp(
    r'^halaman \d+ dr \d+$',
    caseSensitive: false,
  );
  static final RegExp _kindRow = RegExp(
    r'^(Pembayaran|Transfer|Bunga|Biaya|Top ?up|Penarikan|Pajak|Pembelian|'
    r'Setoran|Refund|Cashback|Pemindahan)\b',
    caseSensitive: false,
  );
  static final RegExp _accountRow = RegExp(r'\d{8,}');

  static bool canParse(List<List<PositionedWord>> pages) {
    if (pages.isEmpty) {
      return false;
    }
    final String text = WordRows.pageText(pages.first).toLowerCase();
    return text.contains('rekening koran') && text.contains('seabank');
  }

  ImportedStatement parse(List<List<PositionedWord>> pages) {
    final String firstPageText = pages.isEmpty
        ? ''
        : WordRows.pageText(pages.first);
    final _Period? period = _readPeriod(firstPageText);
    final String account =
        RegExp(r'NO\. REKENING SEABANK:\s*(\d+)').firstMatch(firstPageText)?.group(1) ??
        'seabank';
    final _Summary? summary = _readSummary(firstPageText);

    final List<ImportedTransactionDraft> drafts = <ImportedTransactionDraft>[];
    final List<String> warnings = <String>[];
    final Set<String> seenKeys = <String>{};
    int balanceMismatches = 0;
    double? previousBalance = summary?.openingBalance;

    if (period == null) {
      warnings.add(
        'Periode rekening tidak terbaca, tahun transaksi diasumsikan tahun ini.',
      );
    }

    int sequence = 0;
    for (final List<PositionedWord> page in pages) {
      final _Columns? columns = _findColumns(page);
      if (columns == null) {
        continue;
      }

      final List<PositionedWord> body = page
          .where((PositionedWord w) => w.top > columns.headerTop + 4)
          .toList();
      final List<_Anchor> anchors = _findAnchors(body, columns);
      if (anchors.isEmpty) {
        continue;
      }

      final List<List<PositionedWord>> descriptions =
          List<List<PositionedWord>>.generate(
            anchors.length,
            (_) => <PositionedWord>[],
          );

      for (final PositionedWord word in body) {
        final bool inDescriptionColumn =
            word.left >= columns.descX - 3 &&
            word.right <= columns.keluarRight + 2;
        // Nominal kolom KELUAR berada di rentang yang sama dengan keterangan.
        final bool isKeluarAmount =
            _numberWord.hasMatch(word.text) &&
            (word.right - columns.keluarRight).abs() < 6;
        if (!inDescriptionColumn || isKeluarAmount) {
          continue;
        }
        final int owner = _ownerOf(word.top, anchors);
        if (owner != -1) {
          descriptions[owner].add(word);
        }
      }

      for (int index = 0; index < anchors.length; index++) {
        final _Anchor anchor = anchors[index];
        final List<PositionedWord> sameRow = body
            .where((PositionedWord w) => (w.top - anchor.top).abs() < 2.5)
            .toList();

        double? keluar;
        double? masuk;
        double? saldo;
        for (final PositionedWord w in sameRow) {
          if (!_numberWord.hasMatch(w.text)) {
            continue;
          }
          final double? value = StatementParsingUtils.parseRupiah(w.text);
          if (value == null) {
            continue;
          }
          if ((w.right - columns.keluarRight).abs() < 6) {
            keluar = value;
          } else if ((w.right - columns.masukRight).abs() < 6) {
            masuk = value;
          } else if ((w.right - columns.saldoRight).abs() < 6) {
            saldo = value;
          }
        }
        if (keluar == null && masuk == null) {
          warnings.add('Satu transaksi tanggal ${anchor.label} tidak terbaca.');
          continue;
        }

        final bool isIncome = masuk != null;
        final double amount = (isIncome ? masuk : keluar)!;

        if (saldo != null && previousBalance != null) {
          final double expected = isIncome
              ? previousBalance + amount
              : previousBalance - amount;
          if ((expected - saldo).abs() > 0.5) {
            balanceMismatches++;
          }
        }
        if (saldo != null) {
          previousBalance = saldo;
        }

        final _Description description = _describe(
          descriptions[index],
          isIncome: isIncome,
        );
        final DateTime date = StatementParsingUtils.dateOnly(
          _yearFor(anchor.month, period),
          anchor.month,
          anchor.day,
          sequence: sequence++,
        );

        final String type = isIncome ? 'income' : 'expense';
        String key =
            'seabank:$account:${date.year}-${anchor.month}-${anchor.day}:'
            '${saldo?.round() ?? 'x'}:${amount.round()}:$type';
        int duplicate = 1;
        while (!seenKeys.add(key)) {
          duplicate++;
          key = '$key#$duplicate';
        }

        drafts.add(
          ImportedTransactionDraft(
            externalKey: key,
            sourceTag: sourceTag,
            transactionDate: date,
            title: description.title,
            amount: amount,
            type: type,
            paymentMethod: 'SeaBank',
            suggestedCategoryName: ImportCategorySuggester.suggest(
              title: '${description.title} ${description.kind ?? ''}',
              type: type,
            ),
            note: description.note,
          ),
        );
      }
    }

    if (balanceMismatches > 0) {
      warnings.add(
        '$balanceMismatches transaksi tidak cocok dengan saldo berjalan. '
        'Periksa hasilnya sebelum disimpan.',
      );
    }

    if (summary != null) {
      final ImportedStatement result = ImportedStatement(
        providerLabel: 'SeaBank',
        drafts: drafts,
      );
      if ((result.expenseTotal - summary.expenseTotal).abs() > 0.5) {
        warnings.add(
          'Total transaksi keluar hasil baca tidak sama dengan ringkasan rekening.',
        );
      }
      if ((result.incomeTotal - summary.incomeTotal).abs() > 0.5) {
        warnings.add(
          'Total transaksi masuk hasil baca tidak sama dengan ringkasan rekening.',
        );
      }
    }

    return ImportedStatement(
      providerLabel: 'SeaBank',
      periodLabel: period?.label,
      drafts: drafts,
      warnings: warnings,
    );
  }

  int _yearFor(int month, _Period? period) {
    if (period == null) {
      return DateTime.now().year;
    }
    return month >= period.startMonth ? period.startYear : period.endYear;
  }

  _Columns? _findColumns(List<PositionedWord> page) {
    for (final PositionedWord tanggal in page.where(
      (PositionedWord w) => w.text == 'TANGGAL',
    )) {
      final List<PositionedWord> header = page
          .where((PositionedWord w) => (w.top - tanggal.top).abs() < 3)
          .toList()
        ..sort((PositionedWord a, PositionedWord b) => a.left.compareTo(b.left));
      PositionedWord? transaksi;
      for (final PositionedWord w in header) {
        if (w.text == 'TRANSAKSI') {
          transaksi = w;
        }
      }
      final List<PositionedWord> idr = header
          .where((PositionedWord w) => w.text == '(IDR)')
          .toList();
      if (transaksi != null && idr.length >= 3) {
        return _Columns(
          headerTop: tanggal.top,
          dateX: tanggal.left,
          descX: transaksi.left,
          keluarRight: idr[0].right,
          masukRight: idr[1].right,
          saldoRight: idr[2].right,
        );
      }
    }
    return null;
  }

  List<_Anchor> _findAnchors(List<PositionedWord> body, _Columns columns) {
    final List<_Anchor> anchors = <_Anchor>[];
    for (final PositionedWord word in body) {
      if ((word.left - columns.dateX).abs() > 4 || !_dayWord.hasMatch(word.text)) {
        continue;
      }
      PositionedWord? monthWord;
      for (final PositionedWord other in body) {
        if ((other.top - word.top).abs() < 2 &&
            other.left > word.right &&
            other.left < word.right + 20 &&
            StatementParsingUtils.monthNumber(other.text) != null) {
          monthWord = other;
          break;
        }
      }
      if (monthWord == null) {
        continue;
      }
      anchors.add(
        _Anchor(
          top: word.top,
          day: int.parse(word.text),
          month: StatementParsingUtils.monthNumber(monthWord.text)!,
          label: '${word.text} ${monthWord.text}',
        ),
      );
    }
    anchors.sort((_Anchor a, _Anchor b) => a.top.compareTo(b.top));
    return anchors;
  }

  /// Baris keterangan dimiliki anchor terdekat; batasnya titik tengah di
  /// antara dua baris tanggal.
  int _ownerOf(double top, List<_Anchor> anchors) {
    for (int index = 0; index < anchors.length; index++) {
      final double upper = index + 1 < anchors.length
          ? (anchors[index].top + anchors[index + 1].top) / 2
          : anchors[index].top + 34;
      if (top < upper) {
        return index;
      }
    }
    return -1;
  }

  _Description _describe(List<PositionedWord> words, {required bool isIncome}) {
    final List<String> rows = WordRows.group(words)
        .map(WordRows.rowText)
        .where((String row) => row.isNotEmpty && !_footerRow.hasMatch(row))
        .toList();

    String? kind;
    if (rows.isNotEmpty && _kindRow.hasMatch(rows.last)) {
      kind = rows.removeLast();
    }

    final List<String> titleRows = <String>[];
    final List<String> details = <String>[];
    for (final String row in rows) {
      if (_accountRow.hasMatch(row)) {
        details.add(row);
      } else {
        titleRows.add(row);
      }
    }

    String title = titleRows.join(' ').trim();
    if (kind != null && kind.toLowerCase() == 'transfer' && title.isNotEmpty) {
      title = '${isIncome ? 'Transfer dari' : 'Transfer ke'} $title';
    }
    if (title.isEmpty) {
      title = kind ?? 'Transaksi SeaBank';
    }

    return _Description(
      title: title,
      kind: kind,
      note: <String>['Import SeaBank', ?kind, ...details].join(' - '),
    );
  }

  _Period? _readPeriod(String text) {
    final RegExpMatch? match = RegExp(
      r'(\d{1,2}) ([A-Za-z]{3,9}) (\d{4}) sampai (\d{1,2}) ([A-Za-z]{3,9}) (\d{4})',
    ).firstMatch(text);
    if (match == null) {
      return null;
    }
    final int? startMonth = StatementParsingUtils.monthNumber(match.group(2)!);
    final int? endMonth = StatementParsingUtils.monthNumber(match.group(5)!);
    if (startMonth == null || endMonth == null) {
      return null;
    }
    return _Period(
      startMonth: startMonth,
      startYear: int.parse(match.group(3)!),
      endYear: int.parse(match.group(6)!),
      label:
          '${match.group(1)} ${match.group(2)} ${match.group(3)} - '
          '${match.group(4)} ${match.group(5)} ${match.group(6)}',
    );
  }

  _Summary? _readSummary(String text) {
    final RegExpMatch? match = RegExp(
      r'TABUNGAN ([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+)',
    ).firstMatch(text);
    if (match == null) {
      return null;
    }
    double value(int group) =>
        StatementParsingUtils.parseRupiah(match.group(group)!) ?? 0;
    return _Summary(
      openingBalance: value(1),
      expenseTotal: value(2),
      incomeTotal: value(3),
    );
  }
}

class _Columns {
  const _Columns({
    required this.headerTop,
    required this.dateX,
    required this.descX,
    required this.keluarRight,
    required this.masukRight,
    required this.saldoRight,
  });

  final double headerTop;
  final double dateX;
  final double descX;
  final double keluarRight;
  final double masukRight;
  final double saldoRight;
}

class _Anchor {
  const _Anchor({
    required this.top,
    required this.day,
    required this.month,
    required this.label,
  });

  final double top;
  final int day;
  final int month;
  final String label;
}

class _Description {
  const _Description({required this.title, this.kind, this.note});

  final String title;
  final String? kind;
  final String? note;
}

class _Period {
  const _Period({
    required this.startMonth,
    required this.startYear,
    required this.endYear,
    required this.label,
  });

  final int startMonth;
  final int startYear;
  final int endYear;
  final String label;
}

class _Summary {
  const _Summary({
    required this.openingBalance,
    required this.expenseTotal,
    required this.incomeTotal,
  });

  final double openingBalance;
  final double expenseTotal;
  final double incomeTotal;
}
