import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../core/errors/app_exception.dart';
import '../import/positioned_word.dart';

/// Membaca kata beserta posisinya dari PDF e-statement langsung di perangkat.
///
/// Posisi dipakai karena urutan teks hasil ekstraksi PDF tabel tidak stabil,
/// sedangkan kolom pada tabel mutasi selalu berada di koordinat yang sama.
class PdfStatementTextReader {
  const PdfStatementTextReader();

  /// Mengembalikan daftar kata untuk tiap halaman.
  List<List<PositionedWord>> readPages(Uint8List bytes) {
    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: bytes);
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      final List<List<PositionedWord>> pages = <List<PositionedWord>>[];
      for (int index = 0; index < document.pages.count; index++) {
        final List<PositionedWord> words = <PositionedWord>[];
        for (final TextLine line in extractor.extractTextLines(
          startPageIndex: index,
          endPageIndex: index,
        )) {
          for (final TextWord word in line.wordCollection) {
            if (word.text.trim().isEmpty) {
              continue;
            }
            words.add(
              PositionedWord(
                text: word.text.trim(),
                left: word.bounds.left,
                top: word.bounds.top,
                width: word.bounds.width,
              ),
            );
          }
        }
        pages.add(words);
      }
      return pages;
    } catch (_) {
      throw AppException(
        'File PDF tidak bisa dibaca. Pastikan file tidak diproteksi password.',
      );
    } finally {
      document?.dispose();
    }
  }
}
