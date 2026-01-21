import 'package:flutter/material.dart';

import '../../domain/cultivos.dart';
import '../../domain/motor_invernadero.dart';

class SiembraNuevaScreen extends StatefulWidget {
  final MotorInvernadero motor;
  final String? initialCultivoKey;
  final int? initialCantidad;
  final bool esSiembraRapida;

  const SiembraNuevaScreen({
    super.key,
    required this.motor,
    this.initialCultivoKey,
    this.initialCantidad,
    this.esSiembraRapida = false,
  });

  @override
  State<SiembraNuevaScreen> createState() => _SiembraNuevaScreenState();
}

class _SiembraNuevaScreenState extends State<SiembraNuevaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cantidadController = TextEditingController();

  DateTime _fecha = DateTime.now();
  String? _cultivoKey;
  int? _cantidad;

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    // Inicializar valores si vienen como parámetros
    _cultivoKey = widget.initialCultivoKey;
    if (widget.initialCantidad != null) {
      _cantidad = widget.initialCantidad;
      _cantidadController.text = widget.initialCantidad.toString();
    }
  }

  @override
  void dispose() {
    _cantidadController.dispose();
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

  Future<void> _mostrarDialogoConfirmacion(
    BuildContext context,
    int cantidad,
    String cultivoKey,
  ) async {
    final cultivoLabel = CultivoLabels.obtenerLabel(cultivoKey);
    final esSiembraRapida = widget.esSiembraRapida;
    final resultado = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Siembra registrada'),
          content: Text('Sembraste $cantidad de $cultivoLabel. ¿Qué deseas hacer?'),
          actions: [
            // Botón "Registrar otra siembra"
            TextButton(
              onPressed: () => Navigator.of(context).pop('otra'),
              child: const Text('Registrar otra siembra'),
            ),
            // Botón "Volver al Home" (destacado si es siembra rápida)
            if (esSiembraRapida)
              FilledButton(
                onPressed: () => Navigator.of(context).pop('home'),
                child: const Text('Volver al Home'),
              )
            else
              TextButton(
                onPressed: () => Navigator.of(context).pop('home'),
                child: const Text('Volver al Home'),
              ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (resultado == 'home') {
      // Volver al Home y forzar recarga de coberturas/alertas
      // Pasar true como resultado para que el Home recargue coberturas
      Navigator.of(context).pop(true);
    } else if (resultado == 'otra') {
      // Registrar otra siembra: mantener cultivo seleccionado, cantidad vacía
      setState(() {
        _cantidad = null;
        _cantidadController.clear();
        _guardando = false;
      });
    } else {
      // Si se cierra el diálogo de otra forma, volver al Home por defecto
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _guardar() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    _formKey.currentState!.save();

    if (_cultivoKey == null || _cantidad == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Completa todos los campos')),
      );
      return;
    }

    setState(() {
      _guardando = true;
    });

    try {
      widget.motor.nuevaSiembra(
        cultivoKey: _cultivoKey!,
        cantidad: _cantidad!,
        fecha: _fecha,
      );

      // Mostrar diálogo de confirmación
      await _mostrarDialogoConfirmacion(context, _cantidad!, _cultivoKey!);
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error al registrar siembra: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fechaLabel =
        '${_fecha.day.toString().padLeft(2, '0')}-${_fecha.month.toString().padLeft(2, '0')}-${_fecha.year}';

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva siembra')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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

              // Cultivo
              DropdownButtonFormField<String>(
                value: _cultivoKey,
                decoration: const InputDecoration(
                  labelText: 'Cultivo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.eco),
                ),
                items: CultivoKeys.todas.map((cultivoKey) {
                  return DropdownMenuItem<String>(
                    value: cultivoKey,
                    child: Text(CultivoLabels.obtenerLabel(cultivoKey)),
                  );
                }).toList(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Selecciona un cultivo';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _cultivoKey = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Cantidad
              TextFormField(
                controller: _cantidadController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cantidad',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.format_list_numbered),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa una cantidad';
                  }
                  final parsed = int.tryParse(value);
                  if (parsed == null || parsed <= 0) {
                    return 'La cantidad debe ser un entero positivo';
                  }
                  return null;
                },
                onSaved: (value) {
                  _cantidad = int.tryParse(value ?? '');
                },
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_guardando ? 'Guardando...' : 'Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
