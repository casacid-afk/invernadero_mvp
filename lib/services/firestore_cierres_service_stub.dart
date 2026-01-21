import '../domain/cierre_jornada.dart';

/// Stub de FirestoreCierresService para uso en scripts de línea de comandos
/// que no tienen acceso a Flutter/Firebase.
///
/// **Propósito:**
/// Este stub implementa la misma interfaz que `FirestoreCierresService` pero
/// sin dependencias de Flutter/Firebase, permitiendo que `motor_invernadero.dart`
/// funcione en scripts CLI sin errores de compilación.
///
/// **Compatibilidad:**
/// - Misma firma de constructor que la implementación real
/// - Mismos métodos públicos con la misma firma
/// - Métodos privados incluidos para mantener estructura (aunque no se usen)
/// - Comportamiento: métodos no hacen nada o retornan valores por defecto
///
/// **Uso:**
/// - Automáticamente seleccionado por `firestore_cierres_service_export.dart`
///   cuando se ejecuta en CLI o cuando Flutter no está disponible
class FirestoreCierresService {
  /// Campo privado compatible con la implementación real
  /// No se usa en el stub, pero mantiene la misma estructura de clase
  // ignore: unused_field
  final Object? _firestore;

  /// ID del invernadero (igual que en la implementación real)
  final String invernaderoId;

  /// Constructor compatible con la implementación real de FirestoreCierresService
  ///
  /// [firestore] se acepta para compatibilidad pero se ignora en el stub
  /// [invernaderoId] es requerido y se almacena (igual que en la implementación real)
  FirestoreCierresService({
    Object?
    firestore, // Compatible con FirebaseFirestore? de la implementación real
    required this.invernaderoId,
  }) : _firestore = null; // Stub: siempre null, no se usa

  /// Métodos privados compatibles con la implementación real
  /// Estos métodos no se usan en el stub pero mantienen la misma estructura
  // ignore: unused_element
  String _getCollectionPath() {
    return 'invernaderos/$invernaderoId/cierres_jornada';
  }

  // ignore: unused_element
  String _getDocumentId(DateTime fecha) {
    final fechaInicio = DateTime(fecha.year, fecha.month, fecha.day);
    return 'fecha_${fechaInicio.year}${fechaInicio.month.toString().padLeft(2, '0')}${fechaInicio.day.toString().padLeft(2, '0')}';
  }

  /// Guarda un cierre de jornada (stub - no hace nada)
  /// Compatible con la implementación real que guarda en Firestore
  Future<void> guardarCierre(CierreJornada cierre) async {
    // Stub: no hace nada en scripts de línea de comandos
    // En la implementación real, esto guarda en Firestore
  }

  /// Carga todos los cierres (stub - retorna lista vacía)
  /// Compatible con la implementación real que carga desde Firestore
  Future<List<CierreJornada>> cargarCierres() async {
    // Stub: retorna lista vacía en scripts de línea de comandos
    // En la implementación real, esto carga desde Firestore
    return [];
  }

  /// Verifica si existe un cierre (stub - retorna false)
  /// Compatible con la implementación real que verifica en Firestore
  Future<bool> existeCierre(DateTime fecha) async {
    // Stub: retorna false en scripts de línea de comandos
    // En la implementación real, esto verifica en Firestore
    return false;
  }
}
