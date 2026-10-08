class DateFormatter {
  const DateFormatter._();

  static const List<String> _monthNames = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static const List<String> _longMonthNames = <String>[
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  // Indeks mengikuti DateTime.weekday (Senin = 1).
  static const List<String> _weekdayNames = <String>[
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  static String formatShortDate(DateTime value) {
    final DateTime local = value.toLocal();
    return '${local.day} ${_monthNames[local.month - 1]} ${local.year}';
  }

  static String formatMonthYear(DateTime value) {
    final DateTime local = value.toLocal();
    return '${_monthNames[local.month - 1]} ${local.year}';
  }

  static String formatDateTime(DateTime value) {
    final DateTime local = value.toLocal();
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${_monthNames[local.month - 1]} ${local.year}, $hour:$minute';
  }

  /// Contoh: "September 2026".
  static String formatLongMonthYear(DateTime value) {
    final DateTime local = value.toLocal();
    return '${_longMonthNames[local.month - 1]} ${local.year}';
  }

  /// Contoh: "Rabu, 24 Sep 2026".
  static String formatWeekdayDate(DateTime value) {
    final DateTime local = value.toLocal();
    return '${_weekdayNames[local.weekday - 1]}, ${formatShortDate(local)}';
  }

  /// Contoh: "17:10".
  static String formatTime(DateTime value) {
    final DateTime local = value.toLocal();
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
