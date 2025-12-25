import 'package:intl/intl.dart';

class Fmt {
  static String qty3(num v) => NumberFormat('#,##0.000').format(v);
  static String qtyInt(num v) => NumberFormat('#,##0').format(v);
}
