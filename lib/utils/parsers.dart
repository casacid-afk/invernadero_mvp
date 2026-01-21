/// Parsea un string a int de forma segura, retornando null si falla
/// Ejemplo: parsearInt("123") -> 123, parsearInt("abc") -> null
int? parsearInt(String? valor) {
  if (valor == null || valor.isEmpty) return null;
  return int.tryParse(valor);
}

/// Parsea un string a int de forma segura, retornando un valor por defecto si falla
/// Ejemplo: parsearIntConDefault("123", 0) -> 123, parsearIntConDefault("abc", 0) -> 0
int parsearIntConDefault(String? valor, int valorDefault) {
  return int.tryParse(valor ?? '') ?? valorDefault;
}

/// Parsea un string a double de forma segura, retornando null si falla
/// Ejemplo: parsearDouble("123.45") -> 123.45, parsearDouble("abc") -> null
double? parsearDouble(String? valor) {
  if (valor == null || valor.isEmpty) return null;
  return double.tryParse(valor);
}

/// Parsea un string a double de forma segura, retornando un valor por defecto si falla
/// Ejemplo: parsearDoubleConDefault("123.45", 0.0) -> 123.45, parsearDoubleConDefault("abc", 0.0) -> 0.0
double parsearDoubleConDefault(String? valor, double valorDefault) {
  return double.tryParse(valor ?? '') ?? valorDefault;
}
