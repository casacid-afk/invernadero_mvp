import 'package:shared_preferences/shared_preferences.dart';
import '../domain/cultivos.dart';

/// Metas diarias por defecto para cada cultivo
const Map<String, int> METAS_DIARIAS_POR_CULTIVO = {
  CultivoKeys.lechuga: 50,
  CultivoKeys.cilantro: 40,
  CultivoKeys.acelga: 35,
  CultivoKeys.rucula: 45,
  CultivoKeys.perejil: 42,
};

/// Servicio para gestionar ajustes y metas editables usando SharedPreferences
class AjustesService {
  static const String _prefsKeyPrefix = 'meta_diaria_';

  /// Carga las metas diarias guardadas
  /// Retorna un Map con las metas por cultivo
  /// Si no hay guardado, usa METAS_DIARIAS_POR_CULTIVO como fallback
  static Future<Map<String, int>> cargarMetas() async {
    final prefs = await SharedPreferences.getInstance();
    final metas = <String, int>{};

    for (final cultivoKey in CultivoKeys.todas) {
      final metaGuardada = prefs.getInt('$_prefsKeyPrefix$cultivoKey');
      if (metaGuardada != null) {
        metas[cultivoKey] = metaGuardada;
      } else {
        // Usar valor por defecto si no hay guardado
        metas[cultivoKey] = METAS_DIARIAS_POR_CULTIVO[cultivoKey] ?? 0;
      }
    }

    return metas;
  }

  /// Guarda la meta diaria para un cultivo específico
  static Future<void> guardarMeta(String cultivoKey, int metaDiaria) async {
    if (!CultivoKeys.todas.contains(cultivoKey)) {
      throw ArgumentError('Cultivo inválido: $cultivoKey');
    }

    if (metaDiaria < 0) {
      throw ArgumentError('La meta diaria debe ser mayor o igual a 0');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefsKeyPrefix$cultivoKey', metaDiaria);
  }

  /// Obtiene la meta efectiva para un cultivo
  /// Primero intenta cargar desde SharedPreferences, si no existe usa el valor por defecto
  static Future<int> obtenerMetaEfectiva(String cultivoKey) async {
    final prefs = await SharedPreferences.getInstance();
    final metaGuardada = prefs.getInt('$_prefsKeyPrefix$cultivoKey');

    if (metaGuardada != null) {
      return metaGuardada;
    }

    // Fallback al valor por defecto
    return METAS_DIARIAS_POR_CULTIVO[cultivoKey] ?? 0;
  }
}
