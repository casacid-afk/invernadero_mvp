import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/invernadero_firestore_repo.dart';
import 'cuenta_cliente_detalle_screen.dart';
import 'resumen_cobro_detalle_screen.dart';

class CuentasPorCobrarScreen extends StatefulWidget {
  final InvernaderoFirestoreRepo firestoreRepo;

  const CuentasPorCobrarScreen({
    super.key,
    required this.firestoreRepo,
  });

  @override
  State<CuentasPorCobrarScreen> createState() =>
      _CuentasPorCobrarScreenState();
}

class _CuentasPorCobrarScreenState extends State<CuentasPorCobrarScreen> {
  final NumberFormat _formatoMoneda = NumberFormat.currency(
    locale: 'es_CL',
    symbol: r'$ ',
    decimalDigits: 0,
  );
  final DateFormat _formatoFechaCorta = DateFormat('dd-MM', 'es_CL');

  bool _cargando = false;
  String? _error;

  /// Elementos agregados por cliente: nombre, entregas abiertas y total pendiente.
  List<_ResumenClienteCredito> _resumenes = [];

  @override
  void initState() {
    super.initState();
    _cargarCuentas();
  }

  String _formatearFechaCorta(dynamic createdAt) {
    if (createdAt == null) return '';
    if (createdAt is Timestamp) {
      return _formatoFechaCorta.format(createdAt.toDate());
    }
    if (createdAt is DateTime) {
      return _formatoFechaCorta.format(createdAt);
    }
    final d = DateTime.tryParse(createdAt.toString());
    if (d == null) return '';
    return _formatoFechaCorta.format(d);
  }

  Future<void> _cargarCuentas() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final ventas =
          await widget.firestoreRepo.obtenerVentasCreditoAbiertas();

      final Map<String, _ResumenClienteCredito> agrupado = {};

      for (final v in ventas) {
        final clienteId = v['clienteId']?.toString();
        if (clienteId == null || clienteId.isEmpty) {
          continue;
        }
        final nombre =
            (v['clienteNombre']?.toString().trim().isNotEmpty ?? false)
                ? v['clienteNombre'].toString().trim()
                : 'Cliente sin nombre';
        final totalRaw = v['total'];
        final total = (totalRaw is num) ? totalRaw.toDouble() : 0.0;

        final existente = agrupado[clienteId];
        if (existente == null) {
          agrupado[clienteId] = _ResumenClienteCredito(
            clienteId: clienteId,
            nombre: nombre,
            entregasAbiertas: 1,
            totalPendiente: total,
          );
        } else {
          existente.entregasAbiertas += 1;
          existente.totalPendiente += total;
        }
      }

      final lista = agrupado.values.toList();

      // Para cada cliente con deuda, obtener el resumen de cobro ABIERTO más reciente (si existe)
      for (final resumen in lista) {
        try {
          final snapshot = await widget.firestoreRepo.resumenesCobro
              .where('clienteId', isEqualTo: resumen.clienteId)
              .orderBy('createdAt', descending: true)
              .limit(10)
              .get();
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final estado = data['estado']?.toString();
            if (estado != 'pagado') {
              resumen.tieneResumenAbierto = true;
              resumen.resumenAbiertoCreatedAt = data['createdAt'];
              resumen.resumenAbiertoId = doc.id;
              break;
            }
          }
        } catch (_) {
          // Si falla la lectura de resúmenes, simplemente no marcamos indicador.
        }
      }

      // Orden: total pendiente desc, luego nombre asc
      lista.sort((a, b) {
        final cmpTotal = b.totalPendiente.compareTo(a.totalPendiente);
        if (cmpTotal != 0) return cmpTotal;
        return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
      });

      if (!mounted) return;

      setState(() {
        _resumenes = lista;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al cargar cuentas por cobrar: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Cuentas por cobrar'),
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
                : _resumenes.isEmpty
                    ? const Center(
                        child: Text('No hay cuentas por cobrar'),
                      )
                    : ListView.separated(
                        itemCount: _resumenes.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 8),
                        itemBuilder: (context, index) {
                          final r = _resumenes[index];
                          final indicadorResumenAbierto = r.tieneResumenAbierto
                              ? _formatearFechaCorta(
                                  r.resumenAbiertoCreatedAt,
                                )
                              : '';
                          final lineas = <String>[
                            'Entregas abiertas: ${r.entregasAbiertas}',
                            'Total pendiente: ${_formatoMoneda.format(r.totalPendiente)}',
                          ];
                          if (indicadorResumenAbierto.isNotEmpty) {
                            lineas.add('Resumen abierto: $indicadorResumenAbierto');
                          }

                          return ListTile(
                            title: Text(
                              r.nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(lineas.join('\n')),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (r.tieneResumenAbierto &&
                                    (r.resumenAbiertoId?.isNotEmpty ?? false))
                                  IconButton(
                                    icon: const Icon(Icons.receipt_long),
                                    tooltip: 'Ver resumen abierto',
                                    onPressed: () async {
                                      final id = r.resumenAbiertoId!;
                                      final refrescar =
                                          await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ResumenCobroDetalleScreen(
                                            firestoreRepo: widget.firestoreRepo,
                                            resumenId: id,
                                          ),
                                        ),
                                      );
                                      if (refrescar == true) {
                                        _cargarCuentas();
                                      }
                                    },
                                  ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () async {
                              final refrescar = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => CuentaClienteDetalleScreen(
                                    firestoreRepo: widget.firestoreRepo,
                                    clienteId: r.clienteId,
                                    clienteNombre: r.nombre,
                                  ),
                                ),
                              );
                              if (refrescar == true) {
                                _cargarCuentas();
                              }
                            },
                          );
                        },
                      ),
      ),
    );
  }
}

class _ResumenClienteCredito {
  _ResumenClienteCredito({
    required this.clienteId,
    required this.nombre,
    required this.entregasAbiertas,
    required this.totalPendiente,
    this.tieneResumenAbierto = false,
    this.resumenAbiertoCreatedAt,
    this.resumenAbiertoId,
  });

  final String clienteId;
  final String nombre;
  int entregasAbiertas;
  double totalPendiente;
  bool tieneResumenAbierto;
  dynamic resumenAbiertoCreatedAt;
  String? resumenAbiertoId;
}


