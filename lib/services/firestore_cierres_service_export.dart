// Exporta FirestoreCierresService según el entorno usando imports condicionales.
//
// **Estrategia de selección:**
// - **Flutter Web** (dart.library.html o dart.library.js disponible): 
//   usa la implementación real con Firebase
// - **Scripts CLI** (dart run): usa el stub sin dependencias de Flutter
// - **Flutter móvil/desktop**: usa el stub por defecto, pero `main.dart` 
//   importa directamente la implementación real, por lo que la app siempre usa Firebase
//
// **Comportamiento:**
// - El stub es el default y funciona en todos los entornos sin Flutter
// - En Flutter web, se usa automáticamente la implementación real
// - En Flutter móvil/desktop, aunque este archivo exporta el stub,
//   `main.dart` importa directamente `firestore_cierres_service.dart`,
//   por lo que la aplicación Flutter siempre usa Firebase cuando está disponible
//
// **Uso:**
// - Scripts CLI: `dart run tool/runner.dart seed` → usa stub
// - Flutter: `flutter pub run tool/runner.dart seed` → usa stub (pero app usa real)
// - App Flutter: siempre usa implementación real desde `main.dart`

// Import condicional robusto:
// 1. Por defecto: stub (funciona en CLI y como fallback)
// 2. Si dart.library.html disponible (Flutter web): implementación real
// 3. Si dart.library.js disponible (Flutter web alternativo): implementación real
export '../services/firestore_cierres_service_stub.dart'
    if (dart.library.html) '../services/firestore_cierres_service.dart'
    if (dart.library.js) '../services/firestore_cierres_service.dart';

