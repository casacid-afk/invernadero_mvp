import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/cierre_jornada.dart';

class FirestoreCierresService {
  final FirebaseFirestore _firestore;
  final String invernaderoId;

  FirestoreCierresService({
    FirebaseFirestore? firestore,
    required this.invernaderoId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  String _getCollectionPath() {
    return 'invernaderos/$invernaderoId/cierres_jornada';
  }

  String _getDocumentId(DateTime fecha) {
    final fechaInicio = DateTime(fecha.year, fecha.month, fecha.day);
    return 'fecha_${fechaInicio.year}${fechaInicio.month.toString().padLeft(2, '0')}${fechaInicio.day.toString().padLeft(2, '0')}';
  }

  /// Guarda un cierre de jornada en Firestore
  Future<void> guardarCierre(CierreJornada cierre) async {
    try {
      final docId = _getDocumentId(cierre.fecha);
      await _firestore
          .collection(_getCollectionPath())
          .doc(docId)
          .set(cierre.toMap());
    } catch (e) {
      // Si falla, se mantiene en memoria (fallback)
      rethrow;
    }
  }

  /// Carga todos los cierres desde Firestore
  Future<List<CierreJornada>> cargarCierres() async {
    try {
      final snapshot = await _firestore.collection(_getCollectionPath()).get();
      
      return snapshot.docs
          .map((doc) => CierreJornada.fromMap(doc.data()))
          .toList();
    } catch (e) {
      // Si falla, retornar lista vacía (fallback a memoria)
      return [];
    }
  }

  /// Verifica si existe un cierre para una fecha específica
  Future<bool> existeCierre(DateTime fecha) async {
    try {
      final docId = _getDocumentId(fecha);
      final doc = await _firestore
          .collection(_getCollectionPath())
          .doc(docId)
          .get();
      return doc.exists;
    } catch (e) {
      // Si falla, retornar false (permitir intentar cerrar)
      return false;
    }
  }
}

