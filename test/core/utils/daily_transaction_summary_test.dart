import 'package:app/core/utils/daily_transaction_summary.dart';
import 'package:app/core/utils/transaction_source_label.dart';
import 'package:app/data/models/money_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

MoneyTransaction _transaction(
  String uuid,
  DateTime localDate,
  double amount, {
  String type = 'expense',
}) {
  return MoneyTransaction(
    uuid: uuid,
    type: type,
    title: uuid,
    amount: amount,
    categoryUuid: 'cat',
    categoryNameSnapshot: 'Lainnya',
    source: 'manual',
    transactionDate: localDate.toUtc(),
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('DailyTransactionAggregator', () {
    test('mengelompokkan per hari lokal dengan hari terbaru lebih dulu', () {
      final List<DailyTransactionSummary> days =
          DailyTransactionAggregator.group(<MoneyTransaction>[
            _transaction('a', DateTime(2026, 9, 1, 8), 3000),
            _transaction('b', DateTime(2026, 9, 2, 9), 5000),
            _transaction('c', DateTime(2026, 9, 1, 18), 7000),
          ]);

      expect(days, hasLength(2));
      expect(days.first.date, DateTime(2026, 9, 2));
      expect(days.last.date, DateTime(2026, 9, 1));
      expect(
        days.last.transactions.map((MoneyTransaction t) => t.uuid),
        <String>['c', 'a'],
      );
    });

    test('menghitung total pemasukan, pengeluaran, dan selisih per hari', () {
      final List<DailyTransactionSummary> days =
          DailyTransactionAggregator.group(<MoneyTransaction>[
            _transaction('a', DateTime(2026, 9, 1, 8), 3000),
            _transaction('b', DateTime(2026, 9, 1, 9), 10000, type: 'income'),
            _transaction('c', DateTime(2026, 9, 1, 10), 2000),
          ]);

      expect(days.single.expenseTotal, 5000);
      expect(days.single.incomeTotal, 10000);
      expect(days.single.net, 5000);
    });

    test('daftar kosong menghasilkan daftar kosong', () {
      expect(DailyTransactionAggregator.group(<MoneyTransaction>[]), isEmpty);
    });
  });

  group('TransactionSourceLabel', () {
    test('label dikenal dan fallback ke nilai asli', () {
      expect(TransactionSourceLabel.of('manual'), 'Input manual');
      expect(TransactionSourceLabel.of('import_gopay'), 'Import GoPay');
      expect(TransactionSourceLabel.of('lain'), 'lain');
    });

    test('import bank/laporan tidak menampilkan jam', () {
      expect(TransactionSourceLabel.hasTimeOfDay('import_seabank'), isFalse);
      expect(TransactionSourceLabel.hasTimeOfDay('import_dana'), isFalse);
      expect(TransactionSourceLabel.hasTimeOfDay('import_gopay'), isTrue);
      expect(TransactionSourceLabel.hasTimeOfDay('manual'), isTrue);
    });
  });
}
