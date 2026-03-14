import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../data/invernadero_firestore_repo.dart';

enum _PeriodoResumen {
  historico,
  hoy,
  sieteDias,
  treintaDias,
  esteMes,
  esteAnio,
  personalizado,
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
  double _cobradoReal = 0;
  double _ingresosAnterior = 0;
  double _gastosAnterior = 0;
  double _creditoEmitidoAnterior = 0;
  double _cobradoRealAnterior = 0;
  bool _tieneComparacion = false;
  List<int> _aniosDisponibles = [];
  int? _anioManual;
  int _mesManual = 0; // 0 = Todos, 1-12 = meses

  List<Map<String, dynamic>> _ventasPeriodo = [];
  List<Map<String, dynamic>> _gastosPeriodo = [];

  @override
  void initState() {
    super.initState();
    _cargarResumen();
  }

  Future<void> _cargarResumen() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final ventasSnapshot = await widget.firestoreRepo.ventas.get();
      final gastosSnapshot = await widget.firestoreRepo.gastos.get();

      final ventasRaw = ventasSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
      final gastosRaw = gastosSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      DateTime? _parseFecha(dynamic fechaRaw) {
        if (fechaRaw == null) return null;
        if (fechaRaw is Timestamp) return fechaRaw.toDate().toLocal();
        if (fechaRaw is DateTime) return fechaRaw.toLocal();
        final parsed = DateTime.tryParse(fechaRaw.toString());
        return parsed?.toLocal();
      }

      bool _estaEnPeriodo(DateTime? fecha) {
        final ahora = DateTime.now();
        final hoy = DateTime(ahora.year, ahora.month, ahora.day);

        if (fecha == null) {
          return _periodo == _PeriodoResumen.historico;
        }

        switch (_periodo) {
          case _PeriodoResumen.historico:
            return true;
          case _PeriodoResumen.hoy:
            return fecha.year == hoy.year &&
                fecha.month == hoy.month &&
                fecha.day == hoy.day;
          case _PeriodoResumen.sieteDias:
            final inicio = hoy.subtract(const Duration(days: 6));
            return !fecha.isBefore(inicio) && !fecha.isAfter(ahora);
          case _PeriodoResumen.treintaDias:
            final inicio = hoy.subtract(const Duration(days: 29));
            return !fecha.isBefore(inicio) && !fecha.isAfter(ahora);
          case _PeriodoResumen.esteMes:
            return fecha.year == ahora.year && fecha.month == ahora.month;
          case _PeriodoResumen.esteAnio:
            return fecha.year == ahora.year;
          case _PeriodoResumen.personalizado:
            final anio = _anioManual ?? ahora.year;
            if (fecha.year != anio) return false;
            if (_mesManual == 0) return true;
            return fecha.month == _mesManual;
        }
      }

      double ingresos = 0;
      double creditoEmitido = 0;
      double cobradoReal = 0;
      final List<Map<String, dynamic>> ventasFiltradas = [];
      final Set<int> anios = {};

      for (final v in ventasRaw) {
        final fecha = _parseFecha(v['fecha']);
        if (fecha != null) {
          anios.add(fecha.year);
        }
        if (!_estaEnPeriodo(fecha)) continue;
        ventasFiltradas.add(v);

        final totalRaw = v['total'];
        final total = (totalRaw is num) ? totalRaw.toDouble() : 0.0;
        ingresos += total;
        if (v['medioPago'] == 'credito') {
          creditoEmitido += total;
        }
        final medioPago = v['medioPago']?.toString();
        final estadoCobro = v['estadoCobro']?.toString();
        final esCredito = medioPago == 'credito';
        if (!esCredito || (esCredito && estadoCobro == 'pagada')) {
          cobradoReal += total;
        }
      }

      double gastosTotal = 0;
      final List<Map<String, dynamic>> gastosFiltrados = [];
      for (final g in gastosRaw) {
        DateTime? fecha = _parseFecha(g['fecha']);
        if (fecha != null) {
          anios.add(fecha.year);
        }
        // Si la fecha del gasto no cae en el período seleccionado,
        // intentar usar createdAt como fecha económica de respaldo.
        if (!_estaEnPeriodo(fecha)) {
          final fallback = _parseFecha(g['createdAt']);
          if (!_estaEnPeriodo(fallback)) continue;
          fecha = fallback;
          if (fecha != null) {
            anios.add(fecha.year);
          }
        }
        gastosFiltrados.add(g);

        final montoRaw = g['monto'];
        final monto = (montoRaw is num) ? montoRaw.toDouble() : 0.0;
        gastosTotal += monto;
      }

      // Período anterior (no para Histórico)
      double ingresosAnterior = 0;
      double cobradoRealAnterior = 0;
      double gastosAnterior = 0;
      double creditoEmitidoAnterior = 0;
      bool tieneComparacion = false;

