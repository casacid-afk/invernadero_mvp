import 'dart:io';
import '../lib/domain/motor_invernadero.dart';
import '../lib/domain/etapa.dart';
import '../lib/domain/cultivos.dart';
import '../lib/dev/dev_seed.dart';
import '../lib/dev/dev_validaciones.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    print('Uso: dart run tool/runner.dart <comando> [argumentos]');
    print('Comandos disponibles:');
    print('  seed                    - Ejecuta seed con escenario normal');
    print('  scenario <nombre>       - Ejecuta seed con escenario específico');
    exit(1);
  }

  final comando = args[0];

  switch (comando) {
    case 'seed':
      _ejecutarSeed();
      break;
    case 'scenario':
      if (args.length < 2) {
        print('Error: Debe especificar un nombre de escenario');
        print('Escenarios disponibles: normal, mermaAlta, cosechaParcial');
        exit(1);
      }
      _ejecutarScenario(args[1]);
      break;
    default:
      print('Error: Comando desconocido: $comando');
      exit(1);
  }
}

void _ejecutarSeed() {
  final motor = MotorInvernadero();
  motor.reset();
  seed(motor);
  
  try {
    assertConsistencia(motor);
    print('OK - Seed ejecutado correctamente');
    print('OK - Validaciones de consistencia');
  } catch (e) {
    print('ERROR - Validaciones:');
    print(e);
    exit(1);
  }
}

void _ejecutarScenario(String nombreEscenario) {
  DevScenario? scenario;
  
  switch (nombreEscenario.toLowerCase()) {
    case 'normal':
      scenario = DevScenario.normal;
      break;
    case 'mermaalta':
    case 'merma_alta':
      scenario = DevScenario.mermaAlta;
      break;
    case 'cosechaparcial':
    case 'cosecha_parcial':
      scenario = DevScenario.cosechaParcial;
      break;
    case 'smoke':
      // Escenario smoke: NO ejecuta seed, solo validaciones determinísticas
      final motorSmoke = MotorInvernadero();
      motorSmoke.reset();
      
      try {
        validarKeysCultivos(motorSmoke);
        _validarSiembraSmoke(motorSmoke);
        _validarTraspasoSmoke(motorSmoke);
        _validarCosechaSmoke(motorSmoke);
        assertConsistencia(motorSmoke);
        print('OK - Smoke ejecutado correctamente');
        print('OK - Validaciones de consistencia');
        return;
      } catch (e) {
        print('ERROR - Validaciones:');
        print(e);
        exit(1);
      }
    default:
      print('Error: Escenario desconocido: $nombreEscenario');
      print('Escenarios disponibles: normal, mermaAlta, cosechaParcial, smoke');
      exit(1);
  }

  final motor = MotorInvernadero();
  motor.reset();
  seed(motor, scenario: scenario!);
  
  try {
    assertConsistencia(motor);
    if (nombreEscenario == 'smoke') {
      print('OK - Smoke ejecutado correctamente');
    } else {
      print('OK - Escenario "$nombreEscenario" ejecutado correctamente');
    }
    print('OK - Validaciones de consistencia');
  } catch (e) {
    print('ERROR - Validaciones:');
    print(e);
    exit(1);
  }
}

