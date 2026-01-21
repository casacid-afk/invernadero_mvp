import 'package:intl/intl.dart';

/// Formatea un valor numérico como moneda CLP (pesos chilenos)
/// Ejemplo: formatoCLP(20000) -> "$20.000"
String formatoCLP(num valor) {
  final formatter = NumberFormat.currency(
    locale: 'es_CL',
    symbol: '\$',
    decimalDigits: 0,
  );
  return formatter.format(valor);
}

/// Formatea una fecha en formato corto (DD/MM/YYYY)
/// Ejemplo: formatoFechaCorta(DateTime(2024, 1, 15)) -> "15/1/2024"
String formatoFechaCorta(DateTime fecha) {
  return '${fecha.day}/${fecha.month}/${fecha.year}';
}

/// Formatea una fecha en formato con guiones (DD-MM-YYYY)
/// Ejemplo: formatoFechaGuiones(DateTime(2024, 1, 5)) -> "05-01-2024"
String formatoFechaGuiones(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  final ano = fecha.year.toString();
  return '$dia-$mes-$ano';
}
