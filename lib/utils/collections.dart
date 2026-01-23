/// Suma los valores de una lista de enteros
/// Ejemplo: sumar([1, 2, 3]) -> 6
int sumar(List<int> valores) {
  return valores.fold<int>(0, (suma, valor) => suma + valor);
}

/// Suma los valores de una lista de doubles
/// Ejemplo: sumarDoubles([1.5, 2.5, 3.0]) -> 7.0
double sumarDoubles(List<double> valores) {
  return valores.fold<double>(0.0, (suma, valor) => suma + valor);
}

/// Agrupa una lista por una clave extraída de cada elemento
/// Ejemplo: groupBy([1, 2, 3, 4], (n) => n % 2) -> {0: [2, 4], 1: [1, 3]}
Map<K, List<T>> groupBy<T, K>(List<T> lista, K Function(T) clave) {
  final resultado = <K, List<T>>{};
  for (final elemento in lista) {
    final k = clave(elemento);
    resultado.putIfAbsent(k, () => []).add(elemento);
  }
  return resultado;
}

