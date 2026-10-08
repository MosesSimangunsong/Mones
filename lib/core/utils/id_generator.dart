import 'package:uuid/uuid.dart';

class IdGenerator {
  IdGenerator._();

  static const Uuid _uuid = Uuid();

  static String newUuid() => _uuid.v4();

  /// UUID yang selalu sama untuk [seed] yang sama. Dipakai agar data hasil
  /// import tidak tersimpan ganda saat file yang sama dibaca ulang.
  static String deterministicUuid(String seed) {
    return _uuid.v5(Namespace.url.value, 'moneypilot-import:$seed');
  }
}
