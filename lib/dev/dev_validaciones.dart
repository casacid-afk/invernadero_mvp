import '../domain/motor_invernadero.dart';
import '../domain/movimiento.dart';
import '../domain/etapa.dart';

void assertConsistencia(MotorInvernadero motor) {
  final errores = <String>[];

  // Validación 1: Ningún stock < 0
  for (final lote in motor.lotes) {
    if (lote.cantidadActual < 0) {
      errores.add(
        'Lote ${lote.id} tiene stock negativo: ${lote.cantidadActual}',
      );
    }
  }

  // Validación 2: Suma stock por cultivo == suma stock por etapa
  final stockPorCultivo = motor.lotes
      .where((lote) => lote.activo)
      .fold<int>(0, (suma, lote) => suma + lote.cantidadActual);

  final stockPorEtapa = Etapa.values.fold<int>(
    0,
    (suma, etapa) => suma + motor.calcularStockPorEtapa(etapa),
  );

  if (stockPorCultivo != stockPorEtapa) {
    errores.add(
      'Inconsistencia: Stock por cultivo ($stockPorCultivo) != Stock por etapa ($stockPorEtapa)',
    );
  }

  // Validación 3: Total inicial == stock final + cosechas + mermas
  final totalInicial = motor.movimientos
      .where((m) => m.tipo == TipoMovimiento.siembra && !m.anulado)
      .fold<int>(0, (suma, m) => suma + (m.cantidad ?? 0));

  final stockFinal = motor.lotes
      .where((lote) => lote.activo)
      .fold<int>(0, (suma, lote) => suma + lote.cantidadActual);

  final totalCosechas = motor.movimientos
      .where((m) => m.tipo == TipoMovimiento.cosecha && !m.anulado)
      .fold<int>(0, (suma, m) => suma + (m.cantidad ?? 0));

  final totalMermas = motor.movimientos
      .where((m) => m.tipo == TipoMovimiento.merma && !m.anulado)
      .fold<int>(0, (suma, m) => suma + (m.cantidad ?? 0));

  final totalSalidas = stockFinal + totalCosechas + totalMermas;

  if (totalInicial != totalSalidas) {
    errores.add(
      'Inconsistencia: Total inicial ($totalInicial) != Stock final ($stockFinal) + Cosechas ($totalCosechas) + Mermas ($totalMermas) = $totalSalidas',
    );
  }

  // Si hay errores, lanzar AssertionError
  if (errores.isNotEmpty) {
    throw AssertionError(
      'VALIDACIÓN DE CONSISTENCIA FALLIDA:\n${errores.join('\n')}',
    );
  }
}

