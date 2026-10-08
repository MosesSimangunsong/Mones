/// Satu baris teks hasil OCR beserta kotak pembatasnya.
class OcrLine {
  const OcrLine({
    required this.text,
    required this.left,
    required this.top,
    required this.height,
  });

  final String text;
  final double left;
  final double top;
  final double height;

  double get centerY => top + height / 2;
}

/// Menyusun baris OCR menjadi teks berurutan (atas ke bawah, kiri ke kanan).
class OcrTextAssembler {
  const OcrTextAssembler._();

  static String assemble(List<OcrLine> lines) {
    final List<OcrLine> sorted = List<OcrLine>.of(lines)
      ..sort((OcrLine a, OcrLine b) => a.centerY.compareTo(b.centerY));

    final List<List<OcrLine>> rows = <List<OcrLine>>[];
    for (final OcrLine line in sorted) {
      if (rows.isNotEmpty) {
        final OcrLine reference = rows.last.first;
        final double tolerance = reference.height * 0.5;
        if ((line.centerY - reference.centerY).abs() <= tolerance) {
          rows.last.add(line);
          continue;
        }
      }
      rows.add(<OcrLine>[line]);
    }

    return rows
        .map((List<OcrLine> row) {
          row.sort((OcrLine a, OcrLine b) => a.left.compareTo(b.left));
          return row.map((OcrLine l) => l.text.trim()).join(' ');
        })
        .where((String row) => row.isNotEmpty)
        .join('\n');
  }
}