      if (_periodo != _PeriodoResumen.historico) {
        final ahoraRef = DateTime.now();
        final hoyRef = DateTime(ahoraRef.year, ahoraRef.month, ahoraRef.day);

        bool estaEnPeriodoAnterior(DateTime? fecha) {
          if (fecha == null) return false;
          switch (_periodo) {
            case _PeriodoResumen.hoy: {
              final ayer = hoyRef.subtract(const Duration(days: 1));
              return fecha.year == ayer.year &&
                  fecha.month == ayer.month &&
                  fecha.day == ayer.day;
            }
            case _PeriodoResumen.sieteDias: {
              final finAnterior = hoyRef.subtract(const Duration(days: 7));
              final inicioAnterior = hoyRef.subtract(const Duration(days: 14));
              return !fecha.isBefore(inicioAnterior) &&
                  !fecha.isAfter(finAnterior);
            }
            case _PeriodoResumen.treintaDias: {
              final finAnterior = hoyRef.subtract(const Duration(days: 30));
              final inicioAnterior = hoyRef.subtract(const Duration(days: 60));
              return !fecha.isBefore(inicioAnterior) &&
                  !fecha.isAfter(finAnterior);
            }
            case _PeriodoResumen.esteMes: {
              final py = ahoraRef.month == 1
                  ? ahoraRef.year - 1
                  : ahoraRef.year;
              final pm = ahoraRef.month == 1 ? 12 : ahoraRef.month - 1;
              return fecha.year == py && fecha.month == pm;
            }
            case _PeriodoResumen.esteAnio:
              return fecha.year == ahoraRef.year - 1;
            case _PeriodoResumen.personalizado: {
              final anio = _anioManual ?? ahoraRef.year;
              if (_mesManual == 0) return fecha.year == anio - 1;
              return fecha.year == anio - 1 && fecha.month == _mesManual;
            }
            default:
              return false;
          }
        }

        for (final v in ventasRaw) {
          final fecha = _parseFecha(v['fecha']);
          if (!estaEnPeriodoAnterior(fecha)) continue;
          final totalRaw = v['total'];
          final total = (totalRaw is num) ? totalRaw.toDouble() : 0.0;
          ingresosAnterior += total;
          if (v['medioPago'] == 'credito') {
            creditoEmitidoAnterior += total;
          }
          final medioPago = v['medioPago']?.toString();
          final estadoCobro = v['estadoCobro']?.toString();
          final esCredito = medioPago == 'credito';
          if (!esCredito || (esCredito && estadoCobro == 'pagada')) {
            cobradoRealAnterior += total;
          }
        }
        for (final g in gastosRaw) {
          DateTime? fecha = _parseFecha(g['fecha']);
          if (!estaEnPeriodoAnterior(fecha)) {
            final fallback = _parseFecha(g['createdAt']);
            if (!estaEnPeriodoAnterior(fallback)) continue;
            fecha = fallback;
          }
          final montoRaw = g['monto'];
          final monto = (montoRaw is num) ? montoRaw.toDouble() : 0.0;
          gastosAnterior += monto;
        }
        tieneComparacion = true;
      }

      // Ordenar ventas por fecha desc para debug de diferencias de período
      final ventasOrdenadas = List<Map<String, dynamic>>.from(ventasFiltradas);
      ventasOrdenadas.sort((a, b) {
        final fa = a['fecha'];
        final fb = b['fecha'];
        final da = _parseFecha(fa);
        final db = _parseFecha(fb);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });

      // Ordenar gastos por fecha desc y quedarnos con los últimos 10 para lista compacta
      gastosFiltrados.sort((a, b) {
        final fa = a['fecha'];
        final fb = b['fecha'];
        final da = _parseFecha(fa);
        final db = _parseFecha(fb);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });

      final ultimosGastos = gastosFiltrados.length <= 10
          ? gastosFiltrados
          : gastosFiltrados.sublist(0, 10);

      if (!mounted) return;

      final ahora = DateTime.now();
      final aniosLista = anios.toList()..sort();
      final aniosFinales =
          aniosLista.isEmpty ? <int>[ahora.year] : aniosLista;

