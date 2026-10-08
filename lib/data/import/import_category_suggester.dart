/// Menebak kategori bawaan MoneyPilot dari judul transaksi hasil import.
///
/// Nama yang dikembalikan harus sama dengan nama kategori bawaan pada
/// `CategoryRepository`. Pengguna tetap bisa mengubahnya di layar pratinjau.
class ImportCategorySuggester {
  const ImportCategorySuggester._();

  static const String fallback = 'Lainnya';

  static const List<(String, List<String>)> _expenseRules =
      <(String, List<String>)>[
        (
          'Transportasi',
          <String>[
            'mrt',
            'krl',
            'commuter',
            'transjakarta',
            'busway',
            'gojek',
            'gocar',
            'goride',
            'grab',
            'maxim',
            'parkir',
            'tol ',
            'bensin',
            'pertamina',
            'tiket kereta',
          ],
        ),
        (
          'Makanan & Minuman',
          <String>[
            'chicken',
            'ayam',
            'warung',
            'resto',
            'kopi',
            'coffee',
            'cafe',
            'bakso',
            'mie ',
            'nasi',
            'makan',
            'minum',
            'sayur',
            'roti',
            'bakery',
            'kantin',
            'geprek',
            'sate',
            'pizza',
            'kfc',
            'mcd',
            'burger',
            'starbucks',
            'boba',
            'catering',
            'warteg',
          ],
        ),
        (
          'Kuliah/Pendidikan',
          <String>[
            'lppm',
            'pi-del',
            'ukt',
            'spp',
            'kampus',
            'universitas',
            'institut',
            'fotokopi',
            'kuliah',
          ],
        ),
        ('Kos/Asrama', <String>['kos ', 'kost', 'asrama']),
        (
          'Hiburan',
          <String>[
            'netflix',
            'spotify',
            'youtube',
            'bioskop',
            'cgv',
            'xxi',
            'steam',
            'disney',
            'vidio',
          ],
        ),
        (
          'Kesehatan',
          <String>[
            'apotek',
            'klinik',
            'rumah sakit',
            'dokter',
            'halodoc',
            'kimia farma',
          ],
        ),
        ('Investasi', <String>['bibit', 'bareksa', 'ajaib', 'saham', 'reksa']),
        (
          'Belanja',
          <String>[
            'alfagift',
            'alfamart',
            'indomaret',
            'toko',
            'mart',
            'shopee',
            'tokopedia',
            'lazada',
            'blibli',
            'supermarket',
            'belanja',
          ],
        ),
      ];

  static const List<(String, List<String>)> _incomeRules =
      <(String, List<String>)>[
        ('Bunga/Reward', <String>['bunga', 'cashback', 'reward']),
        ('Gaji', <String>['gaji', 'salary', 'payroll']),
        ('Beasiswa', <String>['beasiswa']),
        ('Dividen', <String>['dividen']),
        ('Uang dari Orang Tua', <String>['orang tua', 'ortu']),
      ];

  static String suggest({required String title, required String type}) {
    final String haystack = '${title.toLowerCase()} ';
    final List<(String, List<String>)> rules = type == 'income'
        ? _incomeRules
        : _expenseRules;
    for (final (String category, List<String> keywords) in rules) {
      for (final String keyword in keywords) {
        if (haystack.contains(keyword)) {
          return category;
        }
      }
    }
    return fallback;
  }
}
