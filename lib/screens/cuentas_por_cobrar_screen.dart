import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/invernadero_firestore_repo.dart';

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

  bool _cargando = false;
  String? _error;

  /// Elementos agregados por cliente: nombre, entregas abiertas y total pendiente.
  List<_ResumenClienteCredito> _resumenes = [];

  @override
  void initState() {
    super.initState();
    _cargarCuentas();
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
                          return ListTile(
                            title: Text(
                              r.nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Entregas abiertas: ${r.entregasAbiertas}\nTotal pendiente: ${_formatoMoneda.format(r.totalPendiente)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              // TODO(FASE 2D): Navegar al detalle de entregas abiertas por cliente.
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
  });

  final String clienteId;
  final String nombre;
  int entregasAbiertas;
  double totalPendiente;
}