      setState(() {
        _aniosDisponibles = aniosFinales;
        _anioManual ??= aniosFinales.contains(ahora.year)
            ? ahora.year
            : aniosFinales.first;
        _ingresos = ingresos;
        _gastos = gastosTotal;
        _creditoEmitido = creditoEmitido;
        _cobradoReal = cobradoReal;
        _ingresosAnterior = ingresosAnterior;
        _gastosAnterior = gastosAnterior;
        _creditoEmitidoAnterior = creditoEmitidoAnterior;
        _cobradoRealAnterior = cobradoRealAnterior;
        _tieneComparacion = tieneComparacion;
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
          label: const Text('Histórico'),
          selected: _periodo == _PeriodoResumen.historico,
          onSelected: (_) {
            setState(() {
              _periodo = _PeriodoResumen.historico;
            });
            _cargarResumen();
          },
        ),
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
        ChoiceChip(
          label: const Text('Este mes'),
          selected: _periodo == _PeriodoResumen.esteMes,
          onSelected: (_) {
            setState(() {
              _periodo = _PeriodoResumen.esteMes;
            });
            _cargarResumen();
          },
        ),
        ChoiceChip(
          label: const Text('Este año'),
          selected: _periodo == _PeriodoResumen.esteAnio,
          onSelected: (_) {
            setState(() {
              _periodo = _PeriodoResumen.esteAnio;
            });
            _cargarResumen();
          },
        ),
        ChoiceChip(
          label: const Text('Elegir período'),
          selected: _periodo == _PeriodoResumen.personalizado,
          onSelected: (_) {
            setState(() {
              _periodo = _PeriodoResumen.personalizado;
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
    double? montoAnterior,
  }) {
    final bool mostrarComparacion =
        _tieneComparacion && montoAnterior != null;
    final double diferencia = monto - (montoAnterior ?? 0);

    return Card(
      color: AppPastel.ventas.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppPastel.ventas.border, width: 1),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
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
            if (mostrarComparacion) ...[
              const SizedBox(height: 8),
              Text(
                'Período anterior: ${_formatoMoneda.format(montoAnterior!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[700],
                    ),
              ),
              Text(
                'Diferencia: ${_formatoMoneda.format(diferencia)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[700],
                    ),
              ),
              if (montoAnterior != 0) ...[
                Text(
                  _textoPorcentaje(diferencia, montoAnterior!),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[700],
                      ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _textoPorcentaje(double diferencia, double base) {
    if (base == 0) return '';
    final int pct = ((diferencia / base) * 100).round();
    if (pct > 0) return '+$pct%';
    if (pct < 0) return '$pct%';
    return '0%';
  }

  Widget _buildListaVentas() {
    if (_ventasPeriodo.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: AppPastel.ventas.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppPastel.ventas.border, width: 1),
      ),
      elevation: 0,
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
      color: AppPastel.ventas.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppPastel.ventas.border, width: 1),
      ),
      elevation: 0,
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

  Widget _buildSeleccionManualPeriodo(BuildContext context) {
    if (_aniosDisponibles.isEmpty) {
      return const SizedBox.shrink();
    }

    final anioActual = _anioManual ?? _aniosDisponibles.first;

    String _labelMes(int mes) {
      switch (mes) {
        case 1:
          return 'Enero';
        case 2:
          return 'Febrero';
        case 3:
          return 'Marzo';
        case 4:
          return 'Abril';
        case 5:
          return 'Mayo';
        case 6:
          return 'Junio';
        case 7:
          return 'Julio';
        case 8:
          return 'Agosto';
        case 9:
          return 'Septiembre';
        case 10:
          return 'Octubre';
        case 11:
          return 'Noviembre';
        case 12:
          return 'Diciembre';
        default:
          return 'Todos';
      }
    }

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            value: anioActual,
            items: _aniosDisponibles
                .map(
                  (anio) => DropdownMenuItem<int>(
                    value: anio,
                    child: Text(anio.toString()),
                  ),
                )
                .toList(),
            decoration: const InputDecoration(
              labelText: 'Año',
              border: OutlineInputBorder(),
            ),
            onChanged: (valor) {
              if (valor == null) return;
              setState(() {
                _anioManual = valor;
              });
              _cargarResumen();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _mesManual,
            items: [
              const DropdownMenuItem<int>(
                value: 0,
                child: Text('Todos'),
              ),
              for (var m = 1; m <= 12; m++)
                DropdownMenuItem<int>(
                  value: m,
                  child: Text(_labelMes(m)),
                ),
            ],
            decoration: const InputDecoration(
              labelText: 'Mes',
              border: OutlineInputBorder(),
            ),
            onChanged: (valor) {
              if (valor == null) return;
              setState(() {
                _mesManual = valor;
              });
              _cargarResumen();
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cajaNeta = _cobradoReal - _gastos;
    final cajaNetaAnterior = _cobradoRealAnterior - _gastosAnterior;

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
                        if (_periodo == _PeriodoResumen.personalizado) ...[
                          const SizedBox(height: 12),
                          _buildSeleccionManualPeriodo(context),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTarjetaResumen(
                                titulo: 'Vendido del período',
                                monto: _ingresos,
                                color: Colors.blue[700],
                                montoAnterior:
                                    _tieneComparacion ? _ingresosAnterior : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildTarjetaResumen(
                                titulo: 'Cobrado real del período',
                                monto: _cobradoReal,
                                color: Colors.green[700],
                                montoAnterior: _tieneComparacion
                                    ? _cobradoRealAnterior
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTarjetaResumen(
                                titulo: 'Gastos del período',
                                monto: _gastos,
                                color: Colors.red[700],
                                montoAnterior:
                                    _tieneComparacion ? _gastosAnterior : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildTarjetaResumen(
                                titulo: 'Caja neta del período',
                                monto: cajaNeta,
                                color: cajaNeta >= 0
                                    ? Colors.green[800]
                                    : Colors.red[800],
                                montoAnterior:
                                    _tieneComparacion ? cajaNetaAnterior : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildTarjetaResumen(
                          titulo: 'Crédito emitido del período',
                          monto: _creditoEmitido,
                          color: Colors.orange[700],
                          montoAnterior: _tieneComparacion
                              ? _creditoEmitidoAnterior
                              : null,
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

