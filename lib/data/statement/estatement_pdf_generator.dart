import 'dart:typed_data';

import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/currency_formatter.dart';
import 'estatement_data.dart';

/// Aset yang dibutuhkan untuk menggambar e-statement.
class EStatementAssets {
  const EStatementAssets({
    required this.logo,
    required this.regular,
    required this.medium,
    required this.bold,
  });

  final Uint8List logo;
  final ByteData regular;
  final ByteData medium;
  final ByteData bold;

  static Future<EStatementAssets> load() async {
    final ByteData logo = await rootBundle.load(
      'assets/branding/moneypilot_logo_wide.png',
    );
    return EStatementAssets(
      logo: logo.buffer.asUint8List(logo.offsetInBytes, logo.lengthInBytes),
      regular: await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
      medium: await rootBundle.load('assets/fonts/Roboto-Medium.ttf'),
      bold: await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
  }
}

/// Membuat PDF e-statement MoneyPilot.
///
/// Susunannya mengikuti format rekening koran: kop berlogo, identitas,
/// ringkasan, rincian transaksi dengan saldo berjalan, dan ketentuan umum.
class EStatementPdfGenerator {
  const EStatementPdfGenerator();

  // Warna mengikuti AppColors.
  static const PdfColor _navy = PdfColor.fromInt(0xFF102A43);
  static const PdfColor _blue = PdfColor.fromInt(0xFF2F6FED);
  static const PdfColor _gray = PdfColor.fromInt(0xFF667085);
  static const PdfColor _lightGray = PdfColor.fromInt(0xFF98A2B3);
  static const PdfColor _border = PdfColor.fromInt(0xFFE2E8F0);
  static const PdfColor _headerFill = PdfColor.fromInt(0xFFEAF1FF);
  static const PdfColor _success = PdfColor.fromInt(0xFF168A5B);

  static const List<String> _months = <String>[
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MEI',
    'JUN',
    'JUL',
    'AGU',
    'SEP',
    'OKT',
    'NOV',
    'DES',
  ];

