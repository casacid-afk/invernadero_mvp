import 'etapa.dart';

class Lote {
  final String id;
  final String cultivoKey;
  final int cantidadActual;
  final Etapa etapaActual;
  final DateTime fechaInicioEtapa;
  final DateTime fechaSiembra;
  final bool activo;
  final int cortesRealizados;

  Lote({
    required this.id,
    required this.cultivoKey,
    required this.cantidadActual,
    required this.etapaActual,
    required this.fechaInicioEtapa,
    required this.fechaSiembra,
    required this.activo,
    this.cortesRealizados = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cultivoKey': cultivoKey,
      'cantidadActual': cantidadActual,
      'etapaActual': etapaActual.name,
      'fechaInicioEtapa': fechaInicioEtapa.toIso8601String(),
      'fechaSiembra': fechaSiembra.toIso8601String(),
      'activo': activo,
      'cortesRealizados': cortesRealizados,
    };
  }

  static Lote fromMap(Map<String, dynamic> map) {
    return Lote(
      id: map['id'] as String,
      cultivoKey: map['cultivoKey'] as String,
      cantidadActual: map['cantidadActual'] as int,
      etapaActual: Etapa.values.firstWhere(
        (e) => e.name == map['etapaActual'],
      ),
      fechaInicioEtapa: DateTime.parse(map['fechaInicioEtapa'] as String),
      fechaSiembra: DateTime.parse(map['fechaSiembra'] as String),
      activo: map['activo'] as bool,
      cortesRealizados: map['cortesRealizados'] as int? ?? 0,
    );
  }
}


