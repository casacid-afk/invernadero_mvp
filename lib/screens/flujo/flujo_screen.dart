import 'package:flutter/material.dart';

import '../../domain/motor_invernadero.dart';
import '../../domain/movimiento.dart';
import '../../domain/cultivos.dart';

enum VentanaFlujo { dias7, dias30 }

class FlujoScreen extends StatefulWidget {
  final MotorInvernadero motor;

  const FlujoScreen({super.key, required this.motor});

  @override
  State<FlujoScreen> createState() => _FlujoScreenState();
}

class _FlujoScreenState extends State<FlujoScreen> {
  VentanaFlujo _ventanaSeleccionada = VentanaFlujo.dias7;

  /// Obtiene el cultivoKey desde un movimiento
  String? _obtenerCultivoKey(Movimiento movimiento) {
    try {
      final lote = widget.motor.lotes.firstWhere(
        (l) => l.id == movimiento.loteId,
      );
      return lote.cultivoKey;
    } catch (_) {
      return null;
    }
  }

  /// Calcula los totales por cultivo y tipo de movimiento
  Map<String, Map<TipoMovimiento, int>> _calcularTotales() {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final manana = hoy.add(const Duration(days: 1));
    final diasAtras = _ventanaSeleccionada == VentanaFlujo.dias7 ? 6 : 29;
    final fechaInicio = hoy.subtract(Duration(days: diasAtras));

    // Inicializar estructura para todos los cultivos
    final totales = <String, Map<TipoMovimiento, int>>{};
    for (final cultivoKey in CultivoKeys.todas) {
      totales[cultivoKey] = {
        TipoMovimiento.siembra: 0,
        TipoMovimiento.traspaso: 0,
        TipoMovimiento.venta: 0,
      };
    }

    // Filtrar movimientos por ventana y tipo
    final movimientosFiltrados = widget.motor.movimientos.where((m) =>
        !m.anulado &&
        (m.tipo == TipoMovimiento.siembra ||
            m.tipo == TipoMovimiento.traspaso ||
            m.tipo == TipoMovimiento.venta) &&
        m.fecha.isAfter(
          fechaInicio.subtract(const Duration(milliseconds: 1)),
        ) &&
        m.fecha.isBefore(manana));

    // Agrupar y sumar cantidades
    for (final movimiento in movimientosFiltrados) {
      final cultivoKey = _obtenerCultivoKey(movimiento);
      if (cultivoKey == null || !CultivoKeys.todas.contains(cultivoKey)) {
        continue;
      }

      final cantidad = movimiento.cantidad ?? 0;
      if (cantidad > 0) {
        totales[cultivoKey]![movimiento.tipo] =
            (totales[cultivoKey]![movimiento.tipo] ?? 0) + cantidad;
      }
    }

    return totales;
  }

  @override
  Widget build(BuildContext context) {
    final totales = _calcularTotales();

    return Scaffold(
      appBar: AppBar(title: const Text('Flujo')),
      body: Column(
        children: [
          // Selector de ventana
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SegmentedButton<VentanaFlujo>(
              segments: const [
                ButtonSegment<VentanaFlujo>(
                  value: VentanaFlujo.dias7,
                  label: Text('7D'),
                ),
                ButtonSegment<VentanaFlujo>(
                  value: VentanaFlujo.dias30,
                  label: Text('30D'),
                ),
              ],
              selected: {_ventanaSeleccionada},
              onSelectionChanged: (Set<VentanaFlujo> nuevaSeleccion) {
                setState(() {
                  _ventanaSeleccionada = nuevaSeleccion.first;
                });
              },
            ),
          ),
          // Lista por cultivo
          Expanded(
            child: ListView.builder(
              itemCount: CultivoKeys.todas.length,
              itemBuilder: (context, index) {
                final cultivoKey = CultivoKeys.todas[index];
                final cultivoLabel = CultivoLabels.obtenerLabel(cultivoKey);
                final datos = totales[cultivoKey]!;

                final siembras = datos[TipoMovimiento.siembra] ?? 0;
                final traspasos = datos[TipoMovimiento.traspaso] ?? 0;
                final ventas = datos[TipoMovimiento.venta] ?? 0;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cultivoLabel,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Siembras: $siembras',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              'Traspasos: $traspasos',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              'Ventas: $ventas',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

