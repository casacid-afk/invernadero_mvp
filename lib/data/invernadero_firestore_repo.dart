import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class InvernaderoFirestoreRepo {
  InvernaderoFirestoreRepo({
    FirebaseFirestore? firestore,
    this.envId = 'dev_local',
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String envId;

  DocumentReference<Map<String, dynamic>> get _envDoc =>
      _firestore.collection('apps').doc('invernadero_mvp').collection('envs').doc(envId);

  CollectionReference<Map<String, dynamic>> get ventas =>
      _envDoc.collection('ventas');

  CollectionReference<Map<String, dynamic>> get movimientos =>
      _envDoc.collection('movimientos');

  CollectionReference<Map<String, dynamic>> get lotes =>
      _envDoc.collection('lotes');

  CollectionReference<Map<String, dynamic>> get meta =>
      _envDoc.collection('meta');

  /// Persiste un documento de venta en Firestore. Añade createdAt y origen.
  Future<void> guardarVenta(Map<String, dynamic> data) async {
    final doc = Map<String, dynamic>.from(data)
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['origen'] = 'mvp';
    await ventas.add(doc);
  }

  /// Persiste un movimiento en Firestore. Añade createdAt y origen.
  Future<void> guardarMovimiento(Map<String, dynamic> data) async {
    final doc = Map<String, dynamic>.from(data)
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['origen'] = 'mvp';
    await movimientos.add(doc);
  }

  /// Lee el respaldo de stock actual desde meta/stock_actual. Devuelve null si no existe o falla.
  Future<Map<String, dynamic>?> obtenerStockActual() async {
    try {
      final snapshot = await meta.doc('stock_actual').get();
      if (snapshot.exists && snapshot.data() != null) {
        return snapshot.data();
      }
      return null;
    } catch (e) {
      debugPrint('Firestore obtenerStockActual: $e');
      return null;
    }
  }

  /// Actualiza la proyección de stock por cultivo en meta/stock_actual (merge).
  Future<void> guardarStockActualPorCultivo(String cultivoKey, int disponible) async {
    await meta.doc('stock_actual').set({
      'cultivos': {
        cultivoKey: {
          'disponible': disponible,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      },
      'origen': 'mvp',
    }, SetOptions(merge: true));
  }
}
