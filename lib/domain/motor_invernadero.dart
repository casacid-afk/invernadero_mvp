import 'lote.dart';
import 'movimiento.dart';
import 'etapa.dart';
import 'cultivos.dart';

class MotorInvernadero {
  final List<Lote> _lotes = [];
  final List<Movimiento> _movimientos = [];

  List<Lote> get lotes => List.unmodifiable(_lotes);
  List<Movimiento> get movimientos => List.unmodifiable(_movimientos);

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
      final nuevaCantidadOrigen = loteActual.cantidadActual - cantidadATraspasar;
      
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
      anulado: true,
    );

    _movimientos[movimientoIndex] = movimientoAnulado;
  }

  int calcularStockPorCultivo(String cultivoKey) {
    return _lotes
        .where((lote) => lote.activo && lote.cultivoKey == cultivoKey)
        .fold(0, (suma, lote) => suma + lote.cantidadActual);
  }

  int calcularStockPorEtapa(Etapa etapa) {
    return _lotes
        .where((lote) => lote.activo && lote.etapaActual == etapa)
        .fold(0, (suma, lote) => suma + lote.cantidadActual);
  }

  void reset() {
    _lotes.clear();
    _movimientos.clear();
  }

  String _generarIdMovimiento() {
    return 'mov_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _generarIdLote() {
    return 'lote_${DateTime.now().millisecondsSinceEpoch}';
  }
}

