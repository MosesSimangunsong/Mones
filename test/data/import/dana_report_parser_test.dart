import 'package:app/data/import/dana_report_parser.dart';
import 'package:app/data/import/imported_transaction_draft.dart';
import 'package:app/data/import/ocr_text_assembler.dart';
import 'package:flutter_test/flutter_test.dart';

// Teks disalin dari tangkapan layar contoh di docs/contoh_data.
const String _september = '''
Laporan DANA
1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30
September
1 Sep - 30 Sep 2026
Uang Masuk Uang Keluar
Rp2.780.000 Rp2.734.400
INCOME
Isi Saldo
Rp2.750.000
Terima Uang
Rp30.000
EXPENSE
Kirim Uang
Rp2.635.000
Belanja
Rp99.400
Powered by DANA
Satu aplikasi untuk semua pembayaran anda
www.dana.id
''';

const String _agustus = '''
Laporan DANA
Agustus
1 Agu - 31 Agu 2026
Uang Masuk
Rp200.000
Uang Keluar
Rp180.000
INCOME
Isi Saldo Rp200.000
EXPENSE
Kirim Uang
Rp170.000
Belanja
Rp10.000
Powered by DANA
''';

void main() {
  group('DanaReportParser', () {
    test('mengenali laporan DANA', () {
      expect(DanaReportParser.canParse(_september), isTrue);
      expect(DanaReportParser.canParse('Mutasi rekening'), isFalse);
    });

    test('membaca ringkasan September 2026 per kategori', () {
      final ImportedStatement result = const DanaReportParser().parse(
        _september,
      );

      expect(result.drafts, hasLength(4));
      expect(result.incomeTotal, 2780000);
      expect(result.expenseTotal, 2734400);
      expect(result.periodLabel, '1 Sep - 30 Sep 2026');

      final ImportedTransactionDraft topUp = result.drafts.first;
      expect(topUp.title, 'DANA - Isi Saldo');
      expect(topUp.type, 'income');
      expect(topUp.amount, 2750000);
      expect(topUp.transactionDate.year, 2026);
      expect(topUp.transactionDate.month, 9);
      expect(topUp.transactionDate.day, 30);
      expect(topUp.hint, isNotNull);

      final ImportedTransactionDraft shopping = result.drafts.last;
      expect(shopping.title, 'DANA - Belanja');
      expect(shopping.type, 'expense');
      expect(shopping.suggestedCategoryName, 'Belanja');
    });

    test('tidak ada peringatan total saat angka cocok dengan header', () {
      final ImportedStatement result = const DanaReportParser().parse(
        _september,
      );
      expect(result.warnings, hasLength(1));
      expect(result.warnings.single, contains('total per kategori'));
    });

    test('mendukung label dan nominal pada satu baris', () {
      final ImportedStatement result = const DanaReportParser().parse(
        _agustus,
      );

      expect(result.drafts, hasLength(3));
      expect(result.incomeTotal, 200000);
      expect(result.expenseTotal, 180000);
      expect(result.drafts.first.transactionDate.day, 31);
      expect(result.drafts.first.transactionDate.month, 8);
    });

    test('kunci eksternal stabil untuk import ulang', () {
      final List<String> first = const DanaReportParser()
          .parse(_september)
          .drafts
          .map((ImportedTransactionDraft d) => d.externalKey)
          .toList();
      final List<String> second = const DanaReportParser()
          .parse(_september)
          .drafts
          .map((ImportedTransactionDraft d) => d.externalKey)
          .toList();

      expect(first, second);
      expect(first.toSet(), hasLength(first.length));
    });

    test('memberi peringatan bila total tidak cocok', () {
      final String broken = _september.replaceFirst('Rp99.400', 'Rp90.400');
      final ImportedStatement result = const DanaReportParser().parse(broken);

      expect(
        result.warnings.any((String w) => w.contains('tidak sama')),
        isTrue,
      );
    });

    test('periode tidak terbaca menghasilkan peringatan, bukan crash', () {
      final ImportedStatement result = const DanaReportParser().parse(
        'Laporan DANA\nINCOME\nIsi Saldo\nRp1.000',
      );

      expect(result.drafts, isEmpty);
      expect(result.warnings, isNotEmpty);
    });
  });

  group('OcrTextAssembler', () {
    test('menyusun baris OCR berdasarkan posisi', () {
      final String text = OcrTextAssembler.assemble(const <OcrLine>[
        OcrLine(text: 'Rp2.750.000', left: 20, top: 140, height: 20),
        OcrLine(text: 'Rp2.734.400', left: 260, top: 40, height: 20),
        OcrLine(text: 'Isi Saldo', left: 20, top: 100, height: 20),
        OcrLine(text: 'Uang Masuk', left: 20, top: 2, height: 20),
        OcrLine(text: 'Rp2.780.000', left: 20, top: 40, height: 20),
        OcrLine(text: 'Uang Keluar', left: 260, top: 0, height: 20),
      ]);

      expect(text.split('\n'), <String>[
        'Uang Masuk Uang Keluar',
        'Rp2.780.000 Rp2.734.400',
        'Isi Saldo',
        'Rp2.750.000',
      ]);
    });
  });
}
