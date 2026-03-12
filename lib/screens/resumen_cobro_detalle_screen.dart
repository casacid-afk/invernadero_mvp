import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../data/invernadero_firestore_repo.dart';

class ResumenCobroDetalleScreen extends StatefulWidget {
  final InvernaderoFirestoreRepo firestoreRepo;
  final String resumenId;

  const ResumenCobroDetalleScreen({
    super.key,
    required this.firestoreRepo,
    required this.resumenId,
  });

  @override
  State<ResumenCobroDetalleScreen> createState() =>
      _ResumenCobroDetalleScreenState();
}

class _ResumenCobroDetalleScreenState
    extends State<ResumenCobroDetalleScreen> {
  final NumberFormat _formatoMoneda = NumberFormat.currency(
    locale: 'es_CL',
    symbol: r'$ ',
    decimalDigits: 0,
  );

  bool _cargando = false;
  String? _error;
  Map<String, dynamic>? _resumen;
  bool _huboCambios = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  String _construirTextoPlanoResumen() {
    final resumen = _resumen;
    if (resumen == null) return '';

    final buffer = StringBuffer();
    buffer.writeln('Resumen de cobro');
    buffer.writeln();

    final cliente = resumen['clienteNombre']?.toString() ?? '';
    if (cliente.isNotEmpty) {
      buffer.writeln('Cliente: $cliente');
    }

    final fechaStr = _formatearFecha(resumen['createdAt']);
    if (fechaStr.isNotEmpty) {
      buffer.writeln('Fecha: $fechaStr');
    }

    final totalRaw = resumen['totalPendiente'];
    final total = (totalRaw is num) ? totalRaw.toDouble() : 0.0;
    buffer.writeln('Total: ${_formatoMoneda.format(total)}');

    final estado = resumen['estado']?.toString();
    if (estado != null && estado.isNotEmpty) {
      buffer.writeln('Estado: $estado');
    }

    final observacion = resumen['observacion']?.toString() ?? '';
    if (observacion.trim().isNotEmpty) {
      buffer.writeln('Observación: $observacion');
    }

    buffer.writeln();
    buffer.writeln('Entregas incluidas');

    final textoEntregas = resumen['textoResumen']?.toString().trim() ?? '';
    if (textoEntregas.isNotEmpty) {
      buffer.writeln(textoEntregas);
    }

    return buffer.toString();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final doc = await widget.firestoreRepo.resumenesCobro
          .doc(widget.resumenId)
          .get();
      if (!doc.exists || doc.data() == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Resumen no encontrado';
        });
      } else {
        if (!mounted) return;
        setState(() {
          _resumen = {
            'id': doc.id,
            ...doc.data()!,
          };
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al cargar resumen: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  Future<void> _copiarTexto() async {
    final texto = _construirTextoPlanoResumen();
    if (texto.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resumen copiado')),
    );
  }

  Future<void> _compartirTexto() async {
    final texto = _construirTextoPlanoResumen();
    if (texto.isEmpty) return;
    await Share.share(texto);
  }

  Future<void> _marcarResumenComoPagado() async {
    if (_resumen == null) return;

    String medioPago = 'efectivo';
    String observacion = '';

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Marcar resumen como pagado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: medioPago,
                decoration: const InputDecoration(
                  labelText: 'Medio de pago',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'efectivo',
                    child: Text('Efectivo'),
                  ),
                  DropdownMenuItem(
                    value: 'transferencia',
                    child: Text('Transferencia'),
                  ),
                  DropdownMenuItem(
                    value: 'credito',
                    child: Text('Crédito'),
                  ),
                  DropdownMenuItem(
                    value: 'otro',
                    child: Text('Otro'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    medioPago = value;
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Observación de pago (opcional)',
                ),
                maxLines: 2,
                onChanged: (value) {
                  observacion = value;
                },
              ),
            ],
          ),
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

    if (resultado != true) return;

    try {
      final ok = await widget.firestoreRepo.marcarResumenCobroComoPagado(
        widget.resumenId,
        medioPago: medioPago,
        observacionPago: observacion,
      );
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No se encontró el resumen de cobro para marcar como pagado'),
          ),
        );
        return;
      }
      await _cargar();
      if (!mounted) return;
      _huboCambios = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resumen marcado como pagado')),
      );
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

  String _formatearFecha(dynamic createdAt) {
    if (createdAt == null) return '';
    if (createdAt is Timestamp) {
      return DateFormat('dd-MM-yyyy HH:mm', 'es_CL')
          .format(createdAt.toDate());
    }
    if (createdAt is DateTime) {
      return DateFormat('dd-MM-yyyy HH:mm', 'es_CL').format(createdAt);
    }
    final d = DateTime.tryParse(createdAt.toString());
    if (d == null) return '';
    return DateFormat('dd-MM-yyyy HH:mm', 'es_CL').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final resumen = _resumen;
    final ventasIds = (resumen?['ventaIds'] as List?) ?? const [];
    final bool tieneTrazabilidad =
        ventasIds.isNotEmpty;

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_huboCambios);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title:
              Text(resumen?['clienteNombre']?.toString() ?? 'Resumen de cobro'),
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
                : resumen == null
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    resumen['clienteNombre']
                                            ?.toString() ??
                                        '',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  if (resumen['createdAt'] != null)
                                    Text(
                                      'Fecha: ${_formatearFecha(resumen['createdAt'])}',
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Total pendiente: ${_formatoMoneda.format((resumen['totalPendiente'] is num) ? (resumen['totalPendiente'] as num).toDouble() : 0.0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (resumen['cantidadEntregas'] != null)
                                    Text(
                                      'Entregas: ${resumen['cantidadEntregas']}',
                                    ),
                                  const SizedBox(height: 4),
                                  if (resumen['tipoPeriodo'] != null)
                                    Text('Período: ${resumen['tipoPeriodo']}'),
                                  const SizedBox(height: 4),
                                  if (resumen['estado'] != null)
                                    Text('Estado: ${resumen['estado']}'),
                                  const SizedBox(height: 4),
                                  if ((resumen['observacion']?.toString() ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    Text(
                                      'Observación: ${resumen['observacion']}',
                                    ),
                                  const SizedBox(height: 4),
                                  if (resumen['estado']?.toString() == 'pagado') ...[
                                    if (resumen['fechaPago'] != null)
                                      Text(
                                        'Fecha de pago: ${_formatearFecha(resumen['fechaPago'])}',
                                      ),
                                    if ((resumen['medioPago']?.toString() ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      Text('Medio de pago: ${resumen['medioPago']}'),
                                    if ((resumen['observacionPago']?.toString() ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      Text(
                                        'Observación de pago: ${resumen['observacionPago']}',
                                      ),
                                  ],
                                  const SizedBox(height: 8),
                                  if (!tieneTrazabilidad)
                                    Text(
                                      'Este es un resumen antiguo sin trazabilidad completa de entregas. '
                                      'Las cuentas por cobrar no se actualizan automáticamente con este resumen.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.orange[800]),
                                    )
                                  else if (resumen['estado']?.toString() == 'pagado')
                                    Text(
                                      'Las entregas asociadas a este resumen fueron marcadas como pagadas '
                                      'en cuentas por cobrar.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.green[800]),
                                    )
                                  else
                                    Text(
                                      'Al marcar este resumen como pagado, se cerrarán las entregas asociadas '
                                      'en cuentas por cobrar.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.blueGrey[700]),
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
                                  onPressed: _copiarTexto,
                                  icon: const Icon(Icons.copy),
                                  label: const Text('Copiar'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _compartirTexto,
                                  icon: const Icon(Icons.share),
                                  label: const Text('Compartir texto'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (resumen['estado']?.toString() != 'pagado')
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _marcarResumenComoPagado,
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Marcar como pagado'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Text(
                            'Entregas incluidas',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                                ),
                              ),
                              child: SingleChildScrollView(
                                child: Text(
                                  resumen['textoResumen']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
        ),
      ),
    );
  }
}

