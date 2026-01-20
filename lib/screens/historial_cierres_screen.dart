import 'package:flutter/material.dart';
import '../domain/motor_invernadero.dart';
import '../domain/cierre_jornada.dart';

class HistorialCierresScreen extends StatelessWidget {
  final MotorInvernadero motor;

  const HistorialCierresScreen({
    super.key,
    required this.motor,
  });

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  void _mostrarDetalle(BuildContext context, CierreJornada cierre) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cierre del ${_formatearFecha(cierre.fecha)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetalleItem('Fecha', _formatearFecha(cierre.fecha)),
            const SizedBox(height: 12),
            _buildDetalleItem('Ventas', cierre.cantidadVentas.toString()),
            const SizedBox(height: 12),
            _buildDetalleItem('Unidades Vendidas', cierre.unidadesVendidas.toString()),
            const SizedBox(height: 12),
            _buildDetalleItem(
              'Total \$',
              '\$${cierre.totalDolares.toStringAsFixed(2)}',
              isHighlight: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleItem(String label, String valor, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          valor,
          style: TextStyle(
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            fontSize: isHighlight ? 18 : 16,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cierres = List<CierreJornada>.from(motor.cierresJornada)
      ..sort((a, b) => b.fecha.compareTo(a.fecha));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Historial de Cierres'),
      ),
      body: cierres.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay cierres registrados',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: cierres.length,
              itemBuilder: (context, index) {
                final cierre = cierres[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.lock,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      _formatearFecha(cierre.fecha),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    subtitle: Text(
                      '${cierre.cantidadVentas} ventas • ${cierre.unidadesVendidas} unidades',
                    ),
                    trailing: Text(
                      '\$${cierre.totalDolares.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    onTap: () => _mostrarDetalle(context, cierre),
                  ),
                );
              },
            ),
    );
  }
}

