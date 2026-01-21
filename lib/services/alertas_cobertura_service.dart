import 'package:shared_preferences/shared_preferences.dart';
import '../domain/cultivos.dart';

/// Servicio para gestionar alertas de cobertura persistentes
/// Las alertas se muestran cuando cobertura == 🔴 (stock == 0) o 🟡 (stock < meta)
/// y persisten hasta que la cobertura cambie
class AlertasCoberturaService {
  static const String _prefsKeyPrefix = 'alerta_cobertura_';

  /// Obtiene el estado de cobertura persistente para un cultivo
  /// Retorna el emoji de cobertura (🔴, 🟡, 🟢) o null si no hay estado guardado
  static Future<String?> obtenerEstadoCobertura(String cultivoKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefsKeyPrefix$cultivoKey');
  }

  /// Guarda el estado de cobertura para un cultivo
  static Future<void> guardarEstadoCobertura(
    String cultivoKey,
    String cobertura,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefsKeyPrefix$cultivoKey', cobertura);
  }

  /// Limpia el estado de cobertura para un cultivo
  static Future<void> limpiarEstadoCobertura(String cultivoKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefsKeyPrefix$cultivoKey');
  }

  /// Actualiza el estado de las alertas basándose en la cobertura actual
  /// Guarda el estado persistente para 🔴 y 🟡
  /// Limpia el estado para 🟢
  static Future<void> actualizarAlertasSegunCobertura(
    Map<String, String> coberturas,
  ) async {
    for (final cultivoKey in CultivoKeys.todas) {
      final cobertura = coberturas[cultivoKey] ?? '🟢';
      if (cobertura == '🔴' || cobertura == '🟡') {
        await guardarEstadoCobertura(cultivoKey, cobertura);
      } else {
        await limpiarEstadoCobertura(cultivoKey);
      }
    }
  }

  /// Obtiene todas las alertas activas (🔴 y 🟡)
  /// Retorna un mapa con cultivoKey -> cobertura persistente
  static Future<Map<String, String>> obtenerEstadosCobertura() async {
    final prefs = await SharedPreferences.getInstance();
    final estados = <String, String>{};

    for (final cultivoKey in CultivoKeys.todas) {
      final estado = prefs.getString('$_prefsKeyPrefix$cultivoKey');
      if (estado != null && (estado == '🔴' || estado == '🟡')) {
        estados[cultivoKey] = estado;
      }
    }

    return estados;
  }
}