/// Valida el flujo de siembra en el smoke test
void _validarSiembraSmoke(MotorInvernadero motor) {
  // Caso 1: Siembra válida → stock correcto en semillero
  final stockInicialSemillero = motor.calcularStockPorEtapa(Etapa.semillero_calefaccionado);
  final stockInicialLechuga = motor.calcularStockPorCultivo(CultivoKeys.lechuga);
  
  final fechaSiembra = DateTime.now();
  motor.nuevaSiembra(
    cultivoKey: CultivoKeys.lechuga,
    cantidad: 50,
    fecha: fechaSiembra,
  );
  
  final stockFinalSemillero = motor.calcularStockPorEtapa(Etapa.semillero_calefaccionado);
  final stockFinalLechuga = motor.calcularStockPorCultivo(CultivoKeys.lechuga);
  
  // Verificar que el stock se incrementó correctamente
  if (stockFinalSemillero != stockInicialSemillero + 50) {
    print('ERROR - Stock en semillero incorrecto después de siembra');
    print('  Esperado: ${stockInicialSemillero + 50}, Obtenido: $stockFinalSemillero');
    exit(1);
  }
  
  if (stockFinalLechuga != stockInicialLechuga + 50) {
    print('ERROR - Stock de lechuga incorrecto después de siembra');
    print('  Esperado: ${stockInicialLechuga + 50}, Obtenido: $stockFinalLechuga');
    exit(1);
  }
  
  // Verificar que el lote se creó en etapa semillero
  final lotesEnSemillero = motor.lotes.where(
    (lote) => lote.etapaActual == Etapa.semillero_calefaccionado && 
              lote.cultivoKey == CultivoKeys.lechuga &&
              lote.cantidadActual == 50 &&
              lote.activo == true
  );
  
  if (lotesEnSemillero.isEmpty) {
    print('ERROR - No se encontró lote creado en semillero después de siembra');
    exit(1);
  }
  
  // Caso 2: Siembra inválida con cultivoKey inválida → debe fallar
  try {
    motor.nuevaSiembra(
      cultivoKey: 'Rúcula', // Key inválida con tilde
      cantidad: 30,
      fecha: fechaSiembra,
    );
    print('ERROR - La siembra con cultivoKey inválida debería haber fallado');
    exit(1);
  } catch (e) {
    // Esperado: debe lanzar ArgumentError
    if (e.toString().contains('cultivoKey inválida')) {
      // OK - La validación funcionó
    } else {
      print('ERROR - Se esperaba ArgumentError por cultivoKey inválida, pero se obtuvo: $e');
      exit(1);
    }
  }
  
  // Caso 3: Siembra inválida con cantidad <= 0 → debe fallar
  try {
    motor.nuevaSiembra(
      cultivoKey: CultivoKeys.lechuga,
      cantidad: 0, // Cantidad inválida
      fecha: fechaSiembra,
    );
    print('ERROR - La siembra con cantidad <= 0 debería haber fallado');
    exit(1);
  } catch (e) {
    // Esperado: debe lanzar ArgumentError
    if (e.toString().contains('cantidad debe ser mayor a 0')) {
      // OK - La validación funcionó
    } else {
      print('ERROR - Se esperaba ArgumentError por cantidad inválida, pero se obtuvo: $e');
      exit(1);
    }
  }
}

