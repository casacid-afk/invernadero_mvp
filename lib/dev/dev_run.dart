import '../domain/motor_invernadero.dart';
import '../domain/etapa.dart';
import '../domain/cultivos.dart';
import 'dev_seed.dart';
import 'dev_validaciones.dart';

void main() {
  final motor = MotorInvernadero();

  print('=== Invernadero MVP - Datos de Prueba ===\n');

  // Cargar datos de prueba
  print('Cargando datos de prueba...');
  seed(motor);
  print('   ✓ ${motor.lotes.length} lotes creados');
  print('   ✓ ${motor.movimientos.length} movimientos registrados\n');

  // Validaciones de consistencia
  print('Validando consistencia...');
  try {
    assertConsistencia(motor);
    print('   ✓ Validación de consistencia exitosa\n');
  } catch (e) {
    print('   ✗ ERROR DE VALIDACIÓN:\n');
    print('   $e\n');
    rethrow;
  }

  // Mostrar estado de lotes
  print('5. Estado actual de lotes:');
  for (final lote in motor.lotes) {
    print('   - Lote ${lote.id} (${lote.cultivoKey}):');
    print('     Cantidad: ${lote.cantidadActual}');
    print('     Etapa: ${lote.etapaActual.name}');
    print('     Activo: ${lote.activo}');
    print('');
  }

  // Calcular stocks usando keys internas, mostrar labels bonitos
  print('6. Stock por cultivo:');
  print('   - ${CultivoLabels.obtenerLabel(CultivoKeys.lechuga)}: ${motor.calcularStockPorCultivo(CultivoKeys.lechuga)}');
  print('   - ${CultivoLabels.obtenerLabel(CultivoKeys.cilantro)}: ${motor.calcularStockPorCultivo(CultivoKeys.cilantro)}');
  print('   - ${CultivoLabels.obtenerLabel(CultivoKeys.acelga)}: ${motor.calcularStockPorCultivo(CultivoKeys.acelga)}');
  print('   - ${CultivoLabels.obtenerLabel(CultivoKeys.rucula)}: ${motor.calcularStockPorCultivo(CultivoKeys.rucula)}');
  print('   - ${CultivoLabels.obtenerLabel(CultivoKeys.perejil)}: ${motor.calcularStockPorCultivo(CultivoKeys.perejil)}');
  print('');

  print('7. Stock por etapa:');
  for (final etapa in Etapa.values) {
    final stock = motor.calcularStockPorEtapa(etapa);
    print('   - ${etapa.name}: $stock');
  }
  print('');

  // Mostrar movimientos
  print('8. Resumen de movimientos:');
  print('   Total: ${motor.movimientos.length}');
  print('   Anulados: ${motor.movimientos.where((m) => m.anulado).length}');
  print('');

  print('=== Fin de datos de prueba ===');
}

