import 'package:flutter/material.dart';
import '../domain/motor_invernadero.dart';
import '../domain/cultivos.dart';
import '../domain/movimiento.dart';
import '../utils/parsers.dart';

class VentasScreen extends StatefulWidget {
  final MotorInvernadero motor;

  const VentasScreen({super.key, required this.motor});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _cultivoSeleccionado;
  final _cantidadController = TextEditingController();
  final _precioController = TextEditingController();
  MedioPago? _medioPagoSeleccionado;

  bool _isLoading = false;

  @override
  void dispose() {
    _cantidadController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  String _formatearMedioPago(MedioPago medio) {
    switch (medio) {
      case MedioPago.efectivo:
        return 'Efectivo';
      case MedioPago.transferencia:
        return 'Transferencia';
      case MedioPago.credito:
        return 'Crédito';
    }
  }

  void _registrarVenta() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_cultivoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor seleccione un cultivo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_medioPagoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor seleccione un medio de pago'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final cantidad = int.parse(_cantidadController.text);
      final precioUnitario = double.parse(_precioController.text);

      // Registrar la venta
      widget.motor.registrarVenta(
        cultivoKey: _cultivoSeleccionado!,
        cantidad: cantidad,
        precioUnitario: precioUnitario,
        medioPago: _medioPagoSeleccionado!,
        fecha: DateTime.now(),
      );

      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Venta registrada exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Limpiar formulario
        setState(() {
          _cultivoSeleccionado = null;
          _cantidadController.clear();
          _precioController.clear();
          _medioPagoSeleccionado = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtener stock total y stock disponible para venta (solo maduro en etapa final)
    final ahora = DateTime.now();
    final stocksTotales = <String, int>{};
    final stocksDisponiblesVenta = <String, int>{};
    for (final cultivoKey in CultivoKeys.todas) {
      stocksTotales[cultivoKey] = widget.motor.calcularStockPorCultivo(
        cultivoKey,
      );
      stocksDisponiblesVenta[cultivoKey] = widget.motor
          .calcularStockMaduroPorCultivo(cultivoKey, ahora);
    }

    final cultivoSeleccionado = _cultivoSeleccionado;
    final stockTotalSeleccionado = cultivoSeleccionado != null
        ? (stocksTotales[cultivoSeleccionado] ?? 0)
        : 0;
    final stockDisponibleVentaSeleccionado = cultivoSeleccionado != null
        ? (stocksDisponiblesVenta[cultivoSeleccionado] ?? 0)
        : 0;

    final puedeRegistrarVenta =
        !_isLoading &&
        cultivoSeleccionado != null &&
        stockDisponibleVentaSeleccionado > 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Registrar Venta'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Selector de cultivo
              DropdownButtonFormField<String>(
                value: _cultivoSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Cultivo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.eco),
                ),
                items: CultivoKeys.todas.map((cultivoKey) {
                  final stockTotal = stocksTotales[cultivoKey] ?? 0;
                  final stockVenta = stocksDisponiblesVenta[cultivoKey] ?? 0;
                  final label = CultivoLabels.obtenerLabel(cultivoKey);
                  return DropdownMenuItem<String>(
                    value: cultivoKey,
                    child: Text(
                      '$label (Total: $stockTotal, Disp. venta: $stockVenta)',
                      style: TextStyle(
                        color: stockVenta > 0 ? null : Colors.grey,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _cultivoSeleccionado = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor seleccione un cultivo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Información de stock para el cultivo seleccionado
              if (cultivoSeleccionado != null)
                Card(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock seleccionado',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Text('Total: $stockTotalSeleccionado unidades'),
                        const SizedBox(height: 4),
                        Text(
                          'Disponible para venta (maduro): $stockDisponibleVentaSeleccionado unidades',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: stockDisponibleVentaSeleccionado > 0
                                ? Theme.of(context).colorScheme.primary
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (cultivoSeleccionado != null) const SizedBox(height: 16),

              // Campo cantidad
              TextFormField(
                controller: _cantidadController,
                decoration: const InputDecoration(
                  labelText: 'Cantidad',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                  helperText: 'Cantidad de unidades a vender',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese la cantidad';
                  }
                  final cantidad = int.tryParse(value);
                  if (cantidad == null || cantidad <= 0) {
                    return 'La cantidad debe ser un número positivo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo precio unitario
              TextFormField(
                controller: _precioController,
                decoration: const InputDecoration(
                  labelText: 'Precio Unitario',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                  helperText: 'Precio por unidad',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese el precio unitario';
                  }
                  final precio = double.tryParse(value);
                  if (precio == null || precio <= 0) {
                    return 'El precio debe ser un número positivo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Selector medio de pago
              DropdownButtonFormField<MedioPago>(
                value: _medioPagoSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Medio de Pago',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payment),
                ),
                items: MedioPago.values.map((medio) {
                  return DropdownMenuItem<MedioPago>(
                    value: medio,
                    child: Text(_formatearMedioPago(medio)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _medioPagoSeleccionado = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Por favor seleccione un medio de pago';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Botón registrar venta
              ElevatedButton.icon(
                onPressed: puedeRegistrarVenta ? _registrarVenta : null,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(_isLoading ? 'Registrando...' : 'Registrar Venta'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),

              // Información de total (si hay cantidad y precio)
              Builder(
                builder: (context) {
                  final cantidad = parsearIntConDefault(
                    _cantidadController.text,
                    0,
                  );
                  final precio = parsearDoubleConDefault(
                    _precioController.text,
                    0.0,
                  );
                  final total = cantidad * precio;

                  if (cantidad > 0 && precio > 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Card(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(
                                'Total de la Venta',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '\$${total.toStringAsFixed(2)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
