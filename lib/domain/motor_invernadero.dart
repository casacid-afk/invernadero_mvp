import 'lote.dart';
import 'movimiento.dart';
import 'etapa.dart';
import 'cultivos.dart';
import 'cierre_jornada.dart';
// Import condicional: exporta la implementación correcta según el entorno
// - En Flutter: usa FirestoreCierresService real con Firebase
// - En scripts CLI: usa stub sin dependencias de Flutter
import '../services/firestore_cierres_service_export.dart';

class MotorInvernadero {
  final List<Lote> _lotes = [];
  final List<Movimiento> _movimientos = [];
  final List<CierreJornada> _cierresJornada = [];
  int _contadorId = 0;
  FirestoreCierresService? _firestoreService;

  List<Lote> get lotes => List.unmodifiable(_lotes);
  List<Movimiento> get movimientos => List.unmodifiable(_movimientos);
  List<CierreJornada> get cierresJornada => List.unmodifiable(_cierresJornada);

  /// Configura el servicio de Firestore para persistencia de cierres
  void configurarFirestore(FirestoreCierresService service) {
    _firestoreService = service;
  }

  /// Carga cierres desde Firestore al motor
  Future<void> cargarCierresDesdeFirestore() async {
    if (_firestoreService == null) return;

    try {
      final cierres = await _firestoreService!.cargarCierres();
      _cierresJornada.clear();
      _cierresJornada.addAll(cierres);
    } catch (e) {
      // Si falla, mantener cierres en memoria (fallback)
    }
  }

  Lote obtenerLote(String id) {
    return _lotes.firstWhere(
      (lote) => lote.id == id,
      orElse: () => throw StateError('Lote no encontrado: $id'),
    );
  }

  Movimiento crearSiembra({
    required String loteId,
    required String cultivoKey,
    required int cantidad,
    required DateTime fecha,
  }) {
    // Validar cantidad positiva
    if (cantidad <= 0) {
      throw ArgumentError('La cantidad debe ser mayor a 0');
    }

    // Validar cultivoKey con regex
    final regex = RegExp(r'^[a-z0-9_]+$');
    if (!regex.hasMatch(cultivoKey)) {
      throw ArgumentError(
        'cultivoKey inválida: "$cultivoKey". Debe cumplir con el formato: solo minúsculas, números y guion bajo',
      );
    }

    final lote = Lote(
      id: loteId,
      cultivoKey: cultivoKey,
      cantidadActual: cantidad,
      etapaActual: Etapa.semillero_calefaccionado,
      fechaInicioEtapa: fecha,
      fechaSiembra: fecha,
      activo: true,
      cortesRealizados: 0,
    );

    _lotes.add(lote);

    final movimiento = Movimiento(
      id: _generarIdMovimiento(),
      loteId: loteId,
      tipo: TipoMovimiento.siembra,
      fecha: fecha,
      cantidad: cantidad,
      anulado: false,
    );

    _movimientos.add(movimiento);
    return movimiento;
  }

  /// Crea una nueva siembra con generación automática de loteId
  /// Valida cultivoKey y cantidad antes de crear el lote
  Movimiento nuevaSiembra({
    required String cultivoKey,
    required int cantidad,
    required DateTime fecha,
  }) {
    final loteId = _generarIdLote();
    return crearSiembra(
      loteId: loteId,
      cultivoKey: cultivoKey,
      cantidad: cantidad,
      fecha: fecha,
    );
  }

  /// Valida que el orden de etapas sea lógico (solo avanzar hacia adelante)
  bool _esOrdenEtapasValido(Etapa origen, Etapa destino) {
    final ordenEtapas = Etapa.values;
    final indiceOrigen = ordenEtapas.indexOf(origen);
    final indiceDestino = ordenEtapas.indexOf(destino);

    // Solo permitir avanzar hacia adelante (destino > origen)
    return indiceDestino > indiceOrigen;
  }

