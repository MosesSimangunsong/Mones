import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/import/import_category_suggester.dart';
import '../../data/import/import_selection.dart';
import '../../data/import/imported_transaction_draft.dart';
import '../../data/models/category.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/services/statement_import_service.dart';
import '../../shared/layouts/app_page.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_loading_state.dart';

/// Import transaksi dari e-statement PDF atau tangkapan layar.
class ImportTransaksiScreen extends StatefulWidget {
  const ImportTransaksiScreen({
    super.key,
    required this.categoryRepository,
    required this.transactionRepository,
    this.importService = const StatementImportService(),
  });

  final CategoryRepository categoryRepository;
  final TransactionRepository transactionRepository;
  final StatementImportService importService;

  @override
  State<ImportTransaksiScreen> createState() => _ImportTransaksiScreenState();
}

class _ImportTransaksiScreenState extends State<ImportTransaksiScreen> {
  final List<_ParsedFile> _files = <_ParsedFile>[];
  bool _isReading = false;
  bool _isSaving = false;
  Map<String, List<Category>> _categories = <String, List<Category>>{};

  int get _selectedCount => _files.fold(
    0,
    (int sum, _ParsedFile file) =>
        sum + file.entries.where((_DraftEntry e) => e.selected).length,
  );

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final List<Category> expense = await widget.categoryRepository.getByType(
      'expense',
    );
    final List<Category> income = await widget.categoryRepository.getByType(
      'income',
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _categories = <String, List<Category>>{
        'expense': expense,
        'income': income,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final int selected = _selectedCount;

    return AppPage(
      title: 'Import transaksi',
      description:
          'Baca e-statement PDF atau tangkapan layar, lalu periksa sebelum disimpan.',
      floatingActionButton: selected > 0
          ? FloatingActionButton.extended(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.check),
              label: Text('Simpan $selected transaksi'),
            )
          : null,
      children: <Widget>[
        const _InfoCard(),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: _isReading || _isSaving ? null : _pickFiles,
          icon: const Icon(LucideIcons.fileUp),
          label: Text(
            _files.isEmpty ? 'Pilih file' : 'Tambah file lain',
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (_isReading)
          const AppLoadingState(message: 'Membaca file di perangkat')
        else
          for (final _ParsedFile file in _files) ...<Widget>[
            _FileSection(
              file: file,
              categories: _categories,
              onChanged: () => setState(() {}),
              onRemove: () => setState(() => _files.remove(file)),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        if (selected > 0) const SizedBox(height: 72),
      ],
    );
  }

  Future<void> _pickFiles() async {
    final List<PlatformFile> picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: StatementImportService.supportedExtensions,
    );
    if (picked.isEmpty || !mounted) {
      return;
    }

    setState(() => _isReading = true);
    final List<_ParsedFile> results = <_ParsedFile>[];

    for (final PlatformFile file in picked) {
      try {
        final ImportedStatement statement = await widget.importService.readFile(
          name: file.name,
          bytes: await file.xFile.readAsBytes(),
        );
        results.add(_ParsedFile.success(file.name, statement, _categories));
      } on AppException catch (error) {
        results.add(_ParsedFile.failure(file.name, error.message));
      } catch (_) {
        results.add(
          _ParsedFile.failure(file.name, 'File tidak bisa diproses.'),
        );
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _files.addAll(results);
      _isReading = false;
    });
  }

  Future<void> _save() async {
    final List<ImportSelection> selections = <ImportSelection>[
      for (final _ParsedFile file in _files)
        for (final _DraftEntry entry in file.entries)
          if (entry.selected && entry.categoryUuid != null)
            ImportSelection(
              draft: entry.draft,
              categoryUuid: entry.categoryUuid!,
            ),
    ];

    setState(() => _isSaving = true);
    try {
      final ImportResult result = await widget.transactionRepository
          .importDrafts(selections);
      if (!mounted) {
        return;
      }

      final List<String> parts = <String>[
        '${result.imported} transaksi diimpor',
        if (result.duplicates > 0) '${result.duplicates} sudah ada',
        if (result.failed > 0) '${result.failed} gagal',
      ];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${parts.join(', ')}.')),
      );
      context.pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaksi belum bisa disimpan. Coba lagi.'),
        ),
      );
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return AppCard(
      backgroundColor: AppColors.infoSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Yang didukung', style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '- E-statement GoPay (PDF)\n'
            '- Rekening koran SeaBank (PDF)\n'
            '- Tangkapan layar Laporan DANA (PNG/JPG), berupa total per '
            'kategori',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(LucideIcons.shieldCheck, size: 16),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'File dibaca di perangkat ini dan tidak dikirim ke server.',
                  style: textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FileSection extends StatelessWidget {
  const _FileSection({
    required this.file,
    required this.categories,
    required this.onChanged,
    required this.onRemove,
  });

  final _ParsedFile file;
  final Map<String, List<Category>> categories;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ImportedStatement? statement = file.statement;

    if (statement == null) {
      return AppCard(
        backgroundColor: AppColors.dangerSoft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(LucideIcons.circleAlert, color: AppColors.danger),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(file.name, style: textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(file.error ?? 'File tidak bisa diproses.'),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Hapus dari daftar',
              onPressed: onRemove,
              icon: const Icon(LucideIcons.x),
            ),
          ],
        ),
      );
    }

    final int selectedCount = file.entries
        .where((_DraftEntry e) => e.selected)
        .length;
    final bool allSelected = selectedCount == file.entries.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      statement.providerLabel,
                      style: textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hapus dari daftar',
                    onPressed: onRemove,
                    icon: const Icon(LucideIcons.x),
                  ),
                ],
              ),
              Text(
                '${file.name}${statement.periodLabel == null ? '' : ' - ${statement.periodLabel}'}',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${statement.drafts.length} transaksi - '
                'masuk ${CurrencyFormatter.formatRupiah(statement.incomeTotal)} - '
                'keluar ${CurrencyFormatter.formatRupiah(statement.expenseTotal)}',
                style: textTheme.bodyMedium,
              ),
              if (statement.skippedCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    '${statement.skippedCount} baris poin/Coins dilewati karena bukan uang tunai.',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              for (final String warning in statement.warnings)
                _Warning(text: warning),
            ],
          ),
        ),
        if (file.entries.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                for (final _DraftEntry entry in file.entries) {
                  entry.selected = !allSelected;
                }
                onChanged();
              },
              child: Text(allSelected ? 'Hapus semua pilihan' : 'Pilih semua'),
            ),
          ),
          for (final _DraftEntry entry in file.entries)
            _DraftTile(
              entry: entry,
              options: categories[entry.draft.type] ?? const <Category>[],
              onChanged: onChanged,
            ),
        ],
      ],
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.warningBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(LucideIcons.triangleAlert, size: 16, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _DraftTile extends StatelessWidget {
  const _DraftTile({
    required this.entry,
    required this.options,
    required this.onChanged,
  });

  final _DraftEntry entry;
  final List<Category> options;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ImportedTransactionDraft draft = entry.draft;
    final Color amountColor = draft.isIncome
        ? AppColors.success
        : AppColors.danger;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Checkbox(
              value: entry.selected,
              onChanged: (bool? value) {
                entry.selected = value ?? false;
                onChanged();
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          draft.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${draft.isIncome ? '+' : '-'}${CurrencyFormatter.formatRupiah(draft.amount)}',
                        style: textTheme.titleSmall?.copyWith(
                          color: amountColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _dateLabel(draft),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (draft.hint != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        draft.hint!,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  if (options.isNotEmpty)
                    DropdownButton<String>(
                      isExpanded: true,
                      isDense: true,
                      value: options.any((Category c) => c.uuid == entry.categoryUuid)
                          ? entry.categoryUuid
                          : null,
                      hint: const Text('Pilih kategori'),
                      items: <DropdownMenuItem<String>>[
                        for (final Category category in options)
                          DropdownMenuItem<String>(
                            value: category.uuid,
                            child: Text(category.name),
                          ),
                      ],
                      onChanged: (String? value) {
                        entry.categoryUuid = value;
                        onChanged();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dateLabel(ImportedTransactionDraft draft) {
    final bool hasTime = draft.sourceTag == 'import_gopay';
    return hasTime
        ? DateFormatter.formatDateTime(draft.transactionDate)
        : DateFormatter.formatShortDate(draft.transactionDate);
  }
}

class _ParsedFile {
  _ParsedFile._({
    required this.name,
    this.statement,
    this.error,
    this.entries = const <_DraftEntry>[],
  });

  factory _ParsedFile.success(
    String name,
    ImportedStatement statement,
    Map<String, List<Category>> categories,
  ) {
    return _ParsedFile._(
      name: name,
      statement: statement,
      entries: <_DraftEntry>[
        for (final ImportedTransactionDraft draft in statement.drafts)
          _DraftEntry(
            draft: draft,
            categoryUuid: _resolveCategory(draft, categories),
          ),
      ],
    );
  }

  factory _ParsedFile.failure(String name, String error) {
    return _ParsedFile._(name: name, error: error);
  }

  final String name;
  final ImportedStatement? statement;
  final String? error;
  final List<_DraftEntry> entries;

  static String? _resolveCategory(
    ImportedTransactionDraft draft,
    Map<String, List<Category>> categories,
  ) {
    final List<Category> options = categories[draft.type] ?? <Category>[];
    for (final Category category in options) {
      if (category.name == draft.suggestedCategoryName) {
        return category.uuid;
      }
    }
    for (final Category category in options) {
      if (category.name == ImportCategorySuggester.fallback) {
        return category.uuid;
      }
    }
    return options.isEmpty ? null : options.first.uuid;
  }
}

class _DraftEntry {
  _DraftEntry({required this.draft, required this.categoryUuid});

  final ImportedTransactionDraft draft;
  String? categoryUuid;
  bool selected = true;
}
