import 'package:intl/intl.dart';

String formatoCLP(num valor) {
  final formatter = NumberFormat.currency(
    locale: 'es_CL',
    symbol: '\$',
    decimalDigits: 0,
  );
  return formatter.format(valor);
}




