import 'package:flutter/material.dart';

import '../../domain/motor_invernadero.dart';
import '../../domain/movimiento.dart';
import '../../domain/lote.dart';
import '../../domain/etapa.dart';
import '../../domain/cultivos.dart';

enum FiltroSiembras { hoy, dias7, todo }

class SiembrasListaScreen extends StatefulWidget {
  final MotorInvernadero motor;

  const SiembrasListaScreen({super.key, required this.motor});

  @override
  State<SiembrasListaScreen> createState() => _SiembrasListaScreenState();
}

class _SiembrasListaScreenState extends State<SiembrasListaScreen> {
  FiltroSiembras _filtroSeleccionado = FiltroSiembras.todo;

  String _formatearEtapa(Etapa etapa) {
    return etapa.name
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  String _obtenerCultivoLabel(Lote? lote) {
    if (lote == null) return 'Cultivo desconocido';
    return CultivoLabels.obtenerLabel(lote.cultivoKey);
  }

  /// Formatea fecha en formato dd-MM (simple, sin año)
  String _formatearFechaSimple(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia-$mes';
  }

  /// Filtra las siembras según el filtro seleccionado
  List<Movimiento> _obtenerSiembrasFiltradas() {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final manana = hoy.add(const Duration(days: 1));
    final hace7Dias = hoy.subtract(const Duration(days: 6));

    // Base: todas las siembras no anuladas
    var siembras = widget.motor.movimientos
        .where((m) => m.tipo == TipoMovimiento.siembra && !m.anulado)
        .toList();

    // Aplicar filtro por fecha según selección
    switch (_filtroSeleccionado) {
      case FiltroSiembras.hoy:
        siembras = siembras
            .where((m) =>
                m.fecha.isAfter(hoy.subtract(const Duration(milliseconds: 1))) &&
                m.fecha.isBefore(manana))
            .toList();
        break;
      case FiltroSiembras.dias7:
        siembras = siembras
            .where((m) =>
                m.fecha.isAfter(hace7Dias.subtract(const Duration(milliseconds: 1))) &&
                m.fecha.isBefore(manana))
            .toList();
        break;
      case FiltroSiembras.todo:
        // Sin filtro adicional
        break;
    }

    // Ordenar por fecha descendente (más nuevo arriba)
    siembras.sort((a, b) => b.fecha.compareTo(a.fecha));

    return siembras;
  }

  @override
  Widget build(BuildContext context) {
    final siembras = _obtenerSiembrasFiltradas();

    return Scaffold(
      appBar: AppBar(title: const Text('Siembras')),
      body: Column(
        children: [
          // Filtro rápido
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SegmentedButton<FiltroSiembras>(
              segments: const [
                ButtonSegment<FiltroSiembras>(
                  value: FiltroSiembras.hoy,
                  label: Text('HOY'),
                ),
                ButtonSegment<FiltroSiembras>(
                  value: FiltroSiembras.dias7,
                  label: Text('7D'),
                ),
                ButtonSegment<FiltroSiembras>(
                  value: FiltroSiembras.todo,
                  label: Text('TODO'),
                ),
              ],
              selected: {_filtroSeleccionado},
              onSelectionChanged: (Set<FiltroSiembras> nuevaSeleccion) {
                setState(() {
                  _filtroSeleccionado = nuevaSeleccion.first;
                });
              },
            ),
          ),
          // Lista de siembras
          Expanded(
            child: siembras.isEmpty
                ? const Center(child: Text('No hay siembras registradas'))
                : ListView.builder(
                    itemCount: siembras.length,
                    itemBuilder: (context, index) {
                      final movimiento = siembras[index];

                      Lote? lote;
                      try {
                        lote = widget.motor.lotes.firstWhere(
                          (l) => l.id == movimiento.loteId,
                        );
                      } catch (_) {
                        lote = null;
                      }

                      final fecha = _formatearFechaSimple(movimiento.fecha);
                      final cultivoLabel = _obtenerCultivoLabel(lote);
                      final cantidad = movimiento.cantidad ?? 0;
                      final etapa =
                          lote?.etapaActual ?? Etapa.semillero_calefaccionado;
                      final etapaLabel = _formatearEtapa(etapa);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  fecha,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  cultivoLabel,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  cantidad.toString(),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  etapaLabel,
                                  textAlign: TextAlign.end,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
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
