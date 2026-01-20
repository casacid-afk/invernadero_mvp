import 'package:flutter/material.dart';

import '../../domain/lote.dart';
import '../../domain/etapa.dart';
import '../../domain/cultivos.dart';

class LoteDetalleScreen extends StatelessWidget {
  final Lote lote;

  const LoteDetalleScreen({
    super.key,
    required this.lote,
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

  @override
  Widget build(BuildContext context) {
    final cultivoLabel = CultivoLabels.obtenerLabel(lote.cultivoKey);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Lote'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cultivoLabel,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Lote: ${lote.id}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Cantidad actual: ${lote.cantidadActual}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Etapa actual: ${_formatearEtapa(lote.etapaActual)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Fecha siembra: ${_formatearFecha(lote.fechaSiembra)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Inicio etapa: ${_formatearFecha(lote.fechaInicioEtapa)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Cortes realizados: ${lote.cortesRealizados}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Activo: ${lote.activo ? 'Sí' : 'No'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


