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

  CollectionReference<Map<String, dynamic>> get gastos =>
      _envDoc.collection('gastos');

  CollectionReference<Map<String, dynamic>> get clientes =>
      _envDoc.collection('clientes');

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

  /// Persiste un gasto en Firestore. Añade createdAt y origen.
  Future<void> guardarGasto(Map<String, dynamic> data) async {
    final doc = Map<String, dynamic>.from(data)
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['origen'] = 'mvp';
    await gastos.add(doc);
  }

  /// Persiste un cliente en Firestore. Añade createdAt y origen.
  Future<void> guardarCliente(Map<String, dynamic> data) async {
    final doc = Map<String, dynamic>.from(data)
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['origen'] = 'mvp';
    await clientes.add(doc);
  }

  /// Valor de stock disponible desde el respaldo para un cultivo, o null si no hay.
  static int? stockDisponibleDesdeRespaldo(Map<String, dynamic>? respaldo, String cultivoKey) {
    if (respaldo == null) return null;
    final cultivos = respaldo['cultivos'];
    if (cultivos is! Map) return null;
    final c = cultivos[cultivoKey];
    if (c is! Map) return null;
    final d = c['disponible'];
    if (d is int) return d;
    if (d is num) return d.toInt();
    return null;
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

  /// Actualiza la proyección de stock por cultivo en meta/stock_actual,
  /// guardando tanto disponible (vendible) como enProceso (total activo).
  Future<void> guardarStockActualDetallePorCultivo({
    required String cultivoKey,
    required int disponible,
    required int enProceso,
  }) async {
    await meta.doc('stock_actual').set({
      'cultivos': {
        cultivoKey: {
          'disponible': disponible,
          'enProceso': enProceso,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      },
      'origen': 'mvp',
    }, SetOptions(merge: true));
  }

  /// Lee todos los movimientos desde apps/invernadero_mvp/envs/{envId}/movimientos.
  /// Intenta ordenar por fecha ascendente en la consulta; si no es posible por compatibilidad de datos,
  /// ordena en memoria usando el campo 'fecha'.
  Future<List<Map<String, dynamic>>> obtenerMovimientos() async {
    try {
      final snapshot = await movimientos.orderBy('fecha').get();
      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      debugPrint('Firestore obtenerMovimientos (orderBy fecha) falló, ordenando en memoria: $e');
      final snapshot = await movimientos.get();
      final items = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      items.sort((a, b) {
        final fa = a['fecha'];
        final fb = b['fecha'];
        if (fa == null && fb == null) return 0;
        if (fa == null) return -1;
        if (fb == null) return 1;
        // Asumimos que 'fecha' es un String ISO8601 como se guarda actualmente.
        try {
          final da = DateTime.tryParse(fa.toString());
          final db = DateTime.tryParse(fb.toString());
          if (da == null && db == null) return 0;
          if (da == null) return -1;
          if (db == null) return 1;
          return da.compareTo(db);
        } catch (_) {
          return 0;
        }
      });

      return items;
    }
  }

  /// Lee las ventas en el rango [desde, hasta], inclusive.
  /// Intenta filtrar/ordenar por fecha en la consulta; si no es posible por compatibilidad de datos,
  /// filtra y ordena en memoria usando el campo 'fecha' (ISO8601 String).
  Future<List<Map<String, dynamic>>> obtenerVentasEnRango({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final desdeIso = desde.toIso8601String();
    final hastaIso = hasta.toIso8601String();
    try {
      final snapshot = await ventas
          .where('fecha', isGreaterThanOrEqualTo: desdeIso)
          .where('fecha', isLessThanOrEqualTo: hastaIso)
          .orderBy('fecha')
          .get();
      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      debugPrint(
          'Firestore obtenerVentasEnRango (filtro por fecha) falló, filtrando en memoria: $e');
      final snapshot = await ventas.get();
      final items = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .where((data) {
            final raw = data['fecha'];
            if (raw == null) return false;
            final d = DateTime.tryParse(raw.toString());
            if (d == null) return false;
            return !d.isBefore(desde) && !d.isAfter(hasta);
          }).toList();

      items.sort((a, b) {
        final fa = a['fecha'];
        final fb = b['fecha'];
        if (fa == null && fb == null) return 0;
        if (fa == null) return -1;
        if (fb == null) return 1;
        try {
          final da = DateTime.tryParse(fa.toString());
          final db = DateTime.tryParse(fb.toString());
          if (da == null && db == null) return 0;
          if (da == null) return -1;
          if (db == null) return 1;
          return da.compareTo(db);
        } catch (_) {
          return 0;
        }
      });

      return items;
    }
  }

  /// Lee los gastos en el rango [desde, hasta], inclusive.
  /// Intenta filtrar/ordenar por fecha en la consulta; si no es posible por compatibilidad de datos,
  /// filtra y ordena en memoria usando el campo 'fecha' (ISO8601 String).
  Future<List<Map<String, dynamic>>> obtenerGastosEnRango({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final desdeIso = desde.toIso8601String();
    final hastaIso = hasta.toIso8601String();
    try {
      final snapshot = await gastos
          .where('fecha', isGreaterThanOrEqualTo: desdeIso)
          .where('fecha', isLessThanOrEqualTo: hastaIso)
          .orderBy('fecha')
          .get();
      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      debugPrint(
          'Firestore obtenerGastosEnRango (filtro por fecha) falló, filtrando en memoria: $e');
      final snapshot = await gastos.get();
      final items = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .where((data) {
            final raw = data['fecha'];
            if (raw == null) return false;
            final d = DateTime.tryParse(raw.toString());
            if (d == null) return false;
            return !d.isBefore(desde) && !d.isAfter(hasta);
          }).toList();

      items.sort((a, b) {
        final fa = a['fecha'];
        final fb = b['fecha'];
        if (fa == null && fb == null) return 0;
        if (fa == null) return -1;
        if (fb == null) return 1;
        try {
          final da = DateTime.tryParse(fa.toString());
          final db = DateTime.tryParse(fb.toString());
          if (da == null && db == null) return 0;
          if (da == null) return -1;
          if (db == null) return 1;
          return da.compareTo(db);
        } catch (_) {
          return 0;
        }
      });

      return items;
    }
  }

  /// Obtiene todas las ventas a crédito abiertas (medioPago == 'credito',
  /// estadoCobro == 'abierta' y clienteId no vacío).
  Future<List<Map<String, dynamic>>> obtenerVentasCreditoAbiertas() async {
    try {
      final snapshot = await ventas
          .where('medioPago', isEqualTo: 'credito')
          .where('estadoCobro', isEqualTo: 'abierta')
          .where('clienteId', isNull: false)
          .get();
      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .where((data) {
            final clienteId = data['clienteId'];
            return clienteId != null &&
                clienteId.toString().isNotEmpty;
          }).toList();
    } catch (e) {
      debugPrint(
          'Firestore obtenerVentasCreditoAbiertas (filtros por credito/abierta/clienteId) falló, filtrando en memoria: $e');
      final snapshot = await ventas.get();
      final items = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .where((data) {
            final medioPago = data['medioPago']?.toString();
            final estadoCobro = data['estadoCobro']?.toString();
            final clienteId = data['clienteId'];
            return medioPago == 'credito' &&
                estadoCobro == 'abierta' &&
                clienteId != null &&
                clienteId.toString().isNotEmpty;
          }).toList();

      return items;
    }
  }

  /// Obtiene todos los clientes, ordenados por nombre ascendente.
  Future<List<Map<String, dynamic>>> obtenerClientes() async {
    try {
      final snapshot = await clientes.orderBy('nombre').get();
      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      debugPrint(
          'Firestore obtenerClientes (orderBy nombre) falló, ordenando en memoria: $e');
      final snapshot = await clientes.get();
      final items = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      items.sort((a, b) {
        final na = a['nombre']?.toString() ?? '';
        final nb = b['nombre']?.toString() ?? '';
        return na.toLowerCase().compareTo(nb.toLowerCase());
      });

      return items;
    }
  }

  /// Obtiene solo los clientes activos, ordenados por nombre ascendente.
  Future<List<Map<String, dynamic>>> obtenerClientesActivos() async {
    try {
      final snapshot = await clientes
          .where('activo', isEqualTo: true)
          .orderBy('nombre')
          .get();
      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      debugPrint(
          'Firestore obtenerClientesActivos (filtro por activo/nombre) falló, filtrando en memoria: $e');
      final todos = await obtenerClientes();
      return todos.where((c) {
        final activo = c['activo'];
        return activo == true;
      }).toList();
    }
  }
}
