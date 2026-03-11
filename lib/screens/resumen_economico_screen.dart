import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/invernadero_firestore_repo.dart';

enum _PeriodoResumen {
  hoy,
  sieteDias,
  treintaDias,
}

class ResumenEconomicoScreen extends StatefulWidget {
  final InvernaderoFirestoreRepo firestoreRepo;

  const ResumenEconomicoScreen({
    super.key,
    required this.firestoreRepo,
  });

  @override
  State<ResumenEconomicoScreen> createState() => _ResumenEconomicoScreenState();
}

class _ResumenEconomicoScreenState extends State<ResumenEconomicoScreen> {
  final NumberFormat _formatoMoneda = NumberFormat.currency(
    locale: 'es_CL',
    symbol: r'$ ',
    decimalDigits: 0,
  );

  _PeriodoResumen _periodo = _PeriodoResumen.hoy;
  bool _cargando = false;
  String? _error;

  double _ingresos = 0;
  double _gastos = 0;
  double _creditoEmitido = 0;

  List<Map<String, dynamic>> _ventasPeriodo = [];
  List<Map<String, dynamic>> _gastosPeriodo = [];

  @override
  void initState() {
    super.initState();
    _cargarResumen();
  }

  DateTimeRange _calcularRango(_PeriodoResumen periodo) {
    final ahora = DateTime.now();
    final hoyInicio = DateTime(ahora.year, ahora.month, ahora.day);
    switch (periodo) {
      case _PeriodoResumen.hoy:
        return DateTimeRange(start: hoyInicio, end: ahora);
      case _PeriodoResumen.sieteDias:
        final inicio = hoyInicio.subtract(const Duration(days: 6));
        return DateTimeRange(start: inicio, end: ahora);
      case _PeriodoResumen.treintaDias:
        final inicio = hoyInicio.subtract(const Duration(days: 29));
        return DateTimeRange(start: inicio, end: ahora);
    }
  }

  Future<void> _cargarResumen() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final rango = _calcularRango(_periodo);

      final ventas = await widget.firestoreRepo.obtenerVentasEnRango(
        desde: rango.start,
        hasta: rango.end,
      );
      final gastos = await widget.firestoreRepo.obtenerGastosEnRango(
        desde: rango.start,
        hasta: rango.end,
      );

      double ingresos = 0;
      double creditoEmitido = 0;
      for (final v in ventas) {
        final totalRaw = v['total'];
        final total = (totalRaw is num) ? totalRaw.toDouble() : 0.0;
        ingresos += total;
        if (v['medioPago'] == 'credito') {
          creditoEmitido += total;
        }
      }

      double gastosTotal = 0;
      for (final g in gastos) {
        final montoRaw = g['monto'];
        final monto = (montoRaw is num) ? montoRaw.toDouble() : 0.0;
        gastosTotal += monto;
      }

      // Ordenar ventas por fecha desc para debug de diferencias de período
      final ventasOrdenadas = List<Map<String, dynamic>>.from(ventas);
      ventasOrdenadas.sort((a, b) {
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

      // Ordenar gastos por fecha desc y quedarnos con los últimos 10 para lista compacta
      gastos.sort((a, b) {
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

      final ultimosGastos =
          gastos.length <= 10 ? gastos : gastos.sublist(0, 10);

      if (!mounted) return;

      setState(() {
        _ingresos = ingresos;
        _gastos = gastosTotal;
        _creditoEmitido = creditoEmitido;
        _ventasPeriodo = ventasOrdenadas;
        _gastosPeriodo = ultimosGastos;
      });
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

  Widget _buildPeriodoChips() {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Hoy'),
          selected: _periodo == _PeriodoResumen.hoy,
          onSelected: (_) {
            setState(() {
              _periodo = _PeriodoResumen.hoy;
            });
            _cargarResumen();
          },
        ),
        ChoiceChip(
          label: const Text('7D'),
          selected: _periodo == _PeriodoResumen.sieteDias,
          onSelected: (_) {
            setState(() {
              _periodo = _PeriodoResumen.sieteDias;
            });
            _cargarResumen();
          },
        ),
        ChoiceChip(
          label: const Text('30D'),
          selected: _periodo == _PeriodoResumen.treintaDias,
          onSelected: (_) {
            setState(() {
              _periodo = _PeriodoResumen.treintaDias;
            });
            _cargarResumen();
          },
        ),
      ],
    );
  }

  Widget _buildTarjetaResumen({
    required String titulo,
    required double monto,
    Color? color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatoMoneda.format(monto),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaVentas() {
    if (_ventasPeriodo.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ventas del período',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _ventasPeriodo.length,
              separatorBuilder: (_, __) => const Divider(height: 8),
              itemBuilder: (context, index) {
                final v = _ventasPeriodo[index];
                final totalRaw = v['total'];
                final total =
                    (totalRaw is num) ? totalRaw.toDouble() : 0.0;
                final medioPago = v['medioPago']?.toString() ?? '';

                DateTime? fecha;
                final fechaRaw = v['fecha'];
                if (fechaRaw != null) {
                  fecha = DateTime.tryParse(fechaRaw.toString());
                }
                final fechaLabel = fecha != null
                    ? '${fecha.day.toString().padLeft(2, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.year}'
                    : '';

                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _formatoMoneda.format(total),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (fechaLabel.isNotEmpty)
                        Text(
                          fechaLabel,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey[700]),
                        ),
                      if (medioPago.isNotEmpty)
                        Text(
                          'Medio de pago: $medioPago',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey[700]),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaGastos() {
    if (_gastosPeriodo.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Últimos gastos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _gastosPeriodo.length,
              separatorBuilder: (_, __) => const Divider(height: 8),
              itemBuilder: (context, index) {
                final g = _gastosPeriodo[index];
                final descripcion = (g['descripcion'] as String?)?.trim();
                final categoria = g['categoria']?.toString() ?? '';
                final montoRaw = g['monto'];
                final monto =
                    (montoRaw is num) ? montoRaw.toDouble() : 0.0;

                DateTime? fecha;
                final fechaRaw = g['fecha'];
                if (fechaRaw != null) {
                  fecha = DateTime.tryParse(fechaRaw.toString());
                }
                final fechaLabel = fecha != null
                    ? '${fecha.day.toString().padLeft(2, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.year}'
                    : '';

                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    categoria,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (descripcion != null && descripcion.isNotEmpty)
                        Text(descripcion),
                      if (fechaLabel.isNotEmpty)
                        Text(
                          fechaLabel,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey[700]),
                        ),
                    ],
                  ),
                  trailing: Text(
                    _formatoMoneda.format(monto),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resultado = _ingresos - _gastos;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Resumen económico'),
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
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPeriodoChips(),
                        const SizedBox(height: 16),
                        _buildTarjetaResumen(
                          titulo: 'Ingresos',
                          monto: _ingresos,
                          color: Colors.green[700],
                        ),
                        _buildTarjetaResumen(
                          titulo: 'Gastos',
                          monto: _gastos,
                          color: Colors.red[700],
                        ),
                        _buildTarjetaResumen(
                          titulo: 'Resultado',
                          monto: resultado,
                          color: resultado >= 0
                              ? Colors.green[800]
                              : Colors.red[800],
                        ),
                        _buildTarjetaResumen(
                          titulo: 'Crédito emitido',
                          monto: _creditoEmitido,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(height: 16),
                        _buildListaVentas(),
                        const SizedBox(height: 16),
                        _buildListaGastos(),
                      ],
                    ),
                  ),
      ),
    );
  }
}

