import 'package:flutter/material.dart';

import '../../domain/motor_invernadero.dart';
import '../../domain/movimiento.dart';
import '../../domain/lote.dart';
import '../../domain/etapa.dart';
import '../../domain/cultivos.dart';
import 'lote_detalle_screen.dart';

class SiembrasListaScreen extends StatefulWidget {
  final MotorInvernadero motor;

  const SiembrasListaScreen({
    super.key,
    required this.motor,
  });

  @override
  State<SiembrasListaScreen> createState() => _SiembrasListaScreenState();
}

class _SiembrasListaScreenState extends State<SiembrasListaScreen> {
  String? _cultivoFiltro; // null = "Todos"
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;

  String _formatearFechaCorta(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia-$mes';
  }

  String _formatearFechaCompleta(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final ano = fecha.year.toString();
    return '$dia-$mes-$ano';
  }

  String _formatearEtapa(Etapa etapa) {
    return etapa.name.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  String _obtenerCultivoLabel(Lote? lote) {
    if (lote == null) return 'Cultivo desconocido';
    return CultivoLabels.obtenerLabel(lote.cultivoKey);
  }

  Future<void> _seleccionarFechaDesde(BuildContext context) async {
    final DateTime? fecha = await showDatePicker(
      context: context,
      initialDate: _fechaDesde ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (fecha != null) {
      setState(() {
        _fechaDesde = fecha;
      });
    }
  }

  Future<void> _seleccionarFechaHasta(BuildContext context) async {
    final DateTime? fecha = await showDatePicker(
      context: context,
      initialDate: _fechaHasta ?? DateTime.now(),
      firstDate: _fechaDesde ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (fecha != null) {
      setState(() {
        _fechaHasta = fecha;
      });
    }
  }

  List<Movimiento> _aplicarFiltros() {
    // Obtener todas las siembras no anuladas
    var siembras = widget.motor.movimientos
        .where((m) => m.tipo == TipoMovimiento.siembra && !m.anulado)
        .toList();

    // Filtrar por cultivo si está seleccionado
    if (_cultivoFiltro != null) {
      siembras = siembras.where((movimiento) {
        try {
          final lote = widget.motor.lotes.firstWhere(
            (l) => l.id == movimiento.loteId,
          );
          return lote.cultivoKey == _cultivoFiltro;
        } catch (_) {
          return false;
        }
      }).toList();
    }

    // Filtrar por fecha desde
    if (_fechaDesde != null) {
      final inicioDia = DateTime(_fechaDesde!.year, _fechaDesde!.month, _fechaDesde!.day);
      siembras = siembras.where((movimiento) {
        return movimiento.fecha.isAfter(inicioDia.subtract(const Duration(milliseconds: 1))) ||
            movimiento.fecha.isAtSameMomentAs(inicioDia);
      }).toList();
    }

    // Filtrar por fecha hasta
    if (_fechaHasta != null) {
      final finDia = DateTime(_fechaHasta!.year, _fechaHasta!.month, _fechaHasta!.day);
      final finDiaConHora = finDia.add(const Duration(days: 1));
      siembras = siembras.where((movimiento) {
        return movimiento.fecha.isBefore(finDiaConHora);
      }).toList();
    }

    // Ordenar por fecha descendente (más nuevo arriba)
    siembras.sort((a, b) => b.fecha.compareTo(a.fecha));

    return siembras;
  }

  @override
  Widget build(BuildContext context) {
    final siembras = _aplicarFiltros();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Siembras'),
      ),
      body: Column(
        children: [
          // Filtros
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              children: [
                // Filtro por cultivo
                DropdownButtonFormField<String>(
                  value: _cultivoFiltro,
                  decoration: const InputDecoration(
                    labelText: 'Cultivo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.eco),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Todos'),
                    ),
                    ...CultivoKeys.todas.map((cultivoKey) {
                      return DropdownMenuItem<String>(
                        value: cultivoKey,
                        child: Text(CultivoLabels.obtenerLabel(cultivoKey)),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _cultivoFiltro = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Filtro por rango de fechas
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _seleccionarFechaDesde(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Desde',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _fechaDesde != null
                                ? _formatearFechaCompleta(_fechaDesde!)
                                : 'Seleccionar fecha',
                            style: TextStyle(
                              color: _fechaDesde != null
                                  ? null
                                  : Theme.of(context).hintColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _seleccionarFechaHasta(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Hasta',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _fechaHasta != null
                                ? _formatearFechaCompleta(_fechaHasta!)
                                : 'Seleccionar fecha',
                            style: TextStyle(
                              color: _fechaHasta != null
                                  ? null
                                  : Theme.of(context).hintColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Botón para limpiar filtros
                if (_cultivoFiltro != null || _fechaDesde != null || _fechaHasta != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _cultivoFiltro = null;
                          _fechaDesde = null;
                          _fechaHasta = null;
                        });
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('Limpiar filtros'),
                    ),
                  ),
              ],
            ),
          ),
          // Lista de siembras
          Expanded(
            child: siembras.isEmpty
                ? const Center(
                    child: Text('No hay siembras registradas'),
                  )
                : ListView.builder(
                    itemCount: siembras.length,
                    itemBuilder: (context, index) {
                      final movimiento = siembras[index];

                      Lote? lote;
                      try {
                        lote = widget.motor.lotes.firstWhere(
                          (l) => l.id == movimiento.loteId,
                          orElse: () => Lote(
                            id: movimiento.loteId,
                            cultivoKey: 'desconocido',
                            cantidadActual: movimiento.cantidad ?? 0,
                            etapaActual: Etapa.semillero_calefaccionado,
                            fechaInicioEtapa: movimiento.fecha,
                            fechaSiembra: movimiento.fecha,
                            activo: true,
                            cortesRealizados: 0,
                          ),
                        );
                      } catch (_) {
                        lote = null;
                      }

                      final fecha = _formatearFechaCorta(movimiento.fecha);
                      final cultivoLabel = _obtenerCultivoLabel(lote);
                      final cantidad = movimiento.cantidad ?? 0;
                      final etapa = lote?.etapaActual ?? Etapa.semillero_calefaccionado;
                      final etapaLabel = _formatearEtapa(etapa);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              fecha,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          title: Text(
                            cultivoLabel,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Cantidad: $cantidad · Etapa: $etapaLabel'),
                          onTap: lote == null
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => LoteDetalleScreen(lote: lote!),
                                    ),
                                  );
                                },
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


