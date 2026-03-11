import 'package:flutter/material.dart';
import '../data/invernadero_firestore_repo.dart';
import '../domain/motor_invernadero.dart';
import '../domain/lote.dart';
import '../domain/etapa.dart';
import '../domain/cultivos.dart';

class TraspasoScreen extends StatefulWidget {
  final MotorInvernadero motor;
  final InvernaderoFirestoreRepo? firestoreRepo;

  const TraspasoScreen({
    super.key,
    required this.motor,
    this.firestoreRepo,
  });

  @override
  State<TraspasoScreen> createState() => _TraspasoScreenState();
}

class _TraspasoScreenState extends State<TraspasoScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _loteSeleccionado;
  Etapa? _etapaDestinoSeleccionada;
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

  List<Etapa> _obtenerEtapasDestinoDisponibles(Lote? lote) {
    if (lote == null) return [];
    final etapaActual = lote.etapaActual;
    final todasEtapas = Etapa.values;
    final indiceActual = todasEtapas.indexOf(etapaActual);
    // Solo mostrar etapas posteriores a la actual
    return todasEtapas
        .where((etapa) => todasEtapas.indexOf(etapa) > indiceActual)
        .toList();
  }

  void _registrarTraspaso() async {
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

    if (_etapaDestinoSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor seleccione una etapa destino'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final lote = widget.motor.obtenerLote(_loteSeleccionado!);
      final cantidadTexto = _cantidadController.text.trim();
      final int? cantidad = cantidadTexto.isEmpty
          ? null
          : int.parse(cantidadTexto);

      // Validar cantidad si se especificó
      if (cantidad != null) {
        if (cantidad <= 0) {
          throw ArgumentError('La cantidad debe ser mayor a 0');
        }
        if (cantidad > lote.cantidadActual) {
          throw ArgumentError(
            'No se puede traspasar $cantidad unidades. Solo hay ${lote.cantidadActual} disponibles en el lote.',
          );
        }
      }

      // Registrar el traspaso
      final fecha = DateTime.now();
      final movimiento = widget.motor.crearTraspaso(
        loteId: _loteSeleccionado!,
        etapaDestino: _etapaDestinoSeleccionada!,
        fecha: fecha,
        cantidad: cantidad,
      );

      // Persistir en Firestore (movimientos), si hay repo disponible
      if (widget.firestoreRepo != null) {
        try {
          await widget.firestoreRepo!.guardarMovimiento({
            'tipo': 'traspaso',
            'fecha': fecha.toIso8601String(),
            'loteId': movimiento.loteId,
            'cultivoKey': lote.cultivoKey,
            'cantidad': movimiento.cantidad,
            'etapaOrigen': movimiento.etapaOrigen?.name,
            'etapaDestino': movimiento.etapaDestino?.name,
            'detalle': 'traspaso manual mvp',
          });
        } catch (e) {
          debugPrint('Firestore guardarMovimiento (traspaso): $e');
        }
      }

      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Traspaso registrado exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Limpiar formulario
        setState(() {
          _loteSeleccionado = null;
          _etapaDestinoSeleccionada = null;
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
            orElse: () => lotesDisponibles.first,
          )
        : null;

    final etapasDestinoDisponibles =
        _obtenerEtapasDestinoDisponibles(loteSeleccionado);

    final puedeRegistrarTraspaso = !_isLoading &&
        _loteSeleccionado != null &&
        _etapaDestinoSeleccionada != null &&
        lotesDisponibles.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Registrar Traspaso'),
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
                    _etapaDestinoSeleccionada = null; // Reset etapa al cambiar lote
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

              // Selector de etapa destino
              DropdownButtonFormField<Etapa>(
                value: _etapaDestinoSeleccionada,
                decoration: const InputDecoration(
                  labelText: 'Etapa Destino',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.arrow_forward),
                  helperText: 'Seleccione la etapa destino del traspaso',
                ),
                items: etapasDestinoDisponibles.map((etapa) {
                  return DropdownMenuItem<Etapa>(
                    value: etapa,
                    child: Text(_formatearEtapa(etapa)),
                  );
                }).toList(),
                onChanged: _loteSeleccionado != null
                    ? (value) {
                        setState(() {
                          _etapaDestinoSeleccionada = value;
                        });
                      }
                    : null,
                validator: (value) {
                  if (value == null) {
                    return 'Por favor seleccione una etapa destino';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo cantidad (opcional)
              TextFormField(
                controller: _cantidadController,
                decoration: const InputDecoration(
                  labelText: 'Cantidad (opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                  helperText:
                      'Deje vacío para traspasar todo el lote, o especifique una cantidad',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final cantidad = int.tryParse(value);
                    if (cantidad == null || cantidad <= 0) {
                      return 'La cantidad debe ser un número positivo';
                    }
                    if (loteSeleccionado != null &&
                        cantidad > loteSeleccionado.cantidadActual) {
                      return 'La cantidad no puede ser mayor a ${loteSeleccionado.cantidadActual}';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Botón registrar traspaso
              ElevatedButton.icon(
                onPressed: puedeRegistrarTraspaso ? _registrarTraspaso : null,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.swap_horiz),
                label: Text(_isLoading ? 'Registrando...' : 'Registrar Traspaso'),
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
