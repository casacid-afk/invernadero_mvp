import '../domain/motor_invernadero.dart';
import '../domain/etapa.dart';
import '../domain/cultivos.dart';

enum DevScenario { normal, mermaAlta, cosechaParcial }

void seed(MotorInvernadero motor, {DevScenario scenario = DevScenario.normal}) {
  final ahora = DateTime.now();

  // Crear siembras para los 5 cultivos del invernadero
  // Lechuga - lote_001
  motor.crearSiembra(
    loteId: 'lote_001',
    cultivoKey: CultivoKeys.lechuga,
    cantidad: 100,
    fecha: ahora.subtract(const Duration(days: 30)),
  );

  // Cilantro - lote_002
  motor.crearSiembra(
    loteId: 'lote_002',
    cultivoKey: CultivoKeys.cilantro,
    cantidad: 80,
    fecha: ahora.subtract(const Duration(days: 25)),
  );

  // Acelga - lote_003
  motor.crearSiembra(
    loteId: 'lote_003',
    cultivoKey: CultivoKeys.acelga,
    cantidad: 75,
    fecha: ahora.subtract(const Duration(days: 20)),
  );

  // Rucula - lote_004
  motor.crearSiembra(
    loteId: 'lote_004',
    cultivoKey: CultivoKeys.rucula,
    cantidad: 90,
    fecha: ahora.subtract(const Duration(days: 18)),
  );

  // Perejil - lote_005
  motor.crearSiembra(
    loteId: 'lote_005',
    cultivoKey: CultivoKeys.perejil,
    cantidad: 85,
    fecha: ahora.subtract(const Duration(days: 15)),
  );

  // Traspasos
  // Lechuga: semillero -> crianza -> bancada inicial
  motor.crearTraspaso(
    loteId: 'lote_001',
    etapaDestino: Etapa.bandeja_crianza,
    fecha: ahora.subtract(const Duration(days: 25)),
  );

  motor.crearTraspaso(
    loteId: 'lote_001',
    etapaDestino: Etapa.bancada_inicial,
    fecha: ahora.subtract(const Duration(days: 15)),
  );

  // Cilantro: semillero -> crianza
  motor.crearTraspaso(
    loteId: 'lote_002',
    etapaDestino: Etapa.bandeja_crianza,
    fecha: ahora.subtract(const Duration(days: 20)),
  );

  // Acelga: semillero -> crianza -> bancada inicial
  motor.crearTraspaso(
    loteId: 'lote_003',
    etapaDestino: Etapa.bandeja_crianza,
    fecha: ahora.subtract(const Duration(days: 15)),
  );

  motor.crearTraspaso(
    loteId: 'lote_003',
    etapaDestino: Etapa.bancada_inicial,
    fecha: ahora.subtract(const Duration(days: 10)),
  );

  // Rucula: semillero -> crianza
  motor.crearTraspaso(
    loteId: 'lote_004',
    etapaDestino: Etapa.bandeja_crianza,
    fecha: ahora.subtract(const Duration(days: 13)),
  );

  // Perejil: semillero -> crianza
  motor.crearTraspaso(
    loteId: 'lote_005',
    etapaDestino: Etapa.bandeja_crianza,
    fecha: ahora.subtract(const Duration(days: 10)),
  );

  // Traspasar lotes a etapa final antes de cosechar
  motor.crearTraspaso(
    loteId: 'lote_001',
    etapaDestino: Etapa.bancada_final,
    fecha: ahora.subtract(const Duration(days: 10)),
  );
  motor.crearTraspaso(
    loteId: 'lote_003',
    etapaDestino: Etapa.bancada_final,
    fecha: ahora.subtract(const Duration(days: 8)),
  );

  // Cosechas (solo lechuga desde etapa final)
  if (scenario != DevScenario.cosechaParcial) {
    motor.crearCosecha(
      loteId: 'lote_001',
      cantidad: 30,
      fecha: ahora.subtract(const Duration(days: 5)),
    );
    // Acelga usa cortes, no cosecha final
    // skipValidacionMadurez=true para permitir cortes en seed sin validar madurez
    motor.registrarCorte(
      loteId: 'lote_003',
      cantidad: 25,
      fecha: ahora.subtract(const Duration(days: 3)),
      skipValidacionMadurez: true,
    );
  } else {
    // Cosecha parcial: solo cosechar una pequeña cantidad
    motor.crearCosecha(
      loteId: 'lote_001',
      cantidad: 10,
      fecha: ahora.subtract(const Duration(days: 5)),
    );
  }

  // Mermas
  if (scenario == DevScenario.mermaAlta) {
    // Merma alta: múltiples mermas y mayores cantidades
    motor.crearMerma(
      loteId: 'lote_001',
      cantidad: 20,
      fecha: ahora.subtract(const Duration(days: 12)),
    );
    motor.crearMerma(
      loteId: 'lote_002',
      cantidad: 15,
      fecha: ahora.subtract(const Duration(days: 10)),
    );
    motor.crearMerma(
      loteId: 'lote_003',
      cantidad: 10,
      fecha: ahora.subtract(const Duration(days: 8)),
    );
    motor.crearMerma(
      loteId: 'lote_004',
      cantidad: 12,
      fecha: ahora.subtract(const Duration(days: 6)),
    );
    motor.crearMerma(
      loteId: 'lote_005',
      cantidad: 8,
      fecha: ahora.subtract(const Duration(days: 4)),
    );
  } else {
    // Merma normal
    motor.crearMerma(
      loteId: 'lote_002',
      cantidad: 5,
      fecha: ahora.subtract(const Duration(days: 10)),
    );
    motor.crearMerma(
      loteId: 'lote_004',
      cantidad: 7,
      fecha: ahora.subtract(const Duration(days: 8)),
    );
  }
}
