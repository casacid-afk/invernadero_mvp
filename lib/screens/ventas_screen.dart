import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/invernadero_firestore_repo.dart';
import '../domain/motor_invernadero.dart';
import '../domain/cultivos.dart';
import '../domain/movimiento.dart';
import '../utils/parsers.dart';

class VentasScreen extends StatefulWidget {
  final MotorInvernadero motor;
  final InvernaderoFirestoreRepo firestoreRepo;

  const VentasScreen({super.key, required this.motor, required this.firestoreRepo});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

/// Promo predefinida: solo datos para UI y registro (cambio mínimo, sin modelo de promos).
const _promoLechuga3Por5000 = (
  id: '3_lechugas_5000',
  label: '3 lechugas por \$ 5.000',
  cultivoKey: CultivoKeys.lechuga,
  cantidad: 3,
  total: 5000,
);

class _VentasScreenState extends State<VentasScreen> {
  final _formKey = GlobalKey<FormState>();

  static final _formatoClp = NumberFormat.currency(
    locale: 'es_CL',
    symbol: r'$ ',
    decimalDigits: 0,
  );

  String? _cultivoSeleccionado;
  String? _promoSeleccionada; // null = sin promo, '3_lechugas_5000' = promo lechuga
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
      final int cantidad;
      final double precioUnitario;
      if (_promoSeleccionada == _promoLechuga3Por5000.id) {
        cantidad = _promoLechuga3Por5000.cantidad;
        precioUnitario = _promoLechuga3Por5000.total / _promoLechuga3Por5000.cantidad;
      } else {
        cantidad = int.parse(_cantidadController.text);
        precioUnitario = double.parse(_precioController.text);
      }

      final fecha = DateTime.now();
      // Registrar la venta (flujo actual en memoria)
      widget.motor.registrarVenta(
        cultivoKey: _cultivoSeleccionado!,
        cantidad: cantidad,
        precioUnitario: precioUnitario,
        medioPago: _medioPagoSeleccionado!,
        fecha: fecha,
      );

      // Persistir en Firestore; si falla no se pierde la venta local
      try {
        final total = cantidad * precioUnitario;
        await widget.firestoreRepo.guardarVenta({
          'fecha': fecha.toIso8601String(),
          'total': total,
          'items': [
            {
              'cultivoKey': _cultivoSeleccionado!,
              'cantidad': cantidad,
              'precioUnitario': precioUnitario,
            },
          ],
          'medioPago': _medioPagoSeleccionado!.name,
        });
      } catch (e) {
        debugPrint('Firestore guardarVenta: $e');
      }
      try {
        final total = cantidad * precioUnitario;
        await widget.firestoreRepo.guardarMovimiento({
          'tipo': 'venta',
          'fecha': fecha.toIso8601String(),
          'cultivoKey': _cultivoSeleccionado!,
          'cantidad': cantidad,
          'medioPago': _medioPagoSeleccionado!.name,
          'total': total,
          'detalle': 'venta manual mvp',
        });
      } catch (e) {
        debugPrint('Firestore guardarMovimiento: $e');
      }

      if (!mounted) return;

      // Mostrar mensaje de éxito
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
        _promoSeleccionada = null;
        _cantidadController.clear();
        _precioController.clear();
        _medioPagoSeleccionado = null;
      });
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
    // Obtener stock total y stock disponible para venta (solo etapa final)
    final stocksTotales = <String, int>{};
    final stocksDisponiblesVenta = <String, int>{};
    for (final cultivoKey in CultivoKeys.todas) {
      stocksTotales[cultivoKey] = widget.motor.calcularStockPorCultivo(
        cultivoKey,
      );
      stocksDisponiblesVenta[cultivoKey] = widget.motor
          .calcularStockFinalPorCultivo(cultivoKey);
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
                    if (value != CultivoKeys.lechuga) _promoSeleccionada = null;
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
                          'Disponible para venta (etapa final): $stockDisponibleVentaSeleccionado unidades',
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

              // Selector promo (solo lechuga)
              if (cultivoSeleccionado == CultivoKeys.lechuga)
                DropdownButtonFormField<String>(
                  value: _promoSeleccionada,
                  decoration: const InputDecoration(
                    labelText: 'Promo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_offer),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Sin promo'),
                    ),
                    DropdownMenuItem<String>(
                      value: _promoLechuga3Por5000.id,
                      child: Text(_promoLechuga3Por5000.label),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _promoSeleccionada = value;
                      if (value == _promoLechuga3Por5000.id) {
                        _cantidadController.text = '${_promoLechuga3Por5000.cantidad}';
                        _precioController.text = (_promoLechuga3Por5000.total / _promoLechuga3Por5000.cantidad).toStringAsFixed(2);
                      }
                    });
                  },
                ),
              if (cultivoSeleccionado == CultivoKeys.lechuga) const SizedBox(height: 16),

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

              // Información de total (si hay cantidad y precio o promo)
              Builder(
                builder: (context) {
                  final bool esPromoLechuga = _promoSeleccionada == _promoLechuga3Por5000.id;
                  final cantidad = esPromoLechuga
                      ? _promoLechuga3Por5000.cantidad
                      : parsearIntConDefault(_cantidadController.text, 0);
                  final total = esPromoLechuga
                      ? _promoLechuga3Por5000.total.toDouble()
                      : cantidad * parsearDoubleConDefault(_precioController.text, 0.0);

                  if (cantidad > 0 && total > 0) {
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
                                _formatoClp.format(total),
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
