class CierreJornada {
  final String id;
  final DateTime fecha;
  final int cantidadVentas;
  final int unidadesVendidas;
  final double totalDolares;

  CierreJornada({
    required this.id,
    required this.fecha,
    required this.cantidadVentas,
    required this.unidadesVendidas,
    required this.totalDolares,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fecha': fecha.toIso8601String(),
      'cantidadVentas': cantidadVentas,
      'unidadesVendidas': unidadesVendidas,
      'totalDolares': totalDolares,
    };
  }

  static CierreJornada fromMap(Map<String, dynamic> map) {
    return CierreJornada(
      id: map['id'] as String,
      fecha: DateTime.parse(map['fecha'] as String),
      cantidadVentas: map['cantidadVentas'] as int,
      unidadesVendidas: map['unidadesVendidas'] as int,
      totalDolares: map['totalDolares'] as double,
    );
  }
}
