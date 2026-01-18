import '../domain/motor_invernadero.dart';
import '../domain/etapa.dart';

enum DevScenario {
  normal,
  mermaAlta,
  cosechaParcial,
}

void seed(MotorInvernadero motor, {DevScenario scenario = DevScenario.normal}) {
  final ahora = DateTime.now();

  // Crear siembras
  motor.crearSiembra(
    loteId: 'lote_001',
    cultivoKey: 'lechuga',
    cantidad: 100,
    fecha: ahora.subtract(const Duration(days: 30)),
  );

  motor.crearSiembra(
    loteId: 'lote_002',
    cultivoKey: 'tomate',
    cantidad: 50,
    fecha: ahora.subtract(const Duration(days: 25)),
  );

  motor.crearSiembra(
    loteId: 'lote_003',
    cultivoKey: 'lechuga',
    cantidad: 75,
    fecha: ahora.subtract(const Duration(days: 20)),
  );

  // Traspasos
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

  motor.crearTraspaso(
    loteId: 'lote_002',
    etapaDestino: Etapa.bandeja_crianza,
    fecha: ahora.subtract(const Duration(days: 20)),
  );

  // Cosechas
  if (scenario != DevScenario.cosechaParcial) {
    motor.crearCosecha(
      loteId: 'lote_001',
      cantidad: 30,
      fecha: ahora.subtract(const Duration(days: 5)),
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
  } else {
    // Merma normal
    motor.crearMerma(
      loteId: 'lote_002',
      cantidad: 5,
      fecha: ahora.subtract(const Duration(days: 10)),
    );
  }
}