/// Valida el flujo de traspaso en el smoke test
void _validarTraspasoSmoke(MotorInvernadero motor) {
  // Caso 1: Traspaso válido parcial
  // Siembro 100 → traspaso 60 a crianza → stock: semillero 40, crianza 60
  final fechaTraspaso = DateTime.now();
  
  // Crear un lote nuevo para la prueba usando lechuga
  // Obtener stock inicial antes de crear el nuevo lote
  final stockInicialSemilleroAntes = motor.calcularStockPorEtapa(Etapa.semillero_calefaccionado);
  final stockInicialCrianzaAntes = motor.calcularStockPorEtapa(Etapa.bandeja_crianza);
  final stockInicialLechugaAntes = motor.calcularStockPorCultivo(CultivoKeys.lechuga);
  
  final movimientoSiembra = motor.nuevaSiembra(
    cultivoKey: CultivoKeys.lechuga,
    cantidad: 100,
    fecha: fechaTraspaso,
  );
  final lotePruebaId = movimientoSiembra.loteId;
  
  // Verificar que el lote existe y tiene las características correctas
  final lotePrueba = motor.obtenerLote(lotePruebaId);
  if (lotePrueba.cantidadActual != 100 || 
      lotePrueba.etapaActual != Etapa.semillero_calefaccionado ||
      !lotePrueba.activo) {
    print('ERROR - El lote de prueba no tiene las características esperadas');
    print('  Esperado: 100 unidades en semillero, activo');
    print('  Obtenido: ${lotePrueba.cantidadActual} unidades en ${lotePrueba.etapaActual.name}, activo: ${lotePrueba.activo}');
    exit(1);
  }
  
  // Obtener stock inicial después de crear el lote
  final stockInicialSemillero = motor.calcularStockPorEtapa(Etapa.semillero_calefaccionado);
  final stockInicialCrianza = motor.calcularStockPorEtapa(Etapa.bandeja_crianza);
  final stockInicialLechuga = motor.calcularStockPorCultivo(CultivoKeys.lechuga);
  
  // Verificar que el stock aumentó correctamente
  if (stockInicialSemillero != stockInicialSemilleroAntes + 100 ||
      stockInicialLechuga != stockInicialLechugaAntes + 100) {
    print('ERROR - Stock no aumentó correctamente después de crear el lote');
    print('  Esperado: semillero=${stockInicialSemilleroAntes + 100}, lechuga=${stockInicialLechugaAntes + 100}');
    print('  Obtenido: semillero=$stockInicialSemillero, lechuga=$stockInicialLechuga');
    exit(1);
  }
  
  // Traspasar 60 unidades a crianza
  motor.traspasarLote(
    loteId: lotePruebaId,
    etapaDestino: Etapa.bandeja_crianza,
    cantidad: 60,
    fecha: fechaTraspaso,
  );
  
  // Verificar stocks después del traspaso
  final stockFinalSemillero = motor.calcularStockPorEtapa(Etapa.semillero_calefaccionado);
  final stockFinalCrianza = motor.calcularStockPorEtapa(Etapa.bandeja_crianza);
  final stockFinalLechuga = motor.calcularStockPorCultivo(CultivoKeys.lechuga);
  
  // Verificar que el stock en semillero bajó en 60
  if (stockFinalSemillero != stockInicialSemillero - 60) {
    print('ERROR - Stock en semillero incorrecto después de traspaso');
    print('  Esperado: ${stockInicialSemillero - 60}, Obtenido: $stockFinalSemillero');
    exit(1);
  }
  
  // Verificar que el stock en crianza subió en 60
  if (stockFinalCrianza != stockInicialCrianza + 60) {
    print('ERROR - Stock en crianza incorrecto después de traspaso');
    print('  Esperado: ${stockInicialCrianza + 60}, Obtenido: $stockFinalCrianza');
    exit(1);
  }
  
  // Verificar que el stock total por cultivo no cambió
  if (stockFinalLechuga != stockInicialLechuga) {
    print('ERROR - Stock total de lechuga cambió después de traspaso');
    print('  Esperado: $stockInicialLechuga, Obtenido: $stockFinalLechuga');
    exit(1);
  }
  
  // Verificar que se creó un sublote en crianza con 60 unidades
  final sublotesEnCrianza = motor.lotes.where(
    (lote) => lote.etapaActual == Etapa.bandeja_crianza &&
              lote.cultivoKey == CultivoKeys.lechuga &&
              lote.cantidadActual == 60 &&
              lote.activo == true
  ).toList();
  
  if (sublotesEnCrianza.isEmpty) {
    print('ERROR - No se encontró sublote creado en crianza después de traspaso parcial');
    exit(1);
  }
  
  // Verificar que el lote origen quedó con 40 unidades en semillero
  final loteOrigen = motor.obtenerLote(lotePruebaId);
  if (loteOrigen.cantidadActual != 40 || 
      loteOrigen.etapaActual != Etapa.semillero_calefaccionado ||
      !loteOrigen.activo) {
    print('ERROR - Lote origen no quedó con cantidad/etapa correcta después de traspaso parcial');
    print('  Esperado: 40 unidades en semillero, activo');
    print('  Obtenido: ${loteOrigen.cantidadActual} unidades en ${loteOrigen.etapaActual.name}, activo: ${loteOrigen.activo}');
    exit(1);
  }
  
  // Caso 2: Traspaso inválido - intentar traspasar más de lo disponible
  // Crear un nuevo lote específico para este test
  final movimientoSiembra2 = motor.nuevaSiembra(
    cultivoKey: CultivoKeys.lechuga,
    cantidad: 50,
    fecha: fechaTraspaso,
  );
  final lotePrueba2Id = movimientoSiembra2.loteId;
  
  try {
    motor.traspasarLote(
      loteId: lotePrueba2Id,
      etapaDestino: Etapa.bandeja_crianza,
      cantidad: 999, // Más de lo disponible (solo hay 50)
      fecha: fechaTraspaso,
    );
    print('ERROR - El traspaso con cantidad mayor a disponible debería haber fallado');
    exit(1);
  } catch (e) {
    // Esperado: debe lanzar ArgumentError
    if (e.toString().contains('No se puede traspasar') || 
        e.toString().contains('disponibles')) {
      // OK - La validación funcionó
    } else {
      print('ERROR - Se esperaba ArgumentError por cantidad excedida, pero se obtuvo: $e');
      exit(1);
    }
  }
  
  // Caso 3: Traspaso inválido - orden de etapas incorrecto
  // Usar el sublote que acabamos de crear (debe estar en crianza)
  final subloteEnCrianza = sublotesEnCrianza.first;
  
  // Verificar que el sublote está realmente en crianza antes de intentar traspasarlo
  if (subloteEnCrianza.etapaActual != Etapa.bandeja_crianza) {
    print('ERROR - El sublote no está en crianza como se esperaba');
    print('  Etapa actual: ${subloteEnCrianza.etapaActual.name}');
    exit(1);
  }
  
  try {
    motor.traspasarLote(
      loteId: subloteEnCrianza.id,
      etapaDestino: Etapa.semillero_calefaccionado, // Retroceder no permitido
      cantidad: 30,
      fecha: fechaTraspaso,
    );
    print('ERROR - El traspaso retrocediendo etapas debería haber fallado');
    exit(1);
  } catch (e) {
    // Esperado: debe lanzar ArgumentError
    if (e.toString().contains('No se puede traspasar') || 
        e.toString().contains('avanzar')) {
      // OK - La validación funcionó
    } else {
      print('ERROR - Se esperaba ArgumentError por orden de etapas inválido, pero se obtuvo: $e');
      exit(1);
    }
  }
}

