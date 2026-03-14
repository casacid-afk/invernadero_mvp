import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/pastel_section_card.dart';
import '../../data/invernadero_firestore_repo.dart';
import '../../domain/cultivos.dart';
import '../../domain/motor_invernadero.dart';

class SiembraNuevaScreen extends StatefulWidget {
  final MotorInvernadero motor;
  final InvernaderoFirestoreRepo? firestoreRepo;
  final String? initialCultivoKey;
  final int? initialCantidad;
  final bool esSiembraRapida;

  const SiembraNuevaScreen({
    super.key,
    required this.motor,
    this.firestoreRepo,
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
      final movimiento = widget.motor.nuevaSiembra(
        cultivoKey: _cultivoKey!,
        cantidad: _cantidad!,
        fecha: _fecha,
      );

      if (widget.firestoreRepo != null) {
        try {
          await widget.firestoreRepo!.guardarMovimiento({
            'tipo': 'siembra',
            'fecha': _fecha.toIso8601String(),
            'loteId': movimiento.loteId,
            'cultivoKey': _cultivoKey!,
            'cantidad': _cantidad!,
            'etapaDestino': 'semillero_calefaccionado',
            'detalle': 'siembra manual mvp',
          });
          final disponible = widget.motor.calcularStockFinalPorCultivo(_cultivoKey!);
          final enProceso = widget.motor.calcularStockPorCultivo(_cultivoKey!);
          await widget.firestoreRepo!.guardarStockActualDetallePorCultivo(
            cultivoKey: _cultivoKey!,
            disponible: disponible,
            enProceso: enProceso,
          );
        } catch (_) {
          if (!mounted) return;
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('La siembra quedó local pero no sincronizada'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _guardando = false;
          });
          return;
        }
      }

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
    final theme = Theme.of(context);
    final fechaLabel =
        '${_fecha.day.toString().padLeft(2, '0')}-${_fecha.month.toString().padLeft(2, '0')}-${_fecha.year}';

    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 15,
      color: AppColors.textPrimary,
    );
    final inputTextStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 16,
      color: AppColors.textPrimary,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nueva siembra',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: PastelSectionCard(
          pastel: AppPastel.siembras,
          child: Form(
            key: _formKey,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fecha
              Text('Fecha', style: labelStyle),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _seleccionarFecha(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.calendar_today),
                    labelStyle: labelStyle,
                  ),
                  child: Text(
                    fechaLabel,
                    style: inputTextStyle,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cultivo
              DropdownButtonFormField<String>(
                value: _cultivoKey,
                decoration: InputDecoration(
                  labelText: 'Cultivo',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.eco),
                  labelStyle: labelStyle,
                  floatingLabelStyle: labelStyle,
                ),
                dropdownColor: theme.scaffoldBackgroundColor,
                style: inputTextStyle,
                items: CultivoKeys.todas.map((cultivoKey) {
                  return DropdownMenuItem<String>(
                    value: cultivoKey,
                    child: Text(
                      CultivoLabels.obtenerLabel(cultivoKey),
                      style: inputTextStyle,
                    ),
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
                style: inputTextStyle,
                decoration: InputDecoration(
                  labelText: 'Cantidad',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.format_list_numbered),
                  labelStyle: labelStyle,
                  floatingLabelStyle: labelStyle,
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
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _guardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.save, size: 22),
                  label: Text(
                    _guardando ? 'Guardando...' : 'Guardar',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
