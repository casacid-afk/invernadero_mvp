import 'package:flutter/material.dart';
import '../data/invernadero_firestore_repo.dart';
import '../domain/motor_invernadero.dart';
import '../domain/lote.dart';
import '../domain/etapa.dart';
import '../domain/cultivos.dart';

class MermaScreen extends StatefulWidget {
  final MotorInvernadero motor;
  final InvernaderoFirestoreRepo? firestoreRepo;

  const MermaScreen({
    super.key,
    required this.motor,
    this.firestoreRepo,
  });

  @override
  State<MermaScreen> createState() => _MermaScreenState();
}

class _MermaScreenState extends State<MermaScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _loteSeleccionado;
  final _cantidadController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _cantidadController.dispose();
    super.dispose();
  }

  String _formatearEtapa(Etapa etapa) {
    switch (etapa) {
      case Etapa.semillero_calefaccionado:
        return 'Semillero Calefaccionado';
      case Etapa.bandeja_crianza:
        return 'Bandeja Crianza';
      case Etapa.bancada_inicial:
        return 'Bancada Inicial';
      case Etapa.bancada_final:
        return 'Bancada Final';
    }
  }

  String _formatearLote(Lote lote) {
    final cultivoLabel = CultivoLabels.obtenerLabel(lote.cultivoKey);
    final etapaLabel = _formatearEtapa(lote.etapaActual);
    return '$cultivoLabel - $etapaLabel (${lote.cantidadActual} unidades)';
  }

  List<Lote> _obtenerLotesDisponibles() {
    return widget.motor.lotes
        .where((lote) => lote.activo && lote.cantidadActual > 0)
        .toList()
      ..sort((a, b) {
        // Ordenar por cultivo y luego por fecha
        final cultivoCompare = a.cultivoKey.compareTo(b.cultivoKey);
        if (cultivoCompare != 0) return cultivoCompare;
        return a.fechaInicioEtapa.compareTo(b.fechaInicioEtapa);
      });
  }

  void _registrarMerma() async {
    debugPrint('MERMA TRACE: entro a _registrarMerma');
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_loteSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor seleccione un lote'),
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

      // Validar cantidad
      if (cantidad <= 0) {
        throw ArgumentError('La cantidad debe ser mayor a 0');
      }

      final lote = widget.motor.obtenerLote(_loteSeleccionado!);
      if (cantidad > lote.cantidadActual) {
        throw ArgumentError(
          'No se puede registrar merma de $cantidad unidades. Solo hay ${lote.cantidadActual} disponibles en el lote.',
        );
      }

      // Registrar la merma
      final fecha = DateTime.now();
      final movimiento = widget.motor.crearMerma(
        loteId: _loteSeleccionado!,
        cantidad: cantidad,
        fecha: fecha,
      );

      // Persistir en Firestore (movimientos), si hay repo disponible
      debugPrint('MERMA TRACE: firestoreRepo=${widget.firestoreRepo != null}');
      if (widget.firestoreRepo != null) {
        try {
          debugPrint('MERMA TRACE: voy a guardar movimiento merma');
          await widget.firestoreRepo!.guardarMovimiento({
            'tipo': 'merma',
            'fecha': fecha.toIso8601String(),
            'loteId': movimiento.loteId,
            'cultivoKey': lote.cultivoKey,
            'cantidad': movimiento.cantidad,
            'etapaOrigen': lote.etapaActual.name,
            'detalle': 'merma manual mvp',
          });
        } catch (e, st) {
          debugPrint('Firestore guardarMovimiento (merma): $e');
          debugPrint('$st');
        }
      }

      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Merma registrada exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Limpiar formulario
        setState(() {
          _loteSeleccionado = null;
          _cantidadController.clear();
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
    final lotesDisponibles = _obtenerLotesDisponibles();
    final loteSeleccionado = _loteSeleccionado != null
        ? widget.motor.lotes.firstWhere(
            (l) => l.id == _loteSeleccionado,
            orElse: () => lotesDisponibles.isNotEmpty
                ? lotesDisponibles.first
                : widget.motor.lotes.first,
          )
        : null;

    final cantidadTexto = _cantidadController.text.trim();
    final cantidad = int.tryParse(cantidadTexto);

    final puedeRegistrarMerma = !_isLoading &&
        _loteSeleccionado != null &&
        cantidad != null &&
        cantidad > 0 &&
        (loteSeleccionado == null || cantidad <= loteSeleccionado.cantidadActual);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Registrar Merma'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Selector de lote
              DropdownButtonFormField<String>(
                value: _loteSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Lote',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory),
                ),
                items: lotesDisponibles.map((lote) {
                  return DropdownMenuItem<String>(
                    value: lote.id,
                    child: Text(_formatearLote(lote)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _loteSeleccionado = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor seleccione un lote';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Información del lote seleccionado
              if (loteSeleccionado != null)
                Card(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lote seleccionado',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cultivo: ${CultivoLabels.obtenerLabel(loteSeleccionado.cultivoKey)}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Etapa actual: ${_formatearEtapa(loteSeleccionado.etapaActual)}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cantidad disponible: ${loteSeleccionado.cantidadActual} unidades',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: loteSeleccionado.cantidadActual > 0
                                ? Theme.of(context).colorScheme.primary
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (loteSeleccionado != null) const SizedBox(height: 16),

              // Campo cantidad
              TextFormField(
                controller: _cantidadController,
                decoration: const InputDecoration(
                  labelText: 'Cantidad',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                  helperText: 'Cantidad de unidades a registrar como merma',
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
                  if (loteSeleccionado != null &&
                      cantidad > loteSeleccionado.cantidadActual) {
                    return 'La cantidad no puede ser mayor a ${loteSeleccionado.cantidadActual}';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    // Trigger rebuild para actualizar validación
                  });
                },
              ),
              const SizedBox(height: 24),

              // Botón registrar merma
              ElevatedButton.icon(
                onPressed: puedeRegistrarMerma ? _registrarMerma : null,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.remove_circle),
                label: Text(_isLoading ? 'Registrando...' : 'Registrar Merma'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
