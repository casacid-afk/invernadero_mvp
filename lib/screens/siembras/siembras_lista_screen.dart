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
    // DESACTIVADO TEMPORALMENTE: UI de listado/filtros de siembras
    // Reemplazado por placeholder simple para estabilizar CAP34
    return Scaffold(
      appBar: AppBar(title: const Text('Siembras')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Siembras (en revisión)',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Temporalmente desactivado para estabilizar CAP34',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