  Future<Uint8List> generate(
    EStatementData data,
    EStatementAssets assets,
  ) async {
    final pw.Font regular = pw.Font.ttf(assets.regular);
    final pw.Font medium = pw.Font.ttf(assets.medium);
    final pw.Font bold = pw.Font.ttf(assets.bold);
    final pw.MemoryImage logo = pw.MemoryImage(assets.logo);

    final pw.Document document = pw.Document(
      title: 'E-Statement Mones ${data.serialNumber}',
      author: 'Mones',
      creator: 'Mones',
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 28, 36, 36),
        header: (pw.Context context) => _header(logo, data, medium),
        footer: (pw.Context context) => _footer(context),
        build: (pw.Context context) => <pw.Widget>[
          pw.SizedBox(height: 18),
          ..._identity(data, medium),
          pw.SizedBox(height: 26),
          ..._summary(data, medium),
          pw.SizedBox(height: 26),
          ..._details(data, medium),
          ..._sourceDetails(data, medium),
          pw.NewPage(),
          _terms(data, medium),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _header(pw.MemoryImage logo, EStatementData data, pw.Font medium) {
    final pw.TextStyle style = pw.TextStyle(
      font: medium,
      fontSize: 10,
      color: _gray,
    );

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _blue, width: 1.4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: <pw.Widget>[
          pw.Image(logo, height: 34),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: <pw.Widget>[
              pw.Text('LAPORAN KEUANGAN', style: style),
              pw.Text('S/N ${data.serialNumber}', style: style),
              pw.Text(_dmy(data.generatedAt), style: style),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Context context) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'halaman ${context.pageNumber} dr ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 10, color: _lightGray),
      ),
    );
  }

  List<pw.Widget> _identity(EStatementData data, pw.Font medium) {
    final pw.TextStyle label = const pw.TextStyle(fontSize: 8, color: _gray);
    final pw.TextStyle value = const pw.TextStyle(fontSize: 8, color: _navy);
    final String scope = data.importsOnly
        ? 'Transaksi hasil import'
        : 'Seluruh transaksi tercatat';
    final String sources = data.sources.isEmpty
        ? '-'
        : data.sources.map((EStatementSourceSummary s) => s.label).join(', ');

    pw.Widget line(String key, String text) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.SizedBox(width: 62, child: pw.Text(key, style: label)),
            pw.Expanded(child: pw.Text(text, style: value)),
          ],
        ),
      );
    }

    return <pw.Widget>[
      pw.Text(
        data.ownerName.toUpperCase(),
        style: pw.TextStyle(font: medium, fontSize: 13, color: _navy),
      ),
      pw.SizedBox(height: 8),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(right: 12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  line('NO. LAPORAN', data.serialNumber),
                  line('CAKUPAN', scope),
                  line('SUMBER', sources),
                  line('TRANSAKSI', '${data.rows.length} transaksi'),
                ],
              ),
            ),
          ),
          pw.Container(
            width: 190,
            padding: const pw.EdgeInsets.only(left: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(left: pw.BorderSide(color: _border, width: 0.8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text('Tentang laporan', style: value),
                pw.SizedBox(height: 6),
                line('Periode', '${_dmy(data.periodStart)} - ${_dmy(data.periodEnd)}'),
                line('Dibuat', _dmyHm(data.generatedAt)),
                line('Aplikasi', 'Mones'),
                pw.Text(
                  'Dibuat otomatis di perangkat Anda dari data yang tercatat.',
                  style: label,
                ),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  List<pw.Widget> _summary(EStatementData data, pw.Font medium) {
    final pw.TextStyle head = pw.TextStyle(font: medium, fontSize: 6.5, color: _navy);
    final pw.TextStyle cell = const pw.TextStyle(fontSize: 8, color: _navy);

    pw.Widget text(String value, pw.TextStyle style, {bool right = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: pw.Align(
          alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          child: pw.Text(value, style: style),
        ),
      );
    }

    final pw.Table table = pw.Table(
      columnWidths: <int, pw.TableColumnWidth>{
        0: const pw.FlexColumnWidth(2.2),
        1: const pw.FlexColumnWidth(1.6),
        2: const pw.FlexColumnWidth(1.8),
        3: const pw.FlexColumnWidth(1.8),
        4: const pw.FlexColumnWidth(1.6),
      },
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _border, width: 0.6),
      ),
      children: <pw.TableRow>[
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _headerFill),
          children: <pw.Widget>[
            text('SUMBER', head),
            text('SALDO AWAL (IDR)', head, right: true),
            text('TRANSAKSI KELUAR (IDR)', head, right: true),
            text('TRANSAKSI MASUK (IDR)', head, right: true),
            text('SALDO AKHIR (IDR)', head, right: true),
          ],
        ),
        for (final EStatementSourceSummary source in data.sources)
          pw.TableRow(
            children: <pw.Widget>[
              text(source.label.toUpperCase(), cell),
              text(_num(source.opening), cell, right: true),
              text(_num(source.expense), cell, right: true),
              text(_num(source.income), cell, right: true),
              text(_num(source.closing), cell, right: true),
            ],
          ),
        if (data.sources.isEmpty)
          pw.TableRow(
            children: <pw.Widget>[
              text('Tidak ada data', cell),
              text('', cell),
              text('', cell),
              text('', cell),
              text('', cell),
            ],
          ),
      ],
    );

    return <pw.Widget>[
      pw.Center(
        child: pw.Text(
          'RINGKASAN LAPORAN',
          style: pw.TextStyle(font: medium, fontSize: 12, color: _navy),
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Center(
        child: pw.Text(
          '${_dmy(data.periodStart)} sampai ${_dmy(data.periodEnd)}',
          style: const pw.TextStyle(fontSize: 8, color: _lightGray),
        ),
      ),
      pw.SizedBox(height: 12),
      pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _border, width: 0.8),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          children: <pw.Widget>[
            table,
            pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: _border, width: 0.6)),
              ),
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'TOTAL: ${_num(data.closingTotal)}',
                  style: pw.TextStyle(font: medium, fontSize: 8, color: _navy),
                ),
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 5),
      pw.Text(
        'Saldo dihitung dari transaksi yang tercatat di Mones '
        '(pemasukan dikurangi pengeluaran), bukan saldo rekening sebenarnya.',
        style: const pw.TextStyle(fontSize: 6.5, color: _lightGray),
      ),
    ];
  }

  List<pw.Widget> _details(EStatementData data, pw.Font medium) {
    final List<pw.Widget> content = <pw.Widget>[
      _sectionTitle('RINCIAN TRANSAKSI', medium),
      pw.SizedBox(height: 12),
    ];

    if (data.rows.isEmpty) {
      content.add(
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _border, width: 0.8),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Center(
            child: pw.Text(
              'Tidak ada transaksi pada periode ini.',
              style: const pw.TextStyle(fontSize: 8, color: _gray),
            ),
          ),
        ),
      );
      return content;
    }

    content.add(_rowsTable(data.rows, medium, withSource: true));
    return content;
  }

  List<pw.Widget> _sourceDetails(EStatementData data, pw.Font medium) {
    final List<pw.Widget> content = <pw.Widget>[];

    for (final EStatementSourceSummary source in data.sources) {
      if (source.rows.isEmpty) {
        continue;
      }
      content.addAll(<pw.Widget>[
        pw.NewPage(freeSpace: 160),
        pw.SizedBox(height: 26),
        _sectionTitle('${source.label.toUpperCase()} - RINCIAN TRANSAKSI', medium),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            'Saldo awal ${_num(source.opening)}',
            style: const pw.TextStyle(fontSize: 8, color: _lightGray),
          ),
        ),
        pw.SizedBox(height: 12),
        _rowsTable(source.rows, medium, withSource: false),
        pw.SizedBox(height: 6),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'SUBTOTAL: ${_num(source.closing)}',
            style: pw.TextStyle(font: medium, fontSize: 8, color: _navy),
          ),
        ),
      ]);
    }

    return content;
  }

  pw.Widget _sectionTitle(String text, pw.Font medium) {
    return pw.Center(
      child: pw.Text(
        text,
        style: pw.TextStyle(font: medium, fontSize: 12, color: _navy),
      ),
    );
  }

  pw.Widget _rowsTable(
    List<EStatementRow> rows,
    pw.Font medium, {
    required bool withSource,
  }) {
    final pw.TextStyle head = pw.TextStyle(font: medium, fontSize: 6.5, color: _navy);
    final pw.TextStyle cell = const pw.TextStyle(fontSize: 8, color: _navy);
    final pw.TextStyle income = const pw.TextStyle(fontSize: 8, color: _success);
    final pw.TextStyle detail = const pw.TextStyle(fontSize: 6.5, color: _lightGray);
    final pw.TextStyle sourceStyle = pw.TextStyle(
      font: medium,
      fontSize: 7,
      color: _blue,
    );

    pw.Widget padded(pw.Widget child, {pw.Alignment? align}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        child: align == null ? child : pw.Align(alignment: align, child: child),
      );
    }

    pw.Widget headCell(String value, {bool right = false}) => padded(
      pw.Text(value, style: head),
      align: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
    );

    pw.Widget amount(double value, pw.TextStyle style) => padded(
      pw.Text(value == 0 ? '' : _num(value), style: style),
      align: pw.Alignment.centerRight,
    );

    return pw.Table(
      columnWidths: <int, pw.TableColumnWidth>{
        0: const pw.FixedColumnWidth(58),
        1: const pw.FlexColumnWidth(),
        if (withSource) 2: const pw.FixedColumnWidth(58),
        withSource ? 3 : 2: const pw.FixedColumnWidth(66),
        withSource ? 4 : 3: const pw.FixedColumnWidth(66),
        withSource ? 5 : 4: const pw.FixedColumnWidth(78),
      },
      border: const pw.TableBorder(
        top: pw.BorderSide(color: _border, width: 0.8),
        bottom: pw.BorderSide(color: _border, width: 0.8),
        left: pw.BorderSide(color: _border, width: 0.8),
        right: pw.BorderSide(color: _border, width: 0.8),
        horizontalInside: pw.BorderSide(color: _border, width: 0.6),
      ),
      children: <pw.TableRow>[
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: _headerFill),
          children: <pw.Widget>[
            headCell('TANGGAL'),
            headCell('TRANSAKSI'),
            if (withSource) headCell('SUMBER'),
            headCell('KELUAR (IDR)', right: true),
            headCell('MASUK (IDR)', right: true),
            headCell('SALDO AKHIR (IDR)', right: true),
          ],
        ),
        for (final EStatementRow row in rows)
          pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: <pw.Widget>[
              padded(pw.Text(_dm(row.date), style: cell)),
              padded(
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text(row.title, style: cell),
                    pw.SizedBox(height: 3),
                    pw.Text(row.detail, style: detail),
                  ],
                ),
              ),
              if (withSource) padded(pw.Text(row.source, style: sourceStyle)),
              amount(row.expense, cell),
              amount(row.income, income),
              padded(
                pw.Text(_num(row.balance), style: cell),
                align: pw.Alignment.centerRight,
              ),
            ],
          ),
      ],
    );
  }

  pw.Widget _terms(EStatementData data, pw.Font medium) {
    final pw.TextStyle title = pw.TextStyle(font: medium, fontSize: 9, color: _navy);
    final pw.TextStyle body = const pw.TextStyle(
      fontSize: 7,
      color: _gray,
      lineSpacing: 2,
    );

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text('Ketentuan Umum', style: title),
          pw.SizedBox(height: 4),
          pw.Text(
            'E-Statement ini dibuat otomatis oleh aplikasi Mones dari '
            'transaksi yang Anda catat atau import, dan tidak memerlukan tanda '
            'tangan. Dokumen ini bukan dokumen resmi bank, dompet digital, atau '
            'lembaga keuangan mana pun. Mohon periksa kembali isinya dengan '
            'dokumen aslinya jika dibutuhkan.',
            style: body,
          ),
          pw.SizedBox(height: 10),
          pw.Text('Tentang Saldo', style: title),
          pw.SizedBox(height: 4),
          pw.Text(
            'Saldo awal dan saldo akhir dihitung dari pemasukan dikurangi '
            'pengeluaran pada transaksi yang tercatat di Mones dan dapat '
            'berbeda dari saldo sebenarnya di rekening atau dompet digital Anda.',
            style: body,
          ),
          pw.SizedBox(height: 10),
          pw.Text('Privasi', style: title),
          pw.SizedBox(height: 4),
          pw.Text(
            'Data dalam laporan ini tersimpan di perangkat Anda. Mones '
            'tidak mengirim transaksi atau data keuangan pribadi ke server.',
            style: body,
          ),
        ],
      ),
    );
  }

  String _dm(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')} ${_months[value.month - 1]}';
  }

  String _dmy(DateTime value) => '${_dm(value)} ${value.year}';

  String _dmyHm(DateTime value) {
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '${_dmy(value)}, $hour:$minute';
  }

  String _num(double value) {
    return CurrencyFormatter.formatRupiah(value).replaceFirst('Rp', '');
  }
}
