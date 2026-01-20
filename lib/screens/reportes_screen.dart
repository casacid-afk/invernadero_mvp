import 'package:flutter/material.dart';
import '../domain/motor_invernadero.dart';
import '../domain/movimiento.dart';
import '../domain/cultivos.dart';

class ReportesScreen extends StatefulWidget {
  final MotorInvernadero motor;

  const ReportesScreen({
    super.key,
    required this.motor,
  });

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  DateTime _fechaSeleccionada = DateTime.now();

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? fecha = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (fecha != null) {
      setState(() {
        _fechaSeleccionada = fecha;
      });
    }
  }

  List<Movimiento> _obtenerVentasDelDia(DateTime fecha) {
    final inicioDia = DateTime(fecha.year, fecha.month, fecha.day);
    final finDia = inicioDia.add(const Duration(days: 1));

    return widget.motor.movimientos.where((movimiento) {
      return movimiento.tipo == TipoMovimiento.venta &&
          !movimiento.anulado &&
          movimiento.fecha.isAfter(inicioDia.subtract(const Duration(milliseconds: 1))) &&
          movimiento.fecha.isBefore(finDia);
    }).toList();
  }

  Map<String, dynamic> _calcularReporte() {
    final ventas = _obtenerVentasDelDia(_fechaSeleccionada);

    final cantidadVentas = ventas.length;
    final unidadesVendidas = ventas.fold<int>(
      0,
      (suma, venta) => suma + (venta.cantidad ?? 0),
    );
    final totalDolares = ventas.fold<double>(
      0.0,
      (suma, venta) =>
          suma + ((venta.cantidad ?? 0) * (venta.precioUnitario ?? 0.0)),
    );

    final efectivo = ventas
        .where((v) => v.medioPago == MedioPago.efectivo)
        .fold<double>(
          0.0,
          (suma, venta) =>
              suma + ((venta.cantidad ?? 0) * (venta.precioUnitario ?? 0.0)),
        );

    final transferencia = ventas
        .where((v) => v.medioPago == MedioPago.transferencia)
        .fold<double>(
          0.0,
          (suma, venta) =>
              suma + ((venta.cantidad ?? 0) * (venta.precioUnitario ?? 0.0)),
        );

    final credito = ventas
        .where((v) => v.medioPago == MedioPago.credito)
        .fold<double>(
          0.0,
          (suma, venta) =>
              suma + ((venta.cantidad ?? 0) * (venta.precioUnitario ?? 0.0)),
        );

    return {
      'cantidadVentas': cantidadVentas,
      'unidadesVendidas': unidadesVendidas,
      'totalDolares': totalDolares,
      'efectivo': efectivo,
      'transferencia': transferencia,
      'credito': credito,
    };
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    final reporte = _calcularReporte();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Reportes Diarios'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Selector de fecha
            Card(
              child: InkWell(
                onTap: () => _seleccionarFecha(context),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fecha',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              _formatearFecha(_fechaSeleccionada),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Resumen principal
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen del Día',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _buildMetrica(
                      context,
                      'Ventas',
                      reporte['cantidadVentas'].toString(),
                      Icons.receipt,
                    ),
                    const SizedBox(height: 12),
                    _buildMetrica(
                      context,
                      'Unidades Vendidas',
                      reporte['unidadesVendidas'].toString(),
                      Icons.inventory_2,
                    ),
                    const SizedBox(height: 12),
                    _buildMetrica(
                      context,
                      'Total \$',
                      '\$${reporte['totalDolares'].toStringAsFixed(2)}',
                      Icons.attach_money,
                      isHighlight: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Desglose por medio de pago
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Desglose por Medio de Pago',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _buildMedioPago(
                      context,
                      'Efectivo',
                      reporte['efectivo'] as double,
                      Colors.green,
                    ),
                    const SizedBox(height: 12),
                    _buildMedioPago(
                      context,
                      'Transferencia',
                      reporte['transferencia'] as double,
                      Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    _buildMedioPago(
                      context,
                      'Crédito',
                      reporte['credito'] as double,
                      Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrica(
    BuildContext context,
    String label,
    String valor,
    IconData icon, {
    bool isHighlight = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        Text(
          valor,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isHighlight ? 20 : null,
                color: isHighlight
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
        ),
      ],
    );
  }

  Widget _buildMedioPago(
    BuildContext context,
    String label,
    double monto,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        Text(
          '\$${monto.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }
}