/// Valida el flujo de cosecha en el smoke test
void _validarCosechaSmoke(MotorInvernadero motor) {
  final fechaCosecha = DateTime.now();
  
  // Caso 1: Cosecha de lechuga (modo A)
  // Si hay 100 en final, cosechar 30 -> final 70
  final movimientoSiembraLechuga = motor.nuevaSiembra(
    cultivoKey: CultivoKeys.lechuga,
    cantidad: 100,
    fecha: fechaCosecha,
  );
  final loteLechugaId = movimientoSiembraLechuga.loteId;
  
  // Traspasar a etapa final (traspaso total sin cantidad = mueve todo)
  motor.crearTraspaso(
    loteId: loteLechugaId,
    etapaDestino: Etapa.bancada_inicial,
    fecha: fechaCosecha,
  );
  
  // Obtener el lote en bancada_inicial y traspasarlo a final (traspaso total)
  final loteEnInicial = motor.lotes.firstWhere(
    (lote) => lote.cultivoKey == CultivoKeys.lechuga && 
              lote.etapaActual == Etapa.bancada_inicial &&
              lote.activo == true,
  );
  motor.crearTraspaso(
    loteId: loteEnInicial.id,
    etapaDestino: Etapa.bancada_final,
    fecha: fechaCosecha,
  );
  
  // Obtener el lote en etapa final usando el ID del lote que traspasamos
  // Después del traspaso total, el lote mantiene su ID pero cambia de etapa
  final loteEnFinal = motor.obtenerLote(loteLechugaId);
  if (loteEnFinal.etapaActual != Etapa.bancada_final ||
      loteEnFinal.cantidadActual != 100 ||
      !loteEnFinal.activo) {
    print('ERROR - El lote no está en bancada_final con las características esperadas');
    print('  Esperado: bancada_final, 100 unidades, activo');
    print('  Obtenido: ${loteEnFinal.etapaActual.name}, ${loteEnFinal.cantidadActual} unidades, activo: ${loteEnFinal.activo}');
    exit(1);
  }
  
  // Obtener stock inicial en etapa final (puede haber otros lotes del seed)
  final stockInicialFinal = motor.calcularStockPorEtapa(Etapa.bancada_final);
  final stockInicialLechuga = motor.calcularStockPorCultivo(CultivoKeys.lechuga);
  
  // Cosechar 30 unidades del lote específico
  motor.crearCosecha(
    loteId: loteEnFinal.id,
    cantidad: 30,
    fecha: fechaCosecha,
  );
  
  // Verificar stocks después de la cosecha
  final stockFinalFinal = motor.calcularStockPorEtapa(Etapa.bancada_final);
  final stockFinalLechuga = motor.calcularStockPorCultivo(CultivoKeys.lechuga);
  
  // Verificar que el stock en etapa final bajó en 30
  if (stockFinalFinal != stockInicialFinal - 30) {
    print('ERROR - Stock en etapa final incorrecto después de cosecha');
    print('  Esperado: ${stockInicialFinal - 30}, Obtenido: $stockFinalFinal');
    exit(1);
  }
  
  // Verificar que el stock de lechuga bajó en 30
  if (stockFinalLechuga != stockInicialLechuga - 30) {
    print('ERROR - Stock de lechuga incorrecto después de cosecha');
    print('  Esperado: ${stockInicialLechuga - 30}, Obtenido: $stockFinalLechuga');
    exit(1);
  }
  
  // Verificar que el lote quedó con 70 unidades
  final lotesActualizados = motor.lotes.where(
    (lote) => lote.id == loteEnFinal.id,
  );
  
  if (lotesActualizados.isEmpty) {
    print('ERROR - No se encontró lote después de la cosecha');
    exit(1);
  }
  
  final loteActualizado = lotesActualizados.first;
  if (loteActualizado.cantidadActual != 70) {
    print('ERROR - Lote no quedó con cantidad correcta después de cosecha');
    print('  Esperado: 70, Obtenido: ${loteActualizado.cantidadActual}');
    exit(1);
  }
  
  // Caso 2: Cortes de rucula (modo B)
  // Registrar 4 cortes OK; 5to corte debe fallar
  final movimientoSiembraRucula = motor.nuevaSiembra(
    cultivoKey: CultivoKeys.rucula,
    cantidad: 50,
    fecha: fechaCosecha,
  );
  final loteRuculaId = movimientoSiembraRucula.loteId;
  
  // Traspasar a etapa final (traspaso total)
  motor.crearTraspaso(
    loteId: loteRuculaId,
    etapaDestino: Etapa.bandeja_crianza,
    fecha: fechaCosecha,
  );
  
  final lotesEnCrianza = motor.lotes.where(
    (lote) => lote.cultivoKey == CultivoKeys.rucula && 
              lote.etapaActual == Etapa.bandeja_crianza &&
              lote.activo == true &&
              lote.cantidadActual == 50,
  );
  
  if (lotesEnCrianza.isEmpty) {
    print('ERROR - No se encontró lote de rucula en crianza después del traspaso');
    exit(1);
  }
  
  final loteEnCrianza = lotesEnCrianza.first;
  motor.crearTraspaso(
    loteId: loteEnCrianza.id,
    etapaDestino: Etapa.bancada_inicial,
    fecha: fechaCosecha,
  );
  
  final lotesEnInicialRucula = motor.lotes.where(
    (lote) => lote.cultivoKey == CultivoKeys.rucula && 
              lote.etapaActual == Etapa.bancada_inicial &&
              lote.activo == true &&
              lote.cantidadActual == 50,
  );
  
  if (lotesEnInicialRucula.isEmpty) {
    print('ERROR - No se encontró lote de rucula en bancada_inicial después del traspaso');
    exit(1);
  }
  
  final loteEnInicialRucula = lotesEnInicialRucula.first;
  motor.crearTraspaso(
    loteId: loteEnInicialRucula.id,
    etapaDestino: Etapa.bancada_final,
    fecha: fechaCosecha,
  );
  
  final lotesEnFinalRucula = motor.lotes.where(
    (lote) => lote.cultivoKey == CultivoKeys.rucula && 
              lote.etapaActual == Etapa.bancada_final &&
              lote.activo == true &&
              lote.cantidadActual == 50,
  );
  
  if (lotesEnFinalRucula.isEmpty) {
    print('ERROR - No se encontró lote de rucula en bancada_final después del traspaso');
    exit(1);
  }
  
  final loteEnFinalRucula = lotesEnFinalRucula.first;
  
  // Obtener stock inicial de rucula antes de los cortes (puede haber otros lotes del seed)
  final stockInicialRucula = motor.calcularStockPorCultivo(CultivoKeys.rucula);
  
  // Registrar 4 cortes (debe funcionar)
  for (int i = 1; i <= 4; i++) {
    motor.registrarCorte(
      loteId: loteEnFinalRucula.id,
      cantidad: 10,
      fecha: fechaCosecha,
    );
    
    // Verificar que el contador se incrementó
    final loteActual = motor.obtenerLote(loteEnFinalRucula.id);
    if (loteActual.cortesRealizados != i) {
      print('ERROR - Contador de cortes incorrecto después del corte $i');
      print('  Esperado: $i, Obtenido: ${loteActual.cortesRealizados}');
      exit(1);
    }
    
    // Verificar que el stock no cambió (las plantas siguen vivas) hasta el 4to corte
    // Después del 4to corte, el lote se cierra automáticamente
    final stockRucula = motor.calcularStockPorCultivo(CultivoKeys.rucula);
    if (i < 4) {
      // Los primeros 3 cortes no deben cambiar el stock
      if (stockRucula != stockInicialRucula) {
        print('ERROR - Stock de rucula cambió después del corte $i');
        print('  Esperado: $stockInicialRucula, Obtenido: $stockRucula');
        exit(1);
      }
    } else {
      // Después del 4to corte, el lote se cierra y el stock baja
      if (stockRucula != stockInicialRucula - 50) {
        print('ERROR - Stock de rucula incorrecto después del 4to corte (lote cerrado)');
        print('  Esperado: ${stockInicialRucula - 50}, Obtenido: $stockRucula');
        exit(1);
      }
    }
  }
  
  // Verificar que el lote se cerró después de 4 cortes
  final lotesDespues4Cortes = motor.lotes.where(
    (lote) => lote.id == loteEnFinalRucula.id,
  );
  
  if (lotesDespues4Cortes.isEmpty) {
    print('ERROR - No se encontró lote después de 4 cortes');
    exit(1);
  }
  
  final loteDespues4Cortes = lotesDespues4Cortes.first;
  if (loteDespues4Cortes.activo) {
    print('ERROR - Lote debería haberse cerrado después de 4 cortes');
    exit(1);
  }
  
  // Intentar 5to corte (debe fallar porque el lote está inactivo después del 4to corte)
  try {
    motor.registrarCorte(
      loteId: loteEnFinalRucula.id,
      cantidad: 10,
      fecha: fechaCosecha,
    );
    print('ERROR - El 5to corte debería haber fallado (lote inactivo o máximo de cortes alcanzado)');
    exit(1);
  } catch (e) {
    // Esperado: debe lanzar StateError (lote inactivo) o ArgumentError (máximo de cortes)
    if (e.toString().contains('inactivo') || 
        e.toString().contains('máximo') || 
        e.toString().contains('cortes')) {
      // OK - La validación funcionó
    } else {
      print('ERROR - Se esperaba error por lote inactivo o máximo de cortes, pero se obtuvo: $e');
      exit(1);
    }
  }
  
  // Verificar que el lote se cerró después del intento fallido (debe seguir con 4 cortes)
  final lotesFinales = motor.lotes.where(
    (lote) => lote.id == loteEnFinalRucula.id,
  );
  
  if (lotesFinales.isEmpty) {
    print('ERROR - No se encontró lote después del intento fallido de corte');
    exit(1);
  }
  
  final loteFinal = lotesFinales.first;
  if (loteFinal.cortesRealizados != 4) {
    print('ERROR - Contador de cortes incorrecto después del intento fallido');
    print('  Esperado: 4, Obtenido: ${loteFinal.cortesRealizados}');
    exit(1);
  }
}

