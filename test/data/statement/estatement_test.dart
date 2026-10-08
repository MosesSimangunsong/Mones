import 'dart:io';
import 'dart:typed_data';

import 'package:app/data/import/dana_report_parser.dart';
import 'package:app/data/import/gopay_statement_parser.dart';
import 'package:app/data/import/imported_transaction_draft.dart';
import 'package:app/data/import/positioned_word.dart';
import 'package:app/data/import/seabank_statement_parser.dart';
import 'package:app/data/models/money_transaction.dart';
import 'package:app/data/services/pdf_statement_text_reader.dart';
import 'package:app/data/statement/estatement_builder.dart';
import 'package:app/data/statement/estatement_data.dart';
import 'package:app/data/statement/estatement_pdf_generator.dart';
import 'package:flutter_test/flutter_test.dart';

MoneyTransaction _transaction(
  String uuid,
  DateTime localDate,
  double amount, {
  String type = 'expense',
  String method = 'GoPay',
  String source = 'import_gopay',
  String title = 'MRT Jakarta',
}) {
  return MoneyTransaction(
    uuid: uuid,
    type: type,
    title: title,
    amount: amount,
    categoryUuid: 'cat',
    categoryNameSnapshot: 'Transportasi',
    paymentMethod: method,
    source: source,
    transactionDate: localDate.toUtc(),
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

List<MoneyTransaction> _fromDrafts(Iterable<ImportedTransactionDraft> drafts) {
  int index = 0;
  return <MoneyTransaction>[
    for (final ImportedTransactionDraft d in drafts)
      MoneyTransaction(
        uuid: 'u${index++}',
        type: d.type,
        title: d.title,
        amount: d.amount,
        categoryUuid: 'cat',
        categoryNameSnapshot: d.suggestedCategoryName,
        paymentMethod: d.paymentMethod,
        source: d.sourceTag,
        transactionDate: d.transactionDate.toUtc(),
        createdAt: DateTime.utc(2026, 10, 8),
        updatedAt: DateTime.utc(2026, 10, 8),
      ),
  ];
}

List<List<PositionedWord>> _pages(String file) => const PdfStatementTextReader()
    .readPages(File('docs/contoh_data/$file').readAsBytesSync());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EStatementBuilder', () {
    final DateTime generatedAt = DateTime(2026, 10, 8, 12, 30);

    test('hanya memuat transaksi import pada bulan terpilih', () {
      final EStatementData data = EStatementBuilder.build(
        allActive: <MoneyTransaction>[
          _transaction('a', DateTime(2026, 9, 5, 8), 3000),
          _transaction('b', DateTime(2026, 8, 31, 8), 9000),
          _transaction('c', DateTime(2026, 10, 1, 0, 5), 7000),
          _transaction('m', DateTime(2026, 9, 6), 1000, source: 'manual'),
        ],
        month: DateTime(2026, 9),
        ownerName: 'Moses',
        generatedAt: generatedAt,
      );

      expect(data.rows, hasLength(1));
      expect(data.expenseTotal, 3000);
      // Transaksi import Agustus menjadi saldo awal.
      expect(data.openingTotal, -9000);
      expect(data.closingTotal, -12000);
    });

    test('opsi semua transaksi ikut menyertakan input manual', () {
      final EStatementData data = EStatementBuilder.build(
        allActive: <MoneyTransaction>[
          _transaction('a', DateTime(2026, 9, 5, 8), 3000),
          _transaction('m', DateTime(2026, 9, 6), 1000, source: 'manual'),
        ],
        month: DateTime(2026, 9),
        ownerName: 'Moses',
        generatedAt: generatedAt,
        importsOnly: false,
      );

      expect(data.rows, hasLength(2));
    });

    test('saldo berjalan mengikuti urutan waktu lintas sumber', () {
      final EStatementData data = EStatementBuilder.build(
        allActive: <MoneyTransaction>[
          _transaction(
            'x',
            DateTime(2026, 9, 3, 9),
            50000,
            type: 'income',
            method: 'SeaBank',
            source: 'import_seabank',
            title: 'Transfer dari A',
          ),
          _transaction('y', DateTime(2026, 9, 1, 8), 3000),
          _transaction('z', DateTime(2026, 9, 2, 8), 2000),
        ],
        month: DateTime(2026, 9),
        ownerName: 'Moses',
        generatedAt: generatedAt,
      );

      expect(
        data.rows.map((EStatementRow r) => r.balance).toList(),
        <double>[-3000, -5000, 45000],
      );
      expect(data.sources.map((EStatementSourceSummary s) => s.label), <String>[
        'GoPay',
        'SeaBank',
      ]);
      final EStatementSourceSummary seabank = data.sources.last;
      expect(seabank.income, 50000);
      expect(seabank.closing, 50000);
    });

    test('baris memuat sumber dan rincian per sumber punya saldo sendiri', () {
      final EStatementData data = EStatementBuilder.build(
        allActive: <MoneyTransaction>[
          _transaction(
            'o',
            DateTime(2026, 8, 30, 9),
            1000,
            type: 'income',
            method: 'SeaBank',
            source: 'import_seabank',
          ),
          _transaction('a', DateTime(2026, 9, 1, 8), 3000),
          _transaction(
            'b',
            DateTime(2026, 9, 2, 9),
            200,
            method: 'SeaBank',
            source: 'import_seabank',
          ),
          _transaction('c', DateTime(2026, 9, 3, 9), 500, type: 'income'),
        ],
        month: DateTime(2026, 9),
        ownerName: 'Moses',
        generatedAt: generatedAt,
      );

      expect(
        data.rows.map((EStatementRow r) => r.source).toList(),
        <String>['GoPay', 'SeaBank', 'GoPay'],
      );
      expect(data.rows.first.detail, 'Transportasi');

      final EStatementSourceSummary gopay = data.sources.firstWhere(
        (EStatementSourceSummary s) => s.label == 'GoPay',
      );
      final EStatementSourceSummary seabank = data.sources.firstWhere(
        (EStatementSourceSummary s) => s.label == 'SeaBank',
      );
      expect(
        gopay.rows.map((EStatementRow r) => r.balance).toList(),
        <double>[-3000, -2500],
      );
      expect(
        seabank.rows.map((EStatementRow r) => r.balance).toList(),
        <double>[800],
      );
    });

    test('total ringkasan sama dengan saldo baris terakhir', () {
      final EStatementData data = EStatementBuilder.build(
        allActive: <MoneyTransaction>[
          _transaction('a', DateTime(2026, 8, 20), 1000, type: 'income'),
          _transaction('b', DateTime(2026, 9, 1), 300),
          _transaction('c', DateTime(2026, 9, 2), 200, method: 'DANA'),
        ],
        month: DateTime(2026, 9),
        ownerName: '',
        generatedAt: generatedAt,
      );

      expect(data.rows.last.balance, data.closingTotal);
      expect(data.closingTotal, 500);
      expect(data.ownerName, 'Pengguna Mones');
    });

    test('nomor seri stabil untuk input yang sama', () {
      final EStatementData one = EStatementBuilder.build(
        allActive: const <MoneyTransaction>[],
        month: DateTime(2026, 9),
        ownerName: 'A',
        generatedAt: generatedAt,
      );
      final EStatementData two = EStatementBuilder.build(
        allActive: const <MoneyTransaction>[],
        month: DateTime(2026, 9),
        ownerName: 'A',
        generatedAt: generatedAt,
      );

      expect(one.serialNumber, two.serialNumber);
      expect(one.serialNumber, startsWith('MP-2609-'));
      expect(one.isEmpty, isTrue);
    });
  });

  group('EStatementPdfGenerator', () {
    test('membuat PDF gabungan dari hasil import GoPay, SeaBank, dan DANA', () async {
      final List<ImportedTransactionDraft> drafts = <ImportedTransactionDraft>[
        ...const SeaBankStatementParser()
            .parse(_pages('Seabank_Statement_20261008.pdf'))
            .drafts,
        ...const GoPayStatementParser()
            .parse(_pages('GoPay Transaction History.pdf'))
            .drafts,
        ...const DanaReportParser()
            .parse(
              'Laporan DANA\n1 Sep - 30 Sep 2026\nINCOME\nIsi Saldo\n'
              'Rp2.750.000\nEXPENSE\nKirim Uang\nRp2.635.000\nBelanja\nRp99.400',
            )
            .drafts,
      ];

      final EStatementData data = EStatementBuilder.build(
        allActive: _fromDrafts(drafts),
        month: DateTime(2026, 9),
        ownerName: 'Moses Romulus Simangunsong',
        generatedAt: DateTime(2026, 10, 8, 12, 30),
      );

      expect(data.sources.map((EStatementSourceSummary s) => s.label), <String>[
        'DANA',
        'GoPay',
        'SeaBank',
      ]);
      expect(data.rows.last.balance, closeTo(data.closingTotal, 0.01));

      final Uint8List bytes = await const EStatementPdfGenerator().generate(
        data,
        await EStatementAssets.load(),
      );

      final String? outputDir = Platform.environment['ESTATEMENT_OUT'];
      if (outputDir != null) {
        File('$outputDir/estatement_sample.pdf').writeAsBytesSync(bytes);
      }

      // PDF valid dan bisa dibaca kembali.
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      final List<List<PositionedWord>> pages = const PdfStatementTextReader()
          .readPages(bytes);
      expect(pages.length, greaterThan(2));

      final String firstPage = WordRows.pageText(pages.first);
      expect(firstPage, contains('LAPORAN KEUANGAN'));
      expect(firstPage, contains('RINGKASAN LAPORAN'));
      expect(firstPage, contains('RINCIAN TRANSAKSI'));
      expect(firstPage, contains('SEABANK'));
      expect(firstPage, contains('GOPAY'));
      expect(firstPage, contains('DANA'));
      expect(firstPage, contains('TANGGAL TRANSAKSI SUMBER KELUAR'));
      expect(firstPage, contains('halaman 1 dr ${pages.length}'));

      final String allText = pages.map(WordRows.pageText).join('\n');
      expect(allText, contains('Mones'));
      expect(allText, isNot(contains('MoneyPilot')));
      expect(allText, contains('DANA - RINCIAN TRANSAKSI'));
      expect(allText, contains('GOPAY - RINCIAN TRANSAKSI'));
      expect(allText, contains('SEABANK - RINCIAN TRANSAKSI'));
      expect(WordRows.pageText(pages.last), contains('Ketentuan Umum'));
    });

    test('periode tanpa transaksi tetap menghasilkan PDF', () async {
      final EStatementData data = EStatementBuilder.build(
        allActive: const <MoneyTransaction>[],
        month: DateTime(2026, 9),
        ownerName: 'Moses',
        generatedAt: DateTime(2026, 10, 8),
      );

      final Uint8List bytes = await const EStatementPdfGenerator().generate(
        data,
        await EStatementAssets.load(),
      );

      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      final String text = WordRows.pageText(
        const PdfStatementTextReader().readPages(bytes).first,
      );
      expect(text, contains('Tidak ada transaksi pada periode ini.'));
    });
  });
}
