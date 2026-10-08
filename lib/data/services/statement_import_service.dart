import 'dart:io';
import 'dart:typed_data';

import '../../core/errors/app_exception.dart';
import '../import/dana_report_parser.dart';
import '../import/gopay_statement_parser.dart';
import '../import/imported_transaction_draft.dart';
import '../import/positioned_word.dart';
import '../import/seabank_statement_parser.dart';
import 'image_text_recognizer.dart';
import 'pdf_statement_text_reader.dart';

/// Membaca file PDF/gambar dan menghasilkan draft transaksi.
///
/// Seluruh proses berjalan di perangkat. File tidak dikirim ke backend.
class StatementImportService {
  const StatementImportService({
    this.pdfReader = const PdfStatementTextReader(),
    this.imageRecognizer = const MlKitImageTextRecognizer(),
  });

  final PdfStatementTextReader pdfReader;
  final ImageTextRecognizer imageRecognizer;

  static const List<String> pdfExtensions = <String>['pdf'];
  static const List<String> imageExtensions = <String>[
    'png',
    'jpg',
    'jpeg',
    'webp',
  ];
  static const List<String> supportedExtensions = <String>[
    ...pdfExtensions,
    ...imageExtensions,
  ];

  /// Membaca file berdasarkan ekstensi [name]. Memakai byte karena pemilih
  /// file Android bisa mengembalikan URI tanpa path file.
  Future<ImportedStatement> readFile({
    required String name,
    required Uint8List bytes,
  }) async {
    final String extension = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : '';

    if (pdfExtensions.contains(extension)) {
      return readPdf(bytes);
    }

    if (imageExtensions.contains(extension)) {
      final Directory directory = await Directory.systemTemp.createTemp(
        'moneypilot_import_',
      );
      try {
        final File file = File('${directory.path}/image.$extension');
        await file.writeAsBytes(bytes, flush: true);
        return readImageText(await imageRecognizer.recognize(file.path));
      } finally {
        // Salinan sementara dibuang agar gambar tidak tertinggal di perangkat.
        await directory.delete(recursive: true);
      }
    }

    throw AppException(
      'Format file .$extension belum didukung. Gunakan PDF, PNG, atau JPG.',
    );
  }

  ImportedStatement readPdf(Uint8List bytes) {
    final List<List<PositionedWord>> pages = pdfReader.readPages(bytes);

    if (GoPayStatementParser.canParse(pages)) {
      return const GoPayStatementParser().parse(pages);
    }
    if (SeaBankStatementParser.canParse(pages)) {
      return const SeaBankStatementParser().parse(pages);
    }

    throw AppException(
      'Format PDF belum dikenali. Saat ini yang didukung: e-statement GoPay '
      'dan rekening koran SeaBank.',
    );
  }

  ImportedStatement readImageText(String text) {
    if (DanaReportParser.canParse(text)) {
      return const DanaReportParser().parse(text);
    }

    throw AppException(
      'Gambar belum dikenali. Saat ini yang didukung: tangkapan layar '
      'Laporan DANA.',
    );
  }
}
