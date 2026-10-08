import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:printing/printing.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/money_transaction.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/statement/estatement_builder.dart';
import '../../data/statement/estatement_data.dart';
import '../../data/statement/estatement_pdf_generator.dart';
import '../../shared/layouts/app_page.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_loading_state.dart';
import 'widgets/month_switcher_card.dart';

/// Membuat e-statement PDF bulanan dari transaksi hasil import.
class EStatementScreen extends StatefulWidget {
  const EStatementScreen({
    super.key,
    required this.transactionRepository,
    required this.ownerName,
    this.initialMonth,
  });

  final TransactionRepository transactionRepository;
  final String ownerName;
  final DateTime? initialMonth;

  @override
  State<EStatementScreen> createState() => _EStatementScreenState();
}

class _EStatementScreenState extends State<EStatementScreen> {
  late DateTime _month;
  bool _importsOnly = true;
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _error;
  List<MoneyTransaction> _transactions = <MoneyTransaction>[];

  @override
  void initState() {
    super.initState();
    final DateTime base = widget.initialMonth ?? DateTime.now();
    _month = DateTime(base.year, base.month);
    _load();
  }

  bool get _isCurrentMonth {
    final DateTime now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  Future<void> _load() async {
    try {
      final List<MoneyTransaction> items = await widget.transactionRepository
          .getActiveTransactions();
      if (!mounted) {
        return;
      }
      setState(() {
        _transactions = items;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'Transaksi belum bisa dimuat.';
      });
    }
  }

  EStatementData _build() {
    return EStatementBuilder.build(
      allActive: _transactions,
      month: _month,
      ownerName: widget.ownerName,
      generatedAt: DateTime.now(),
      importsOnly: _importsOnly,
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  Future<void> _generate(EStatementData data) async {
    setState(() => _isGenerating = true);
    try {
      final EStatementAssets assets = await EStatementAssets.load();
      final Uint8List bytes = await const EStatementPdfGenerator().generate(data, assets);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => _EStatementPreviewScreen(
            bytes: bytes,
            fileName: _fileName(data),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-statement belum bisa dibuat. Coba lagi.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  String _fileName(EStatementData data) {
    final String month = data.periodStart.month.toString().padLeft(2, '0');
    return 'EStatement_Mones_${data.periodStart.year}-$month.pdf';
  }

  @override
  Widget build(BuildContext context) {
    final EStatementData? data = _isLoading || _error != null ? null : _build();

    return AppPage(
      title: 'E-Statement',
      description:
          'Buat laporan PDF bulanan berlogo Mones dari transaksi hasil import.',
      children: <Widget>[
        MonthSwitcherCard(
          month: _month,
          canGoNext: !_isCurrentMonth,
          onPrevious: () => _changeMonth(-1),
          onNext: () => _changeMonth(1),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hanya hasil import'),
            subtitle: const Text(
              'Matikan untuk menyertakan transaksi manual dan suara.',
            ),
            value: _importsOnly,
            onChanged: (bool value) => setState(() => _importsOnly = value),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (_isLoading)
          const AppLoadingState(message: 'Memuat transaksi')
        else if (_error != null)
          Text(_error!)
        else if (data != null) ...<Widget>[
          _Overview(data: data),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: data.isEmpty || _isGenerating
                ? null
                : () => _generate(data),
            icon: _isGenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.fileText),
            label: Text(
              _isGenerating ? 'Membuat PDF' : 'Buat dan pratinjau e-statement',
            ),
          ),
          if (data.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(
                _importsOnly
                    ? 'Belum ada transaksi hasil import pada bulan ini. '
                          'Import file dari tab Keuangan, atau matikan filter di atas.'
                    : 'Belum ada transaksi pada bulan ini.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.data});

  final EStatementData data;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            DateFormatter.formatLongMonthYear(data.periodStart),
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${data.rows.length} transaksi - '
            '${data.sources.isEmpty ? 'tanpa sumber' : data.sources.map((EStatementSourceSummary s) => s.label).join(', ')}',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          _line('Masuk', data.incomeTotal, AppColors.success, textTheme),
          _line('Keluar', data.expenseTotal, AppColors.danger, textTheme),
          const Divider(),
          _line('Saldo tercatat akhir', data.closingTotal, AppColors.textPrimary, textTheme),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Saldo dihitung dari transaksi tercatat di Mones, bukan saldo '
            'rekening sebenarnya.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, double value, Color color, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: textTheme.bodyMedium)),
          Text(
            CurrencyFormatter.formatRupiah(value),
            style: textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EStatementPreviewScreen extends StatelessWidget {
  const _EStatementPreviewScreen({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pratinjau e-statement')),
      body: PdfPreview(
        build: (_) async => bytes,
        pdfFileName: fileName,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}
