import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/pastel_section_card.dart';
import '../data/invernadero_firestore_repo.dart';
import '../domain/movimiento.dart';

class GastosScreen extends StatefulWidget {
  final InvernaderoFirestoreRepo firestoreRepo;

  const GastosScreen({super.key, required this.firestoreRepo});

  @override
  State<GastosScreen> createState() => _GastosScreenState();
}

class _GastosScreenState extends State<GastosScreen> {
  final _formKey = GlobalKey<FormState>();

  final _montoController = TextEditingController();
  final _descripcionController = TextEditingController();

  DateTime _fecha = DateTime.now();
  String? _categoria;
  MedioPago? _medioPago;

  bool _isLoading = false;

  static const List<String> _categorias = [
    'Insumos',
    'Mano de obra',
    'Electricidad',
    'Otros',
  ];

  @override
  void dispose() {
    _montoController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? fecha = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (fecha != null) {
      setState(() {
        _fecha = fecha;
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_categoria == null || _categoria!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor seleccione una categoría'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_medioPago == null) {
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
      final textoMonto = _montoController.text.replaceAll(',', '.');
      final monto = double.parse(textoMonto);
      final descripcion = _descripcionController.text.trim();

      final data = <String, dynamic>{
        'fecha': _fecha.toIso8601String(),
        'monto': monto,
        'categoria': _categoria,
        'medioPago': _medioPago!.name,
      };
      if (descripcion.isNotEmpty) {
        data['descripcion'] = descripcion;
      }

      await widget.firestoreRepo.guardarGasto(data);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gasto registrado'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al registrar gasto: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
    final fechaLabel =
        '${_fecha.day.toString().padLeft(2, '0')}-${_fecha.month.toString().padLeft(2, '0')}-${_fecha.year}';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Registrar Gasto'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: PastelSectionCard(
          pastel: AppPastel.ventas,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Fecha
              Text('Fecha', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _seleccionarFecha(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(fechaLabel),
                ),
              ),
              const SizedBox(height: 16),

              // Monto
              TextFormField(
                controller: _montoController,
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                  helperText: 'Monto del gasto',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese el monto';
                  }
                  final normalizado = value.replaceAll(',', '.');
                  final monto = double.tryParse(normalizado);
                  if (monto == null || monto <= 0) {
                    return 'El monto debe ser un número positivo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Categoría
              DropdownButtonFormField<String>(
                value: _categoria,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categorias
                    .map(
                      (c) => DropdownMenuItem<String>(
                        value: c,
                        child: Text(c),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _categoria = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor seleccione una categoría';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Medio de pago
              DropdownButtonFormField<MedioPago>(
                value: _medioPago,
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
                    _medioPago = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Por favor seleccione un medio de pago';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Descripción opcional
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Botón guardar
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _guardar,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isLoading ? 'Guardando...' : 'Guardar'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
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
}

