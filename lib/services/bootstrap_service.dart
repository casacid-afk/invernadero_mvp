import 'package:shared_preferences/shared_preferences.dart';
import 'app_repository.dart';

class BootstrapService {
  static const String _seededKey = 'seeded_v1';

  static Future<void> ensureSeeded(AppRepository repo) async {
    final prefs = await SharedPreferences.getInstance();

    // Si ya está seeded, retornar inmediatamente
    if (prefs.getBool(_seededKey) == true) {
      return;
    }

    // Ejecutar seed
    repo.seed();

    // Guardar flag de seeded
    await prefs.setBool(_seededKey, true);
  }

  /// Carga cierres de jornada desde Firestore al motor
  static Future<void> cargarCierres(AppRepository repo) async {
    await repo.motor.cargarCierresDesdeFirestore();
  }
}
