import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/invernadero_firestore_repo.dart';
import 'resumen_cobro_detalle_screen.dart';

class CuentaClienteDetalleScreen extends StatefulWidget {
  final InvernaderoFirestoreRepo firestoreRepo;
  final String clienteId;
  final String clienteNombre;

  const CuentaClienteDetalleScreen({
    super.key,
    required this.firestoreRepo,
    required this.clienteId,
    required this.clienteNombre,
  });

  @override
  State<CuentaClienteDetalleScreen> createState() =>
      _CuentaClienteDetalleScreenState();
}

class _CuentaClienteDetalleScreenState
    extends State<CuentaClienteDetalleScreen> {
  final NumberFormat _formatoMoneda = NumberFormat.currency(
    locale: 'es_CL',
    symbol: r'$ ',
    decimalDigits: 0,
  );

  bool _cargando = false;
  String? _error;

  List<Map<String, dynamic>> _ventas = [];
  double _totalPendiente = 0;
  Map<String, dynamic>? _ultimoResumen;
  Set<String> _ventaIdsResumenAbierto = <String>{};
  bool _hayResumenAbiertoSinTrazabilidad = false;

  @override
  void initState() {
    super.initState();
    _cargarVentas();
    _cargarUltimoResumen();
    _cargarResumenAbiertoParaUI();
  }

  Future<void> _cargarVentas() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final ventas = await widget.firestoreRepo
          .obtenerVentasCreditoAbiertasPorCliente(widget.clienteId);

      // Ordenar por fecha desc
      ventas.sort((a, b) {
        final fa = a['fecha'];
        final fb = b['fecha'];
        if (fa == null && fb == null) return 0;
        if (fa == null) return 1;
        if (fb == null) return -1;
        try {
          final da = DateTime.tryParse(fa.toString());
          final db = DateTime.tryParse(fb.toString());
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da);
        } catch (_) {
          return 0;
        }
      });

      double total = 0;
      for (final v in ventas) {
        final totalRaw = v['total'];
        final t = (totalRaw is num) ? totalRaw.toDouble() : 0.0;
        total += t;
      }

      if (!mounted) return;

      setState(() {
        _ventas = ventas;
        _totalPendiente = total;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al cargar detalle de cuenta: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  Future<void> _cargarUltimoResumen() async {
    try {
      final snapshot = await widget.firestoreRepo.resumenesCobro
          .where('clienteId', isEqualTo: widget.clienteId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (!mounted) return;
      if (snapshot.docs.isEmpty) {
        setState(() {
          _ultimoResumen = null;
        });
        return;
      }
      final doc = snapshot.docs.first;
      setState(() {
        _ultimoResumen = {
          'id': doc.id,
          ...doc.data(),
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ultimoResumen = null;
      });
    }
  }

  /// Devuelve el resumen "abierto" (estado != 'pagado') más reciente para el cliente,
  /// o null si no hay ninguno. Considera también resúmenes legacy sin estado.
  Future<Map<String, dynamic>?> _obtenerResumenAbiertoMasReciente() async {
    try {
      final snapshot = await widget.firestoreRepo.resumenesCobro
          .where('clienteId', isEqualTo: widget.clienteId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final estado = data['estado']?.toString();
        if (estado != 'pagado') {
          return {
            'id': doc.id,
            ...data,
          };
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _cargarResumenAbiertoParaUI() async {
    final resumenAbierto = await _obtenerResumenAbiertoMasReciente();
    if (!mounted) return;
    if (resumenAbierto == null) {
      setState(() {
        _ventaIdsResumenAbierto = <String>{};
        _hayResumenAbiertoSinTrazabilidad = false;
      });
      return;
    }

    final dynamic ventaIdsRaw = resumenAbierto['ventaIds'];
    if (ventaIdsRaw is List) {
      final ids = ventaIdsRaw
          .map((e) => e?.toString())
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .toSet();
      setState(() {
        _ventaIdsResumenAbierto = ids;
        _hayResumenAbiertoSinTrazabilidad = ids.isEmpty;
      });
    } else {
      setState(() {
        _ventaIdsResumenAbierto = <String>{};
        _hayResumenAbiertoSinTrazabilidad = true;
      });
    }
  }

  String _formatearFechaHora(dynamic fechaRaw) {
    if (fechaRaw == null) return '';
    final d = DateTime.tryParse(fechaRaw.toString());
    if (d == null) return '';
    final fecha =
        '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
    final hora =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '$fecha $hora';
  }

  String _formatearFechaResumen(dynamic createdAt) {
    if (createdAt == null) return '';
    if (createdAt is Timestamp) {
      return DateFormat('dd-MM-yyyy HH:mm', 'es_CL').format(createdAt.toDate());
    }
    if (createdAt is DateTime) {
      return DateFormat('dd-MM-yyyy HH:mm', 'es_CL').format(createdAt);
    }
    final d = DateTime.tryParse(createdAt.toString());
    if (d == null) return '';
    return DateFormat('dd-MM-yyyy HH:mm', 'es_CL').format(d);
  }

  Future<void> _copiarResumenWhatsApp() async {
    if (_ventas.isEmpty) return;

    final texto = _generarTextoResumen();

    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resumen copiado'),
      ),
    );
  }

  Future<void> _marcarComoPagado() async {
    if (_ventas.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Marcar como pagado'),
          content: Text(
              '¿Confirmas marcar como pagadas todas las entregas abiertas de ${widget.clienteNombre}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      await widget.firestoreRepo
          .marcarVentasClienteComoPagadas(widget.clienteId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta marcada como pagada'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al marcar como pagado: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _generarTextoResumen() {
    final buffer = StringBuffer();
    buffer.writeln('Resumen de deuda – ${widget.clienteNombre}');
    buffer.writeln();
    buffer.writeln('Total pendiente: ${_formatoMoneda.format(_totalPendiente)}');
    buffer.writeln('Entregas abiertas: ${_ventas.length}');
    buffer.writeln();
    buffer.writeln('Detalle:');

    String? fechaActual;

    for (final v in _ventas) {
      final fechaRaw = v['fecha'];
      final d = DateTime.tryParse(fechaRaw?.toString() ?? '');
      String fechaLinea = '';
      String horaLinea = '';
      if (d != null) {
        fechaLinea =
            '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
        horaLinea =
            '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      }

      if (fechaLinea.isNotEmpty && fechaLinea != fechaActual) {
        buffer.writeln();
        buffer.writeln(fechaLinea);
        fechaActual = fechaLinea;
      }

      final items = (v['items'] as List?) ?? const [];
      String cultivo = '';
      int cantidad = 0;
      double precioUnitario = 0;
      if (items.isNotEmpty) {
        final item = items.first;
        if (item is Map) {
          cultivo = item['cultivoKey']?.toString() ?? '';
          final cantRaw = item['cantidad'];
          if (cantRaw is num) cantidad = cantRaw.toInt();
          final precioRaw = item['precioUnitario'];
          if (precioRaw is num) precioUnitario = precioRaw.toDouble();
        }
      }
      final totalRaw = v['total'];
      final total = (totalRaw is num) ? totalRaw.toDouble() : 0.0;

      buffer.writeln(
          '- $horaLinea $cultivo $cantidad x ${_formatoMoneda.format(precioUnitario)} = ${_formatoMoneda.format(total)}');
    }

    return buffer.toString();
  }

  Future<String?> _pedirTipoPeriodo({String? valorActual}) async {
    const opciones = ['manual', 'semanal', 'mensual', 'anual'];
    String seleccionado = valorActual != null && opciones.contains(valorActual)
        ? valorActual
        : 'manual';

    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Tipo de período'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: opciones.map((op) {
                  return RadioListTile<String>(
                    title: Text(op[0].toUpperCase() + op.substring(1)),
                    value: op,
                    groupValue: seleccionado,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        seleccionado = value;
                      });
                    },
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(seleccionado),
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final entregasAbiertas = _ventas.length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.clienteNombre),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_hayResumenAbiertoSinTrazabilidad)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            'Resumen abierto sin trazabilidad de ventas. '
                            'Las marcas por venta pueden no estar completas.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.orange[800]),
                          ),
                        ),
                      if (_ultimoResumen != null) ...[
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.receipt_long),
                            title: const Text('Ver último resumen'),
                            subtitle: () {
                              final fechaStr = _formatearFechaResumen(
                                  _ultimoResumen!['createdAt']);
                              return fechaStr.isNotEmpty
                                  ? Text('Fecha: $fechaStr')
                                  : null;
                            }(),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              final id =
                                  _ultimoResumen!['id']?.toString() ?? '';
                              if (id.isEmpty) return;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ResumenCobroDetalleScreen(
                                    firestoreRepo: widget.firestoreRepo,
                                    resumenId: id,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Resumen',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text('Entregas abiertas: $entregasAbiertas'),
                              const SizedBox(height: 4),
                              Text(
                                'Total pendiente: ${_formatoMoneda.format(_totalPendiente)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _ventas.isEmpty ? null : _copiarResumenWhatsApp,
                              icon: const Icon(Icons.message),
                              label: const Text('Copiar resumen WhatsApp'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _ventas.isEmpty
                                  ? null
                                  : () async {
                                      // Evitar resúmenes duplicados: revisar si ya hay uno abierto
                                      final resumenAbierto =
                                          await _obtenerResumenAbiertoMasReciente();
                                      if (resumenAbierto != null) {
                                        final decision =
                                            await showDialog<String>(
                                          context: context,
                                          builder: (context) {
                                            return AlertDialog(
                                              title: const Text(
                                                  'Ya existe un resumen abierto'),
                                              content: const Text(
                                                  'Este cliente ya tiene un resumen de cobro sin marcar como pagado.\n\n¿Qué quieres hacer?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop('cancelar'),
                                                  child:
                                                      const Text('Cancelar'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop('ver'),
                                                  child: const Text(
                                                      'Ver resumen existente'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop('actualizar'),
                                                  child: const Text(
                                                      'Actualizar resumen existente'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop('crear'),
                                                  child: const Text(
                                                      'Crear de todos modos'),
                                                ),
                                              ],
                                            );
                                          },
                                        );

                                        if (decision == 'ver') {
                                          final id = resumenAbierto['id']
                                                  ?.toString() ??
                                              '';
                                          if (id.isNotEmpty && mounted) {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ResumenCobroDetalleScreen(
                                                  firestoreRepo:
                                                      widget.firestoreRepo,
                                                  resumenId: id,
                                                ),
                                              ),
                                            );
                                          }
                                          return;
                                        } else if (decision == 'actualizar') {
                                          final tipoPeriodoSeleccionado =
                                              await _pedirTipoPeriodo(
                                            valorActual: resumenAbierto[
                                                    'tipoPeriodo']
                                                ?.toString(),
                                          );
                                          if (tipoPeriodoSeleccionado == null) {
                                            return;
                                          }

                                          final texto =
                                              _generarTextoResumen();

                                          DateTime? desde;
                                          DateTime? hasta;
                                          final ids = <String>[];
                                          for (final v in _ventas) {
                                            final fechaRaw = v['fecha'];
                                            final d = DateTime.tryParse(
                                                fechaRaw?.toString() ?? '');
                                            if (d != null) {
                                              desde = (desde == null ||
                                                      d.isBefore(desde!))
                                                  ? d
                                                  : desde;
                                              hasta = (hasta == null ||
                                                      d.isAfter(hasta!))
                                                  ? d
                                                  : hasta;
                                            }
                                            final id = v['id']?.toString();
                                            if (id != null &&
                                                id.isNotEmpty) {
                                              ids.add(id);
                                            }
                                          }

                                          final update = <String, dynamic>{
                                            'totalPendiente': _totalPendiente,
                                            'cantidadEntregas':
                                                _ventas.length,
                                            'textoResumen': texto,
                                            'ventaIds': ids,
                                            'updatedAt':
                                                FieldValue.serverTimestamp(),
                                          };
                                          update['tipoPeriodo'] =
                                              tipoPeriodoSeleccionado;
                                          if (desde != null) {
                                            update['periodoDesde'] =
                                                desde!.toIso8601String();
                                          }
                                          if (hasta != null) {
                                            update['periodoHasta'] =
                                                hasta!.toIso8601String();
                                          }

                                          try {
                                            final idResumen =
                                                resumenAbierto['id']
                                                        ?.toString() ??
                                                    '';
                                            if (idResumen.isEmpty) return;
                                            await widget.firestoreRepo
                                                .resumenesCobro
                                                .doc(idResumen)
                                                .update(update);
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Resumen actualizado'),
                                              ),
                                            );
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ResumenCobroDetalleScreen(
                                                  firestoreRepo:
                                                      widget.firestoreRepo,
                                                  resumenId: idResumen,
                                                ),
                                              ),
                                            );
                                          } catch (e) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Error al actualizar resumen: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                          return;
                                        } else if (decision == 'cancelar' ||
                                            decision == null) {
                                          return;
                                        }
                                        // Si decision == 'crear', continúa flujo normal.
                                      }

                                      final tipoPeriodoNuevo =
                                          await _pedirTipoPeriodo(
                                              valorActual: 'manual');
                                      if (tipoPeriodoNuevo == null) {
                                        return;
                                      }

                                      final texto = _generarTextoResumen();

                                      DateTime? desde;
                                      DateTime? hasta;
                                      final ids = <String>[];
                                      for (final v in _ventas) {
                                        final fechaRaw = v['fecha'];
                                        final d = DateTime.tryParse(
                                            fechaRaw?.toString() ?? '');
                                        if (d != null) {
                                          desde = (desde == null ||
                                                  d.isBefore(desde!))
                                              ? d
                                              : desde;
                                          hasta = (hasta == null ||
                                                  d.isAfter(hasta!))
                                              ? d
                                              : hasta;
                                        }
                                        final id = v['id']?.toString();
                                        if (id != null && id.isNotEmpty) {
                                          ids.add(id);
                                        }
                                      }

                                      final data = <String, dynamic>{
                                        'clienteId': widget.clienteId,
                                        'clienteNombre':
                                            widget.clienteNombre,
                                        'totalPendiente': _totalPendiente,
                                        'cantidadEntregas': _ventas.length,
                                        'textoResumen': texto,
                                        'estado': 'borrador',
                                        'ventaIds': ids,
                                        'tipoPeriodo': tipoPeriodoNuevo,
                                      };
                                      if (desde != null) {
                                        data['periodoDesde'] =
                                            desde!.toIso8601String();
                                      }
                                      if (hasta != null) {
                                        data['periodoHasta'] =
                                            hasta!.toIso8601String();
                                      }

                                      try {
                                        await widget.firestoreRepo
                                            .guardarResumenCobro(data);
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('Resumen guardado'),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Error al guardar resumen: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                              icon: const Icon(Icons.save),
                              label: const Text('Guardar resumen'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _ventas.isEmpty ? null : _marcarComoPagado,
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Marcar como pagado'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _ventas.isEmpty
                            ? const Center(
                                child:
                                    Text('No hay entregas abiertas para este cliente'),
                              )
                            : ListView.separated(
                                itemCount: _ventas.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 8),
                                itemBuilder: (context, index) {
                                  final v = _ventas[index];
                                  final fechaLabel =
                                      _formatearFechaHora(v['fecha']);

                                  final items =
                                      (v['items'] as List?) ?? const [];
                                  String cultivo = '';
                                  int cantidad = 0;
                                  double precioUnitario = 0;
                                  if (items.isNotEmpty) {
                                    final item = items.first;
                                    if (item is Map) {
                                      cultivo =
                                          item['cultivoKey']?.toString() ?? '';
                                      final cantRaw = item['cantidad'];
                                      if (cantRaw is num) {
                                        cantidad = cantRaw.toInt();
                                      }
                                      final precioRaw = item['precioUnitario'];
                                      if (precioRaw is num) {
                                        precioUnitario =
                                            precioRaw.toDouble();
                                      }
                                    }
                                  }

                                  final totalRaw = v['total'];
                                  final total = (totalRaw is num)
                                      ? totalRaw.toDouble()
                                      : 0.0;
                                  final idVenta = v['id']?.toString() ?? '';
                                  final incluidaEnResumenAbierto =
                                      _ventaIdsResumenAbierto
                                          .contains(idVenta);

                                  return ListTile(
                                    title: Text(
                                      cultivo,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (fechaLabel.isNotEmpty)
                                          Text(fechaLabel),
                                        Text(
                                            'Cantidad: $cantidad  Precio: ${_formatoMoneda.format(precioUnitario)}'),
                                        if (incluidaEnResumenAbierto)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4.0),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.receipt_long,
                                                  size: 16,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'En resumen abierto',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: Text(
                                      _formatoMoneda.format(total),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

