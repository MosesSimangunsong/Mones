/// Satu kata hasil ekstraksi dokumen beserta posisinya pada halaman.
class PositionedWord {
  const PositionedWord({
    required this.text,
    required this.left,
    required this.top,
    required this.width,
  });

  final String text;
  final double left;
  final double top;
  final double width;

  double get right => left + width;

  @override
  String toString() => 'PositionedWord($text, x=$left, y=$top)';
}

/// Utilitas pengelompokan kata menjadi baris berdasarkan posisi vertikal.
class WordRows {
  const WordRows._();

  /// Mengelompokkan [words] menjadi baris (atas ke bawah, kiri ke kanan).
  static List<List<PositionedWord>> group(
    Iterable<PositionedWord> words, {
    double tolerance = 3,
  }) {
    final List<PositionedWord> sorted = words.toList()
      ..sort((PositionedWord a, PositionedWord b) => a.top.compareTo(b.top));
    final List<List<PositionedWord>> rows = <List<PositionedWord>>[];
    double? rowTop;

    for (final PositionedWord word in sorted) {
      if (rowTop == null || (word.top - rowTop).abs() > tolerance) {
        rows.add(<PositionedWord>[word]);
        rowTop = word.top;
      } else {
        rows.last.add(word);
      }
    }

    for (final List<PositionedWord> row in rows) {
      row.sort((PositionedWord a, PositionedWord b) => a.left.compareTo(b.left));
    }
    return rows;
  }

  static String rowText(List<PositionedWord> row) {
    return row
        .map((PositionedWord word) => word.text.trim())
        .where((String text) => text.isNotEmpty)
        .join(' ');
  }

  /// Seluruh teks halaman, satu baris visual per baris teks.
  static String pageText(Iterable<PositionedWord> words) {
    return group(words).map(rowText).where((String r) => r.isNotEmpty).join('\n');
  }
}
