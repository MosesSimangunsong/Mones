import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:app/data/import/import_selection.dart';
import 'package:app/data/import/imported_transaction_draft.dart';
import 'package:app/data/local/local_database_service.dart';
import 'package:app/data/models/category.dart';
import 'package:app/data/models/money_transaction.dart';
import 'package:app/data/repositories/category_repository.dart';
import 'package:app/data/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

ImportedTransactionDraft _draft(
  String key, {
  String type = 'expense',
  double amount = 3000,
  DateTime? date,
}) {
  return ImportedTransactionDraft(
    externalKey: key,
    sourceTag: 'import_gopay',
    transactionDate: date ?? DateTime(2026, 9, 30, 17, 10),
    title: 'MRT Jakarta',
    amount: amount,
    type: type,
    paymentMethod: 'GoPay',
    suggestedCategoryName: 'Transportasi',
    note: 'Import GoPay $key',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late LocalDatabaseService databaseService;
  late CategoryRepository categoryRepository;
  late TransactionRepository transactionRepository;

  setUpAll(() async {
    final Map<String, dynamic> packageConfig =
        jsonDecode(await File('.dart_tool/package_config.json').readAsString())
            as Map<String, dynamic>;
    final Map<String, dynamic> isarPackage =
        (packageConfig['packages'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .firstWhere((p) => p['name'] == 'isar_flutter_libs');
    final String libraryPath = Uri.base
        .resolve('${isarPackage['rootUri']}/windows/isar.dll')
        .toFilePath(windows: Platform.isWindows);
    await Isar.initializeIsarCore(
      libraries: <Abi, String>{Abi.current(): libraryPath},
    );
  });

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('money_pilot_imp_');
    databaseService = LocalDatabaseService();
    await databaseService.init(directoryPath: tempDirectory.path);
    categoryRepository = CategoryRepository(databaseService.isar);
    transactionRepository = TransactionRepository(databaseService.isar);
    await categoryRepository.seedDefaultCategoriesIfNeeded();
  });

  tearDown(() async {
    await databaseService.close();
    if (tempDirectory.existsSync()) {
      tempDirectory.deleteSync(recursive: true);
    }
  });

  Future<Category> categoryNamed(String name, String type) async {
    final List<Category> items = await categoryRepository.getByType(type);
    return items.firstWhere((Category c) => c.name == name);
  }

  group('importDrafts', () {
    test('menyimpan transaksi dengan sumber dan status sinkron pending', () async {
      final Category transport = await categoryNamed('Transportasi', 'expense');

      final ImportResult result = await transactionRepository.importDrafts(
        <ImportSelection>[
          ImportSelection(draft: _draft('gopay:A1'), categoryUuid: transport.uuid),
        ],
      );

      expect(result.imported, 1);
      expect(result.duplicates, 0);
      expect(result.failed, 0);

      final List<MoneyTransaction> saved = await transactionRepository
          .getActiveTransactions();
      expect(saved, hasLength(1));
      expect(saved.single.source, 'import_gopay');
      expect(saved.single.syncStatus, 'pending');
      expect(saved.single.categoryNameSnapshot, 'Transportasi');
      expect(saved.single.amount, 3000);
      expect(saved.single.paymentMethod, 'GoPay');
    });

    test('import ulang file yang sama tidak membuat data ganda', () async {
      final Category transport = await categoryNamed('Transportasi', 'expense');
      final List<ImportSelection> batch = <ImportSelection>[
        ImportSelection(draft: _draft('gopay:A1'), categoryUuid: transport.uuid),
        ImportSelection(draft: _draft('gopay:A2'), categoryUuid: transport.uuid),
      ];

      final ImportResult first = await transactionRepository.importDrafts(batch);
      final ImportResult second = await transactionRepository.importDrafts(batch);

      expect(first.imported, 2);
      expect(second.imported, 0);
      expect(second.duplicates, 2);
      expect(await transactionRepository.getActiveTransactions(), hasLength(2));
    });

    test('transaksi yang sudah dihapus pengguna tidak hidup kembali', () async {
      final Category transport = await categoryNamed('Transportasi', 'expense');
      final List<ImportSelection> batch = <ImportSelection>[
        ImportSelection(draft: _draft('gopay:A1'), categoryUuid: transport.uuid),
      ];
      await transactionRepository.importDrafts(batch);
      final MoneyTransaction saved =
          (await transactionRepository.getActiveTransactions()).single;
      await transactionRepository.softDeleteTransaction(saved.uuid);

      final ImportResult again = await transactionRepository.importDrafts(batch);

      expect(again.duplicates, 1);
      expect(await transactionRepository.getActiveTransactions(), isEmpty);
    });

    test('kategori yang tidak cocok dengan tipe dihitung gagal', () async {
      final Category salary = await categoryNamed('Gaji', 'income');

      final ImportResult result = await transactionRepository.importDrafts(
        <ImportSelection>[
          ImportSelection(
            draft: _draft('gopay:A1', type: 'expense'),
            categoryUuid: salary.uuid,
          ),
          ImportSelection(
            draft: _draft('gopay:A2'),
            categoryUuid: 'tidak-ada',
          ),
        ],
      );

      expect(result.imported, 0);
      expect(result.failed, 2);
      expect(await transactionRepository.getActiveTransactions(), isEmpty);
    });
  });

  group('getTransactionsByLocalMonth', () {
    test('memakai batas bulan menurut zona waktu perangkat', () async {
      final Category transport = await categoryNamed('Transportasi', 'expense');
      await transactionRepository.importDrafts(<ImportSelection>[
        ImportSelection(
          draft: _draft('a', date: DateTime(2026, 9, 1, 0, 30)),
          categoryUuid: transport.uuid,
        ),
        ImportSelection(
          draft: _draft('b', date: DateTime(2026, 9, 30, 23, 30)),
          categoryUuid: transport.uuid,
        ),
        ImportSelection(
          draft: _draft('c', date: DateTime(2026, 8, 31, 23, 30)),
          categoryUuid: transport.uuid,
        ),
        ImportSelection(
          draft: _draft('d', date: DateTime(2026, 10, 1, 0, 0)),
          categoryUuid: transport.uuid,
        ),
      ]);

      final List<MoneyTransaction> september = await transactionRepository
          .getTransactionsByLocalMonth(DateTime(2026, 9));

      expect(september, hasLength(2));
      expect(
        september.every((MoneyTransaction t) {
          final DateTime local = t.transactionDate.toLocal();
          return local.year == 2026 && local.month == 9;
        }),
        isTrue,
      );
    });
  });
}
