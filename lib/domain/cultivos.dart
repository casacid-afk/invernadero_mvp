/// Claves internas de cultivos (sin tildes, minúsculas)
class CultivoKeys {
  static const String lechuga = 'lechuga';
  static const String cilantro = 'cilantro';
  static const String acelga = 'acelga';
  static const String rucula = 'rucula';
  static const String perejil = 'perejil';

  /// Lista de todas las keys válidas
  static const List<String> todas = [
    lechuga,
    cilantro,
    acelga,
    rucula,
    perejil,
  ];
}

/// Mapeo de keys internas a labels para mostrar en UI
class CultivoLabels {
  static const Map<String, String> _labels = {
    CultivoKeys.lechuga: 'Lechuga',
    CultivoKeys.cilantro: 'Cilantro',
    CultivoKeys.acelga: 'Acelga',
    CultivoKeys.rucula: 'Rúcula',
    CultivoKeys.perejil: 'Perejil',
  };

  /// Obtiene el label bonito para una key de cultivo
  static String obtenerLabel(String cultivoKey) {
    return _labels[cultivoKey] ?? cultivoKey;
  }
}

/// Configuración de cultivos
class CultivoConfig {
  /// Máximo número de cortes permitidos por cultivo (0 = no permite cortes, solo cosecha final)
  static const Map<String, int> maxCortes = {
    CultivoKeys.lechuga: 0, // Lechuga: solo cosecha final
    CultivoKeys.cilantro: 3, // Cilantro: permite hasta 3 cortes
    CultivoKeys.acelga: 3, // Acelga: permite hasta 3 cortes
    CultivoKeys.rucula: 3, // Rúcula: permite hasta 3 cortes
    CultivoKeys.perejil: 3, // Perejil: permite hasta 3 cortes
  };

  /// Obtiene el máximo de cortes permitidos para un cultivo
  static int obtenerMaxCortes(String cultivoKey) {
    return maxCortes[cultivoKey] ?? 0;
  }

  /// Verifica si un cultivo permite cortes (maxCortes > 0)
  static bool permiteCortes(String cultivoKey) {
    return obtenerMaxCortes(cultivoKey) > 0;
  }
}
