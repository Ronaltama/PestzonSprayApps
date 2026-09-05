import 'package:intl/intl.dart';

class AppFormat {
  /// Mengubah angka menjadi format string dengan pemisah ribuan (contoh: 1000 -> "1.000")
  static String thousands(num number) {
    final formatter = NumberFormat('#,##0', 'id_ID');
    return formatter.format(number);
  }
}
