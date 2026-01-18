import 'lote.dart';
import 'movimiento.dart';
import 'etapa.dart';

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
    final lote = Lote(
      id: loteId,
      cultivoKey: cultivoKey,
      cantidadActual: cantidad,
      etapaActual: Etapa.semillero_calefaccionado,
      fechaInicioEtapa: fecha,
      fechaSiembra: fecha,
      activo: true,
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

  Movimiento crearTraspaso({
    required String loteId,
    required Etapa etapaDestino,
    required DateTime fecha,
  }) {
    final loteIndex = _lotes.indexWhere((l) => l.id == loteId);
    if (loteIndex == -1) {
      throw StateError('Lote no encontrado: $loteId');
    }

    final loteActual = _lotes[loteIndex];
    final etapaOrigen = loteActual.etapaActual;

    final loteActualizado = Lote(
      id: loteActual.id,
      cultivoKey: loteActual.cultivoKey,
      cantidadActual: loteActual.cantidadActual,
      etapaActual: etapaDestino,
      fechaInicioEtapa: fecha,
      fechaSiembra: loteActual.fechaSiembra,
      activo: loteActual.activo,
    );

    _lotes[loteIndex] = loteActualizado;

    final movimiento = Movimiento(
      id: _generarIdMovimiento(),
      loteId: loteId,
      tipo: TipoMovimiento.traspaso,
      fecha: fecha,
      etapaOrigen: etapaOrigen,
      etapaDestino: etapaDestino,
      anulado: false,
    );

    _movimientos.add(movimiento);
    return movimiento;
  }

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
}

