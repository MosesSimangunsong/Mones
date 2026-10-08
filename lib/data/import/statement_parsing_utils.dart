/// Helper bersama untuk parser mutasi/laporan.
class StatementParsingUtils {
  const StatementParsingUtils._();

  static const Map<String, int> _months = <String, int>{
    'jan': 1,
    'januari': 1,
    'feb': 2,
    'februari': 2,
    'mar': 3,
    'maret': 3,
    'apr': 4,
    'april': 4,
    'mei': 5,
    'may': 5,
    'jun': 6,
    'juni': 6,
    'jul': 7,
    'juli': 7,
    'agu': 8,
    'agt': 8,
    'aug': 8,
    'agustus': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'okt': 10,
    'oct': 10,
    'oktober': 10,
    'nov': 11,
    'november': 11,
    'des': 12,
    'dec': 12,
    'desember': 12,
  };

  /// Nomor bulan (1-12) dari nama bulan Indonesia/Inggris, atau null.
  static int? monthNumber(String name) {
    return _months[name.trim().toLowerCase().replaceAll('.', '')];
  }

  /// Mengubah "Rp1.234.567", "-Rp3.000", "1.234" menjadi angka rupiah.
  /// Mengembalikan null jika teks bukan nominal.
  static double? parseRupiah(String raw) {
    final String text = raw.trim();
    final RegExpMatch? match = RegExp(
      r'^([+-])?\s*(?:Rp\.?)?\s*([0-9]{1,3}(?:[.,][0-9]{3})*|[0-9]+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) {
      return null;
    }
    final double? value = double.tryParse(
      match.group(2)!.replaceAll('.', '').replaceAll(',', ''),
    );
    if (value == null) {
      return null;
    }
    return match.group(1) == '-' ? -value : value;
  }

  /// Tanggal bersifat tanpa jam: dipasang jam 12.00 agar aman terhadap zona
  /// waktu. [sequence] menjaga urutan transaksi pada hari yang sama.
  static DateTime dateOnly(int year, int month, int day, {int sequence = 0}) {
    return DateTime(year, month, day, 12, 0, sequence.clamp(0, 3599));
  }
}