  Movimiento crearTraspaso({
    required String loteId,
    required Etapa etapaDestino,
    required DateTime fecha,
    int? cantidad,
  }) {
    final loteIndex = _lotes.indexWhere((l) => l.id == loteId);
    if (loteIndex == -1) {
      throw StateError('Lote no encontrado: $loteId');
    }

    final loteActual = _lotes[loteIndex];
    final etapaOrigen = loteActual.etapaActual;

    // Validar orden lógico de etapas
    if (!_esOrdenEtapasValido(etapaOrigen, etapaDestino)) {
      throw ArgumentError(
        'No se puede traspasar de ${etapaOrigen.name} a ${etapaDestino.name}. Solo se permite avanzar hacia etapas posteriores.',
      );
    }

    // Si no se especifica cantidad, mover todo el lote
    final cantidadATraspasar = cantidad ?? loteActual.cantidadActual;

    // Validar cantidad positiva
    if (cantidadATraspasar <= 0) {
      throw ArgumentError('La cantidad a traspasar debe ser mayor a 0');
    }

    // Validar que no se traspase más de lo disponible
    if (cantidadATraspasar > loteActual.cantidadActual) {
      throw ArgumentError(
        'No se puede traspasar $cantidadATraspasar unidades. Solo hay ${loteActual.cantidadActual} disponibles en el lote.',
      );
    }

    // Validar que el lote esté activo
    if (!loteActual.activo) {
      throw StateError('No se puede traspasar un lote inactivo');
    }

    final esTraspasoTotal = cantidadATraspasar == loteActual.cantidadActual;

    if (esTraspasoTotal) {
      // Traspaso total: mover el lote completo
      final loteActualizado = Lote(
        id: loteActual.id,
        cultivoKey: loteActual.cultivoKey,
        cantidadActual: loteActual.cantidadActual,
        etapaActual: etapaDestino,
        fechaInicioEtapa: fecha,
        fechaSiembra: loteActual.fechaSiembra,
        activo: loteActual.activo,
        cortesRealizados: loteActual.cortesRealizados,
      );

      _lotes[loteIndex] = loteActualizado;
    } else {
      // Traspaso parcial: reducir cantidad del lote origen y crear sublote en destino
      final nuevaCantidadOrigen =
          loteActual.cantidadActual - cantidadATraspasar;

      // Actualizar lote origen
      final loteOrigenActualizado = Lote(
        id: loteActual.id,
        cultivoKey: loteActual.cultivoKey,
        cantidadActual: nuevaCantidadOrigen,
        etapaActual: etapaOrigen,
        fechaInicioEtapa: loteActual.fechaInicioEtapa,
        fechaSiembra: loteActual.fechaSiembra,
        activo: true,
        cortesRealizados: loteActual.cortesRealizados,
      );

      _lotes[loteIndex] = loteOrigenActualizado;

      // Crear sublote en etapa destino
      final subloteId = _generarIdLote();
      final sublote = Lote(
        id: subloteId,
        cultivoKey: loteActual.cultivoKey,
        cantidadActual: cantidadATraspasar,
        etapaActual: etapaDestino,
        fechaInicioEtapa: fecha,
        fechaSiembra: loteActual.fechaSiembra,
        activo: true,
        cortesRealizados: 0, // Sublote nuevo, sin cortes
      );

      _lotes.add(sublote);
    }

    // Registrar movimiento (usar loteId original para trazabilidad)
    final movimiento = Movimiento(
      id: _generarIdMovimiento(),
      loteId: loteId,
      tipo: TipoMovimiento.traspaso,
      fecha: fecha,
      cantidad: cantidadATraspasar,
      etapaOrigen: etapaOrigen,
      etapaDestino: etapaDestino,
      anulado: false,
    );

    _movimientos.add(movimiento);
    return movimiento;
  }

  /// Traspasa una cantidad específica de un lote a otra etapa
  /// Valida cantidad disponible, orden de etapas y crea sublote si es parcial
  Movimiento traspasarLote({
    required String loteId,
    required Etapa etapaDestino,
    required int cantidad,
    required DateTime fecha,
  }) {
    return crearTraspaso(
      loteId: loteId,
      etapaDestino: etapaDestino,
      fecha: fecha,
      cantidad: cantidad,
    );
  }

