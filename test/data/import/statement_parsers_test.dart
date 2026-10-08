import 'dart:io';

import 'package:app/data/import/gopay_statement_parser.dart';
import 'package:app/data/import/imported_transaction_draft.dart';
import 'package:app/data/import/positioned_word.dart';
import 'package:app/data/import/seabank_statement_parser.dart';
import 'package:app/data/services/pdf_statement_text_reader.dart';
import 'package:flutter_test/flutter_test.dart';

List<List<PositionedWord>> _readSample(String fileName) {
  final File file = File('docs/contoh_data/$fileName');
  return const PdfStatementTextReader().readPages(file.readAsBytesSync());
}

void main() {
  group('GoPayStatementParser', () {
    test('mengenali dan membaca e-statement September 2026', () {
      final pages = _readSample('GoPay Transaction History.pdf');
      expect(GoPayStatementParser.canParse(pages), isTrue);
      expect(SeaBankStatementParser.canParse(pages), isFalse);

      final ImportedStatement result = const GoPayStatementParser().parse(
        pages,
      );

      expect(result.warnings, isEmpty);
      expect(result.periodLabel, '1 September 2026 - 30 September 2026');
      expect(result.incomeTotal, 100000);
      expect(result.expenseTotal, 132000);
      expect(result.drafts.where((d) => d.isIncome), hasLength(1));
      expect(result.drafts.where((d) => !d.isIncome), hasLength(44));
      // Baris Coins/cashback bukan uang tunai dan harus dilewati.
      expect(result.skippedCount, greaterThan(0));
    });

    test('mengisi tanggal, jam, judul, dan kategori', () {
      final ImportedStatement result = const GoPayStatementParser().parse(
        _readSample('GoPay Transaction History.pdf'),
      );

      final ImportedTransactionDraft first = result.drafts.first;
      expect(first.title, 'MRT Jakarta');
      expect(first.transactionDate, DateTime(2026, 9, 30, 17, 10));
      expect(first.amount, 3000);
      expect(first.type, 'expense');
      expect(first.suggestedCategoryName, 'Transportasi');
      expect(first.paymentMethod, 'GoPay');

      final ImportedTransactionDraft topUp = result.drafts.firstWhere(
        (d) => d.isIncome,
      );
      expect(topUp.title, 'GoPay top up');
      expect(topUp.hint, isNotNull);
    });

    test('kunci eksternal unik untuk semua transaksi', () {
      final ImportedStatement result = const GoPayStatementParser().parse(
        _readSample('GoPay Transaction History.pdf'),
      );
      final keys = result.drafts.map((d) => d.externalKey).toSet();
      expect(keys, hasLength(result.drafts.length));
    });

    test('total Agustus 2026 sesuai dokumen, termasuk nominal kecil', () {
      final ImportedStatement result = const GoPayStatementParser().parse(
        _readSample('GoPay Transaction History (1).pdf'),
      );

      expect(result.warnings, isEmpty);
      expect(result.incomeTotal, 130002);
      expect(result.expenseTotal, 115101);
    });
  });

  group('SeaBankStatementParser', () {
    test('membaca rekening koran September 2026 sesuai ringkasan', () {
      final pages = _readSample('Seabank_Statement_20261008.pdf');
      expect(SeaBankStatementParser.canParse(pages), isTrue);
      expect(GoPayStatementParser.canParse(pages), isFalse);

      final ImportedStatement result = const SeaBankStatementParser().parse(
        pages,
      );

      expect(result.warnings, isEmpty);
      expect(result.expenseTotal, 8115989);
      expect(result.incomeTotal, 7763882);
      expect(result.periodLabel, '01 SEP 2026 - 30 SEP 2026');
    });

    test('keterangan multi-baris tersusun benar', () {
      final ImportedStatement result = const SeaBankStatementParser().parse(
        _readSample('Seabank_Statement_20261008.pdf'),
      );

      final ImportedTransactionDraft interest = result.drafts.first;
      expect(interest.title, 'Bunga Tabungan');
      expect(interest.type, 'income');
      expect(interest.amount, 48);
      expect(interest.transactionDate.month, 9);
      expect(interest.transactionDate.day, 1);
      expect(interest.suggestedCategoryName, 'Bunga/Reward');

      final ImportedTransactionDraft chicken = result.drafts[1];
      expect(chicken.title, 'SUSI CHICKEN');
      expect(chicken.type, 'expense');
      expect(chicken.amount, 40000);
      expect(chicken.suggestedCategoryName, 'Makanan & Minuman');

      final ImportedTransactionDraft market = result.drafts[2];
      expect(market.title, 'Sayur Asep Pasar Karbela');
      expect(market.amount, 22000);

      final ImportedTransactionDraft transferIn = result.drafts.firstWhere(
        (d) => d.title.startsWith('Transfer dari FANNY'),
      );
      expect(transferIn.amount, 600000);
      expect(transferIn.type, 'income');
      expect(transferIn.note, contains('031401018731505'));
    });

    test('kunci eksternal unik dan stabil antar pembacaan', () {
      final first = const SeaBankStatementParser().parse(
        _readSample('Seabank_Statement_20261008.pdf'),
      );
      final second = const SeaBankStatementParser().parse(
        _readSample('Seabank_Statement_20261008.pdf'),
      );
      final keys = first.drafts.map((d) => d.externalKey).toList();

      expect(keys.toSet(), hasLength(keys.length));
      expect(keys, second.drafts.map((d) => d.externalKey).toList());
    });

    test('rekening koran Agustus 2026 juga sesuai ringkasan', () {
      final ImportedStatement result = const SeaBankStatementParser().parse(
        _readSample('Seabank_Statement_20261009.pdf'),
      );

      expect(result.warnings, isEmpty);
      expect(result.expenseTotal, 8372918);
      expect(result.incomeTotal, 8698468);
    });
  });
}
