import 'dart:io';
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

  // Stock final incluye todos los lotes (activos e inactivos) porque las plantas siguen existiendo
  // aunque el lote esté cerrado (inactivo)
  final stockFinal = motor.lotes.fold<int>(
    0,
    (suma, lote) => suma + lote.cantidadActual,
  );

  final totalCosechas = motor.movimientos
      .where((m) => m.tipo == TipoMovimiento.cosecha && !m.anulado)
      .fold<int>(0, (suma, m) => suma + (m.cantidad ?? 0));

  final totalMermas = motor.movimientos
      .where((m) => m.tipo == TipoMovimiento.merma && !m.anulado)
      .fold<int>(0, (suma, m) => suma + (m.cantidad ?? 0));

  // Los cortes no reducen stock (las plantas siguen vivas), así que no se cuentan como salidas
  // Solo se registran para trazabilidad, pero no afectan el cálculo de consistencia

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

/// Valida que todas las keys de cultivos cumplan con el formato correcto
/// Formato esperado: solo minúsculas, números y guion bajo (^[a-z0-9_]+$)
/// Si alguna key no cumple, imprime "INVALID_CULTIVO_KEY: <valor>" y sale con código de error
void validarKeysCultivos(MotorInvernadero motor) {
  final regex = RegExp(r'^[a-z0-9_]+$');
  final keysInvalidas = <String>[];

  // Recorrer todos los lotes y validar sus cultivoKey
  for (final lote in motor.lotes) {
    if (!regex.hasMatch(lote.cultivoKey)) {
      keysInvalidas.add(lote.cultivoKey);
    }
  }

  // Si hay keys inválidas, imprimir y salir con error
  if (keysInvalidas.isNotEmpty) {
    for (final keyInvalida in keysInvalidas) {
      print('INVALID_CULTIVO_KEY: $keyInvalida');
    }
    exit(1);
  }
}