  /// Cosecha de lechuga (modo A): solo desde etapa final, reduce stock
  Movimiento crearCosecha({
    required String loteId,
    required int cantidad,
    required DateTime fecha,
  }) {
    final loteIndex = _lotes.indexWhere((l) => l.id == loteId);
    if (loteIndex == -1) {
      throw StateError('Lote no encontrado: $loteId');
    }

    final loteActual = _lotes[loteIndex];

    // Validar que el lote esté activo
    if (!loteActual.activo) {
      throw StateError('No se puede cosechar un lote inactivo');
    }

    // Validar que esté en etapa final
    if (loteActual.etapaActual != Etapa.bancada_final) {
      throw ArgumentError(
        'La cosecha solo se puede realizar desde la etapa final (bancada_final). El lote está en ${loteActual.etapaActual.name}',
      );
    }

    // Validar que sea lechuga (solo lechuga permite cosecha final)
    if (CultivoConfig.permiteCortes(loteActual.cultivoKey)) {
      throw ArgumentError(
        'El cultivo ${loteActual.cultivoKey} no permite cosecha final. Use registrarCorte() en su lugar.',
      );
    }

    // Validar cantidad positiva
    if (cantidad <= 0) {
      throw ArgumentError('La cantidad a cosechar debe ser mayor a 0');
    }

    // Validar que no se coseche más de lo disponible
    if (cantidad > loteActual.cantidadActual) {
      throw ArgumentError(
        'No se puede cosechar $cantidad unidades. Solo hay ${loteActual.cantidadActual} disponibles en el lote.',
      );
    }

    int nuevaCantidad = loteActual.cantidadActual - cantidad;
    if (nuevaCantidad <= 0) {
      nuevaCantidad = 0;
    }
    final nuevoActivo = nuevaCantidad > 0 ? loteActual.activo : false;

    final loteActualizado = Lote(
      id: loteActual.id,
      cultivoKey: loteActual.cultivoKey,
      cantidadActual: nuevaCantidad,
      etapaActual: loteActual.etapaActual,
      fechaInicioEtapa: loteActual.fechaInicioEtapa,
      fechaSiembra: loteActual.fechaSiembra,
      activo: nuevoActivo,
      cortesRealizados: loteActual.cortesRealizados,
    );

    _lotes[loteIndex] = loteActualizado;

    final movimiento = Movimiento(
      id: _generarIdMovimiento(),
      loteId: loteId,
      tipo: TipoMovimiento.cosecha,
      fecha: fecha,
      cantidad: cantidad,
      anulado: false,
    );

    _movimientos.add(movimiento);
    return movimiento;
  }

  /// Registra un corte de hierbas (modo B): solo desde etapa final, no reduce plantas
  Movimiento registrarCorte({
    required String loteId,
    required int cantidad,
    required DateTime fecha,
  }) {
    final loteIndex = _lotes.indexWhere((l) => l.id == loteId);
    if (loteIndex == -1) {
      throw StateError('Lote no encontrado: $loteId');
    }

    final loteActual = _lotes[loteIndex];

    // Validar que el lote esté activo
    if (!loteActual.activo) {
      throw StateError('No se puede registrar corte en un lote inactivo');
    }

    // Validar que esté en etapa final
    if (loteActual.etapaActual != Etapa.bancada_final) {
      throw ArgumentError(
        'Los cortes solo se pueden realizar desde la etapa final (bancada_final). El lote está en ${loteActual.etapaActual.name}',
      );
    }

    // Validar que el cultivo permita cortes
    if (!CultivoConfig.permiteCortes(loteActual.cultivoKey)) {
      throw ArgumentError(
        'El cultivo ${loteActual.cultivoKey} no permite cortes. Use crearCosecha() en su lugar.',
      );
    }

    // Validar cantidad positiva
    if (cantidad <= 0) {
      throw ArgumentError('La cantidad del corte debe ser mayor a 0');
    }

    // Validar máximo de cortes
    final maxCortes = CultivoConfig.obtenerMaxCortes(loteActual.cultivoKey);
    if (loteActual.cortesRealizados >= maxCortes) {
      throw ArgumentError(
        'Se ha alcanzado el máximo de $maxCortes cortes para este lote. El lote debe ser cerrado.',
      );
    }

    final nuevoNumeroCorte = loteActual.cortesRealizados + 1;
    final alcanzoMaxCortes = nuevoNumeroCorte >= maxCortes;

    // Actualizar lote: incrementar contador de cortes, cerrar si alcanzó el máximo
    final loteActualizado = Lote(
      id: loteActual.id,
      cultivoKey: loteActual.cultivoKey,
      cantidadActual: loteActual.cantidadActual, // No reduce plantas
      etapaActual: loteActual.etapaActual,
      fechaInicioEtapa: loteActual.fechaInicioEtapa,
      fechaSiembra: loteActual.fechaSiembra,
      activo: !alcanzoMaxCortes, // Cerrar si alcanzó el máximo
      cortesRealizados: nuevoNumeroCorte,
    );

    _lotes[loteIndex] = loteActualizado;

    // Registrar movimiento de corte
    final movimiento = Movimiento(
      id: _generarIdMovimiento(),
      loteId: loteId,
      tipo: TipoMovimiento.corte,
      fecha: fecha,
      cantidad: cantidad,
      numeroCorte: nuevoNumeroCorte,
      anulado: false,
    );

    _movimientos.add(movimiento);
    return movimiento;
  }

