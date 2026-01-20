import 'etapa.dart';

enum TipoMovimiento {
  siembra,
  traspaso,
  cosecha,
  corte,
  merma,
  venta,
}

enum MedioPago {
  efectivo,
  transferencia,
  credito,
}

class Movimiento {
  final String id;
  final String loteId;
  final TipoMovimiento tipo;
  final DateTime fecha;
  final int? cantidad;
  final Etapa? etapaOrigen;
  final Etapa? etapaDestino;
  final int? numeroCorte; // Solo para tipo corte
  final double? precioUnitario; // Solo para tipo venta
  final MedioPago? medioPago; // Solo para tipo venta
  final bool anulado;

  Movimiento({
    required this.id,
    required this.loteId,
    required this.tipo,
    required this.fecha,
    this.cantidad,
    this.etapaOrigen,
    this.etapaDestino,
    this.numeroCorte,
    this.precioUnitario,
    this.medioPago,
    required this.anulado,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'loteId': loteId,
      'tipo': tipo.name,
      'fecha': fecha.toIso8601String(),
      'cantidad': cantidad,
      'etapaOrigen': etapaOrigen?.name,
      'etapaDestino': etapaDestino?.name,
      'numeroCorte': numeroCorte,
      'precioUnitario': precioUnitario,
      'medioPago': medioPago?.name,
      'anulado': anulado,
    };
  }

  static Movimiento fromMap(Map<String, dynamic> map) {
    return Movimiento(
      id: map['id'] as String,
      loteId: map['loteId'] as String,
      tipo: TipoMovimiento.values.firstWhere(
        (e) => e.name == map['tipo'],
      ),
      fecha: DateTime.parse(map['fecha'] as String),
      cantidad: map['cantidad'] as int?,
      etapaOrigen: map['etapaOrigen'] != null
          ? Etapa.values.firstWhere(
              (e) => e.name == map['etapaOrigen'],
            )
          : null,
      etapaDestino: map['etapaDestino'] != null
          ? Etapa.values.firstWhere(
              (e) => e.name == map['etapaDestino'],
            )
          : null,
      numeroCorte: map['numeroCorte'] as int?,
      precioUnitario: map['precioUnitario'] as double?,
      medioPago: map['medioPago'] != null
          ? MedioPago.values.firstWhere(
              (e) => e.name == map['medioPago'],
            )
          : null,
      anulado: map['anulado'] as bool,
    );
  }
}


