import 'package:shared_preferences/shared_preferences.dart';
import '../domain/cultivos.dart';

/// Servicio para gestionar alertas de cobertura persistentes
/// Las alertas se muestran cuando cobertura == 🔴 (stock == 0)
/// y persisten hasta que se registre una siembra válida o la cobertura cambie
class AlertasCoberturaService {
  static const String _prefsKeyPrefix = 'alerta_cobertura_';

  /// Obtiene el estado de la alerta para un cultivo
  /// Retorna true si la alerta debe mostrarse
  static Future<bool> obtenerAlertaActiva(String cultivoKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefsKeyPrefix$cultivoKey') ?? false;
  }

  /// Activa la alerta para un cultivo (cuando cobertura == 🔴)
  static Future<void> activarAlerta(String cultivoKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefsKeyPrefix$cultivoKey', true);
  }

  /// Desactiva la alerta para un cultivo
  /// Se llama cuando se registra una siembra válida o la cobertura deja de ser 🔴
  static Future<void> desactivarAlerta(String cultivoKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefsKeyPrefix$cultivoKey', false);
  }

  /// Actualiza el estado de las alertas basándose en la cobertura actual
  /// Si cobertura == 🔴 (stock == 0), activa la alerta
  /// Si cobertura != 🔴, desactiva la alerta
  static Future<void> actualizarAlertasSegunCobertura(
    Map<String, String> coberturas,
  ) async {
    for (final cultivoKey in CultivoKeys.todas) {
      final cobertura = coberturas[cultivoKey] ?? '';
      if (cobertura == '🔴') {
        await activarAlerta(cultivoKey);
      } else {
        await desactivarAlerta(cultivoKey);
      }
    }
  }

  /// Obtiene todas las alertas activas
  static Future<Set<String>> obtenerAlertasActivas() async {
    final prefs = await SharedPreferences.getInstance();
    final alertasActivas = <String>{};
    
    for (final cultivoKey in CultivoKeys.todas) {
      final activa = prefs.getBool('$_prefsKeyPrefix$cultivoKey') ?? false;
      if (activa) {
        alertasActivas.add(cultivoKey);
      }
    }
    
    return alertasActivas;
  }
}