  Movimiento crearMerma({
    required String loteId,
    required int cantidad,
    required DateTime fecha,
  }) {
    final loteIndex = _lotes.indexWhere((l) => l.id == loteId);
    if (loteIndex == -1) {
      throw StateError('Lote no encontrado: $loteId');
    }

    final loteActual = _lotes[loteIndex];
    int nuevaCantidad = loteActual.cantidadActual - cantidad;
    if (nuevaCantidad <= 0) {
      nuevaCantidad = 0;
    }
    final nuevoActivo = nuevaCantidad > 0 ? loteActual.activo : false;

    final loteActualizado = Lote(
      id: loteActual.id,
      cultivoKey: loteActual.cultivoKey,
      cantidadActual: nuevaCantidad,
      etapaActual: loteActual.etapaActual,
      fechaInicioEtapa: loteActual.fechaInicioEtapa,
      fechaSiembra: loteActual.fechaSiembra,
      activo: nuevoActivo,
      cortesRealizados: loteActual.cortesRealizados,
    );

    _lotes[loteIndex] = loteActualizado;

    final movimiento = Movimiento(
      id: _generarIdMovimiento(),
      loteId: loteId,
      tipo: TipoMovimiento.merma,
      fecha: fecha,
      cantidad: cantidad,
      anulado: false,
    );

    _movimientos.add(movimiento);
    return movimiento;
  }

  /// Registra una venta de cultivo: reduce stock desde lotes disponibles en etapa final
  Movimiento registrarVenta({
    required String cultivoKey,
    required int cantidad,
    required double precioUnitario,
    required MedioPago medioPago,
    required DateTime fecha,
  }) {
    // Validar cantidad positiva
    if (cantidad <= 0) {
      throw ArgumentError('La cantidad a vender debe ser mayor a 0');
    }

    // Validar precio unitario positivo
    if (precioUnitario <= 0) {
      throw ArgumentError('El precio unitario debe ser mayor a 0');
    }

    // Validar cultivoKey
    if (!CultivoKeys.todas.contains(cultivoKey)) {
      throw ArgumentError('Cultivo inválido: $cultivoKey');
    }

    // Calcular stock disponible del cultivo solo en etapa final (bancada_final)
    final stockDisponible = calcularStockFinalPorCultivo(cultivoKey);

    // Validar que haya stock suficiente
    if (stockDisponible < cantidad) {
      throw StateError(
        'Stock insuficiente: disponible $stockDisponible, solicitado $cantidad (bancada_final)',
      );
    }

    // Obtener lotes activos del cultivo en etapa final, ordenados por fecha más antigua (FIFO)
    final lotesDisponibles =
        _lotes
            .where(
              (lote) =>
                  lote.activo &&
                  lote.cultivoKey == cultivoKey &&
                  lote.etapaActual == Etapa.bancada_final,
            )
            .toList()
          ..sort((a, b) => a.fechaInicioEtapa.compareTo(b.fechaInicioEtapa));

    if (lotesDisponibles.isEmpty) {
      throw StateError(
        'No hay lotes disponibles en etapa final para el cultivo $cultivoKey',
      );
    }

    // Reducir stock de lotes disponibles hasta cubrir la cantidad solicitada
    int cantidadRestante = cantidad;
    final lotesAfectados = <String>[];

    for (final lote in lotesDisponibles) {
      if (cantidadRestante <= 0) break;

      final loteIndex = _lotes.indexWhere((l) => l.id == lote.id);
      if (loteIndex == -1) continue;

      final loteActual = _lotes[loteIndex];
      final cantidadADescontar = cantidadRestante < loteActual.cantidadActual
          ? cantidadRestante
          : loteActual.cantidadActual;

      final nuevaCantidad = loteActual.cantidadActual - cantidadADescontar;
      final nuevoActivo = nuevaCantidad > 0 ? loteActual.activo : false;

      final loteActualizado = Lote(
        id: loteActual.id,
        cultivoKey: loteActual.cultivoKey,
        cantidadActual: nuevaCantidad,
        etapaActual: loteActual.etapaActual,
        fechaInicioEtapa: loteActual.fechaInicioEtapa,
        fechaSiembra: loteActual.fechaSiembra,
        activo: nuevoActivo,
        cortesRealizados: loteActual.cortesRealizados,
      );

      _lotes[loteIndex] = loteActualizado;
      lotesAfectados.add(loteActual.id);
      cantidadRestante -= cantidadADescontar;
    }

    // Registrar movimiento de venta usando el primer lote afectado como referencia
    final loteReferencia = lotesAfectados.isNotEmpty
        ? lotesAfectados.first
        : _lotes.firstWhere((l) => l.activo && l.cultivoKey == cultivoKey).id;

    final movimiento = Movimiento(
      id: _generarIdMovimiento(),
      loteId: loteReferencia,
      tipo: TipoMovimiento.venta,
      fecha: fecha,
      cantidad: cantidad,
      precioUnitario: precioUnitario,
      medioPago: medioPago,
      anulado: false,
    );

    _movimientos.add(movimiento);
    return movimiento;
  }

