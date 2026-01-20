import 'package:flutter/material.dart';

import '../../domain/motor_invernadero.dart';
import '../../domain/movimiento.dart';
import '../../domain/lote.dart';
import '../../domain/etapa.dart';
import '../../domain/cultivos.dart';

class SiembrasListaScreen extends StatelessWidget {
  final MotorInvernadero motor;

  const SiembrasListaScreen({
    super.key,
    required this.motor,
  });

  String _formatearFecha(DateTime fecha) {
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

  @override
  Widget build(BuildContext context) {
    // Obtener todas las siembras no anuladas
    final siembras = motor.movimientos
        .where((m) => m.tipo == TipoMovimiento.siembra && !m.anulado)
        .toList();

    // Ordenar por fecha descendente (más nuevo arriba)
    siembras.sort((a, b) => b.fecha.compareTo(a.fecha));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Siembras'),
      ),
      body: siembras.isEmpty
          ? const Center(
              child: Text('No hay siembras registradas'),
            )
          : ListView.builder(
              itemCount: siembras.length,
              itemBuilder: (context, index) {
                final movimiento = siembras[index];

                Lote? lote;
                try {
                  lote = motor.lotes.firstWhere(
                    (l) => l.id == movimiento.loteId,
                  );
                } catch (_) {
                  lote = null;
                }

                final fecha = _formatearFecha(movimiento.fecha);
                final cultivoLabel = _obtenerCultivoLabel(lote);
                final cantidad = movimiento.cantidad ?? 0;
                final etapa = lote?.etapaActual ?? Etapa.semillero_calefaccionado;
                final etapaLabel = _formatearEtapa(etapa);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  ),
                );
              },
            ),
    );
  }
}