  void anularMovimiento(String movimientoId) {
    final movimientoIndex = _movimientos.indexWhere(
      (m) => m.id == movimientoId,
    );
    if (movimientoIndex == -1) {
      throw StateError('Movimiento no encontrado: $movimientoId');
    }

    final movimientoActual = _movimientos[movimientoIndex];
    final movimientoAnulado = Movimiento(
      id: movimientoActual.id,
      loteId: movimientoActual.loteId,
      tipo: movimientoActual.tipo,
      fecha: movimientoActual.fecha,
      cantidad: movimientoActual.cantidad,
      etapaOrigen: movimientoActual.etapaOrigen,
      etapaDestino: movimientoActual.etapaDestino,
      numeroCorte: movimientoActual.numeroCorte,
      precioUnitario: movimientoActual.precioUnitario,
      medioPago: movimientoActual.medioPago,
      anulado: true,
    );

    _movimientos[movimientoIndex] = movimientoAnulado;
  }

  /// Calcula el stock total por cultivo considerando todas las etapas
  int calcularStockPorCultivo(String cultivoKey) {
    return _lotes
        .where((lote) => lote.activo && lote.cultivoKey == cultivoKey)
        .fold(0, (suma, lote) => suma + lote.cantidadActual);
  }

  /// Calcula el stock disponible para venta por cultivo,
  /// considerando solo lotes activos en etapa final (bancada_final)
  int calcularStockFinalPorCultivo(String cultivoKey) {
    return _lotes
        .where(
          (lote) =>
              lote.activo &&
              lote.cultivoKey == cultivoKey &&
              lote.etapaActual == Etapa.bancada_final,
        )
        .fold(0, (suma, lote) => suma + lote.cantidadActual);
  }

  int calcularStockPorEtapa(Etapa etapa) {
    return _lotes
        .where((lote) => lote.activo && lote.etapaActual == etapa)
        .fold(0, (suma, lote) => suma + lote.cantidadActual);
  }

  /// Calcula la cobertura de un cultivo
  /// Retorna '🔴' si stock == 0, '🟡' si stock > 0 y < meta, '🟢' si stock >= meta
  /// Si meta es null, usa lógica simplificada: 🔴 = stock == 0, 🟢 = stock > 0
  String calcularCobertura(String cultivoKey, {int? meta}) {
    final stock = calcularStockPorCultivo(cultivoKey);
    if (stock == 0) {
      return '🔴';
    }
    if (meta != null && meta > 0) {
      if (stock < meta) {
        return '🟡';
      }
      return '🟢';
    }
    // Si no hay meta definida, usar lógica simplificada
    return '🟢';
  }

  void reset() {
    _lotes.clear();
    _movimientos.clear();
    _cierresJornada.clear();
    _contadorId = 0;
  }

  /// Cierra la jornada de una fecha específica guardando un snapshot de las ventas del día
  Future<CierreJornada> cerrarJornada({
    required DateTime fecha,
    required int cantidadVentas,
    required int unidadesVendidas,
    required double totalDolares,
  }) async {
    // Verificar si ya existe un cierre para esta fecha
    final fechaInicio = DateTime(fecha.year, fecha.month, fecha.day);
    final fechaFin = fechaInicio.add(const Duration(days: 1));

    final existeCierre = _cierresJornada.any(
      (cierre) =>
          cierre.fecha.isAfter(
            fechaInicio.subtract(const Duration(milliseconds: 1)),
          ) &&
          cierre.fecha.isBefore(fechaFin),
    );

    if (existeCierre) {
      throw StateError('Ya existe un cierre de jornada para esta fecha');
    }

    // Verificar en Firestore si está configurado
    if (_firestoreService != null) {
      final existeCierreFirestore = await _firestoreService!.existeCierre(
        fechaInicio,
      );
      if (existeCierreFirestore) {
        throw StateError('Ya existe un cierre de jornada para esta fecha');
      }
    }

    final cierre = CierreJornada(
      id: _generarIdCierre(),
      fecha: fechaInicio,
      cantidadVentas: cantidadVentas,
      unidadesVendidas: unidadesVendidas,
      totalDolares: totalDolares,
    );

    // Guardar en memoria
    _cierresJornada.add(cierre);

    // Guardar en Firestore si está configurado
    if (_firestoreService != null) {
      try {
        await _firestoreService!.guardarCierre(cierre);
      } catch (e) {
        // Si falla Firestore, el cierre queda en memoria (fallback)
      }
    }

    return cierre;
  }

  /// Cierra la jornada calculando automáticamente los valores del día
  Future<CierreJornada> cerrarJornadaAutomatico(DateTime fecha) async {
    final fechaInicio = DateTime(fecha.year, fecha.month, fecha.day);
    final fechaFin = fechaInicio.add(const Duration(days: 1));

    // Verificar si ya existe un cierre para esta fecha (en memoria y Firestore)
    final existeCierreMemoria = _cierresJornada.any(
      (cierre) =>
          cierre.fecha.isAfter(
            fechaInicio.subtract(const Duration(milliseconds: 1)),
          ) &&
          cierre.fecha.isBefore(fechaFin),
    );

    if (existeCierreMemoria) {
      throw StateError('Ya existe un cierre de jornada para esta fecha');
    }

    // Verificar en Firestore si está configurado
    if (_firestoreService != null) {
      final existeCierreFirestore = await _firestoreService!.existeCierre(
        fechaInicio,
      );
      if (existeCierreFirestore) {
        throw StateError('Ya existe un cierre de jornada para esta fecha');
      }
    }

    // Calcular valores del día
    final ventas = _movimientos.where((movimiento) {
      return movimiento.tipo == TipoMovimiento.venta &&
          !movimiento.anulado &&
          movimiento.fecha.isAfter(
            fechaInicio.subtract(const Duration(milliseconds: 1)),
          ) &&
          movimiento.fecha.isBefore(fechaFin);
    }).toList();

    final cantidadVentas = ventas.length;
    final unidadesVendidas = ventas.fold<int>(
      0,
      (suma, venta) => suma + (venta.cantidad ?? 0),
    );
    final totalDolares = ventas.fold<double>(
      0.0,
      (suma, venta) =>
          suma + ((venta.cantidad ?? 0) * (venta.precioUnitario ?? 0.0)),
    );

    final cierre = CierreJornada(
      id: _generarIdCierre(),
      fecha: fechaInicio,
      cantidadVentas: cantidadVentas,
      unidadesVendidas: unidadesVendidas,
      totalDolares: totalDolares,
    );

    // Guardar en memoria
    _cierresJornada.add(cierre);

    // Guardar en Firestore si está configurado
    if (_firestoreService != null) {
      try {
        await _firestoreService!.guardarCierre(cierre);
      } catch (e) {
        // Si falla Firestore, el cierre queda en memoria (fallback)
      }
    }

    return cierre;
  }

  String _generarIdMovimiento() {
    _contadorId++;
    return 'mov_${DateTime.now().millisecondsSinceEpoch}_$_contadorId';
  }

  String _generarIdLote() {
    _contadorId++;
    return 'lote_${DateTime.now().millisecondsSinceEpoch}_$_contadorId';
  }

  String _generarIdCierre() {
    _contadorId++;
    return 'cierre_${DateTime.now().millisecondsSinceEpoch}_$_contadorId';
  }
}
