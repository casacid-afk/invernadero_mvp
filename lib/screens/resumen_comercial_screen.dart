import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/invernadero_firestore_repo.dart';

enum _PeriodoComercial {
  historico,
  hoy,
  sieteDias,
  treintaDias,
  esteMes,
  esteAnio,
  personalizado,
}

class ResumenComercialScreen extends StatefulWidget {
  final InvernaderoFirestoreRepo firestoreRepo;

  const ResumenComercialScreen({
    super.key,
    required this.firestoreRepo,
  });

  @override
  State<ResumenComercialScreen> createState() => _ResumenComercialScreenState();
}

class _ResumenComercialScreenState extends State<ResumenComercialScreen> {
  final NumberFormat _formatoMoneda = NumberFormat.currency(
    locale: 'es_CL',
    symbol: r'$ ',
    decimalDigits: 0,
  );

  bool _cargando = false;
  String? _error;

  double _vendidoTotal = 0;
  double _cobradoTotal = 0;
  double _pendienteTotal = 0;

  String? _clienteTopNombre;
  double _clienteTopMonto = 0;

  String? _mejorMesLabel;
  double _mejorMesMonto = 0;

  List<_MesVentas> _ventasPorMes = [];
  List<_ClienteVentas> _topClientes = [];
  List<_MedioPagoResumen> _totalesPorMedioPago = [];

  _PeriodoComercial _periodo = _PeriodoComercial.historico;
  List<int> _aniosDisponibles = [];
  int? _anioManual;
  int _mesManual = 0; // 0 = Todos, 1-12 = meses

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final snapshot = await widget.firestoreRepo.ventas.get();
      final ventasRaw = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      double vendidoTotal = 0;
      double cobradoTotal = 0;
      double pendienteTotal = 0;

      final Map<String, double> ventasPorCliente = {};
      final Map<String, String> nombrePorCliente = {};
      final Map<String, double> ventasPorMes = {};
      final Map<String, double> ventasPorMedioPago = {};
      final List<Map<String, dynamic>> ventasFiltradas = [];
      final Set<int> anios = {};

      DateTime? _parseFecha(dynamic fechaRaw) {
        if (fechaRaw == null) return null;
        if (fechaRaw is Timestamp) return fechaRaw.toDate();
        if (fechaRaw is DateTime) return fechaRaw;
        return DateTime.tryParse(fechaRaw.toString());
      }

      bool _estaEnPeriodo(DateTime? fecha) {
        if (fecha == null) return _periodo == _PeriodoComercial.historico;
        final ahora = DateTime.now();
        final hoy = DateTime(ahora.year, ahora.month, ahora.day);
        switch (_periodo) {
          case _PeriodoComercial.historico:
            return true;
          case _PeriodoComercial.hoy:
            return fecha.year == hoy.year &&
                fecha.month == hoy.month &&
                fecha.day == hoy.day;
          case _PeriodoComercial.sieteDias:
            final inicio = hoy.subtract(const Duration(days: 6));
            return !fecha.isBefore(inicio) && !fecha.isAfter(ahora);
          case _PeriodoComercial.treintaDias:
            final inicio = hoy.subtract(const Duration(days: 29));
            return !fecha.isBefore(inicio) && !fecha.isAfter(ahora);
          case _PeriodoComercial.esteMes:
            final inicioMes = DateTime(ahora.year, ahora.month, 1);
            final inicioMesSiguiente = DateTime(
              ahora.year,
              ahora.month + 1,
              1,
            );
            return !fecha.isBefore(inicioMes) &&
                fecha.isBefore(inicioMesSiguiente);
          case _PeriodoComercial.esteAnio:
            final inicioAnio = DateTime(ahora.year, 1, 1);
            final inicioAnioSiguiente = DateTime(ahora.year + 1, 1, 1);
            return !fecha.isBefore(inicioAnio) &&
                fecha.isBefore(inicioAnioSiguiente);
          case _PeriodoComercial.personalizado:
            final anio = _anioManual;
            if (anio == null) return false;
            if (fecha.year != anio) return false;
            if (_mesManual == 0) return true;
            return fecha.month == _mesManual;
        }
      }

      for (final v in ventasRaw) {
        final fecha = _parseFecha(v['fecha']);
        if (fecha != null) {
          anios.add(fecha.year);
        }
        if (!_estaEnPeriodo(fecha)) continue;
        ventasFiltradas.add(v);

        final totalRaw = v['total'];
        final total = (totalRaw is num) ? totalRaw.toDouble() : 0.0;
        vendidoTotal += total;

        final medioPago = v['medioPago']?.toString();
        final estadoCobro = v['estadoCobro']?.toString();
        final clienteId = v['clienteId']?.toString();
        final clienteNombre = v['clienteNombre']?.toString();

        // Cobrado: todo lo que no es crédito, más crédito ya pagado
        final esCredito = medioPago == 'credito';
        final esCreditoAbierto = esCredito && estadoCobro == 'abierta';
        if (!esCredito || (esCredito && estadoCobro == 'pagada')) {
          cobradoTotal += total;
        }
        if (esCreditoAbierto) {
          pendienteTotal += total;
        }

        // Cliente top: sumar por clienteId (o por nombre si no hay id)
        final claveCliente = (clienteId != null && clienteId.isNotEmpty)
            ? clienteId
            : clienteNombre ?? 'sin_id';
        ventasPorCliente[claveCliente] =
            (ventasPorCliente[claveCliente] ?? 0) + total;
        if (clienteNombre != null && clienteNombre.trim().isNotEmpty) {
          nombrePorCliente[claveCliente] = clienteNombre.trim();
        }

        // Ventas por mes
        if (fecha != null) {
          final claveMes =
              '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}';
          ventasPorMes[claveMes] = (ventasPorMes[claveMes] ?? 0) + total;
        }

        // Totales por medio de pago
        final claveMedio = medioPago ?? 'desconocido';
        ventasPorMedioPago[claveMedio] =
            (ventasPorMedioPago[claveMedio] ?? 0) + total;
      }

      // Cliente top
      String? clienteTopClave;
      double clienteTopMonto = 0;
      ventasPorCliente.forEach((clave, monto) {
        if (monto > clienteTopMonto) {
          clienteTopMonto = monto;
          clienteTopClave = clave;
        }
      });
      final clienteTopNombre =
          (clienteTopClave != null && nombrePorCliente[clienteTopClave] != null)
              ? nombrePorCliente[clienteTopClave]
              : clienteTopClave;

      // Mejor mes
      String? mejorMesClave;
      double mejorMesMonto = 0;
      ventasPorMes.forEach((mes, monto) {
        if (monto > mejorMesMonto) {
          mejorMesMonto = monto;
          mejorMesClave = mes;
        }
      });
      String? mejorMesLabel;
      if (mejorMesClave != null) {
        final partes = mejorMesClave.split('-');
        if (partes.length == 2) {
          final year = int.tryParse(partes[0]);
          final month = int.tryParse(partes[1]);
          if (year != null && month != null) {
            final fechaMes = DateTime(year, month, 1);
            mejorMesLabel = DateFormat('MMMM yyyy', 'es_CL').format(fechaMes);
          }
        }
        mejorMesLabel ??= mejorMesClave;
      }

      // Listas derivadas
      final ventasPorMesLista = ventasPorMes.entries
          .map((e) => _MesVentas(mesClave: e.key, monto: e.value))
          .toList()
        ..sort((a, b) => a.fechaMes.compareTo(b.fechaMes));

      final clientesLista = ventasPorCliente.entries
          .map((e) => _ClienteVentas(
                clienteClave: e.key,
                nombre: nombrePorCliente[e.key] ?? e.key,
                monto: e.value,
              ))
          .toList()
        ..sort((a, b) => b.monto.compareTo(a.monto));
      final topClientes =
          clientesLista.length <= 5 ? clientesLista : clientesLista.sublist(0, 5);

      final mediosLista = ventasPorMedioPago.entries
          .map((e) => _MedioPagoResumen(medio: e.key, monto: e.value))
          .toList()
        ..sort((a, b) => b.monto.compareTo(a.monto));

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
        _vendidoTotal = vendidoTotal;
        _cobradoTotal = cobradoTotal;
        _pendienteTotal = pendienteTotal;
        _clienteTopNombre = clienteTopNombre;
        _clienteTopMonto = clienteTopMonto;
        _mejorMesLabel = mejorMesLabel;
        _mejorMesMonto = mejorMesMonto;
        _ventasPorMes = ventasPorMesLista;
        _topClientes = topClientes;
        _totalesPorMedioPago = mediosLista;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al cargar resumen comercial: $e';
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
        title: const Text('Resumen comercial'),
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
                        _buildFiltroPeriodo(context),
                        if (_periodo == _PeriodoComercial.personalizado) ...[
                          const SizedBox(height: 12),
                          _buildSeleccionManualPeriodo(context),
                        ],
                        const SizedBox(height: 16),
                        _buildResumenSuperior(context),
                        const SizedBox(height: 16),
                        _buildVentasPorMes(context),
                        const SizedBox(height: 16),
                        _buildTopClientes(context),
                        const SizedBox(height: 16),
                        _buildTotalesPorMedioPago(context),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildResumenSuperior(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildCardResumen(
                context,
                titulo: 'Vendido total',
                monto: _vendidoTotal,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCardResumen(
                context,
                titulo: 'Cobrado total',
                monto: _cobradoTotal,
                color: Colors.green[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildCardResumen(
                context,
                titulo: 'Pendiente por cobrar',
                monto: _pendienteTotal,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCardClienteTop(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildCardMejorMes(context),
      ],
    );
  }

  Widget _buildCardResumen(
    BuildContext context, {
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

  Widget _buildCardClienteTop(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cliente top (vendido)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (_clienteTopNombre == null)
              Text(
                'Sin datos',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else ...[
              Text(
                _clienteTopNombre!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatoMoneda.format(_clienteTopMonto),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardMejorMes(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mejor mes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (_mejorMesLabel == null)
              Text(
                'Sin datos',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else ...[
              Text(
                _mejorMesLabel!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatoMoneda.format(_mejorMesMonto),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVentasPorMes(BuildContext context) {
    if (_ventasPorMes.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Sin datos de ventas por mes.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ventas por mes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _ventasPorMes.length,
              separatorBuilder: (_, __) => const Divider(height: 8),
              itemBuilder: (context, index) {
                final m = _ventasPorMes[index];
                final label = m.labelMes('es_CL');
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: Text(
                    _formatoMoneda.format(m.monto),
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

  Widget _buildTopClientes(BuildContext context) {
    if (_topClientes.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Sin datos de clientes.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top 5 clientes por monto vendido',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _topClientes.length,
              separatorBuilder: (_, __) => const Divider(height: 8),
              itemBuilder: (context, index) {
                final c = _topClientes[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),
                  title: Text(
                    c.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: Text(
                    _formatoMoneda.format(c.monto),
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

  Widget _buildTotalesPorMedioPago(BuildContext context) {
    if (_totalesPorMedioPago.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Sin datos por medio de pago.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Totales por medio de pago',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _totalesPorMedioPago.length,
              separatorBuilder: (_, __) => const Divider(height: 8),
              itemBuilder: (context, index) {
                final m = _totalesPorMedioPago[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    m.medio,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: Text(
                    _formatoMoneda.format(m.monto),
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
}

class _MesVentas {
  _MesVentas({required this.mesClave, required this.monto});

  final String mesClave; // 'YYYY-MM'
  final double monto;

  DateTime get fechaMes {
    final partes = mesClave.split('-');
    if (partes.length == 2) {
      final year = int.tryParse(partes[0]);
      final month = int.tryParse(partes[1]);
      if (year != null && month != null) {
        return DateTime(year, month, 1);
      }
    }
    return DateTime(1900, 1, 1);
  }

  String labelMes(String locale) {
    final partes = mesClave.split('-');
    if (partes.length == 2) {
      final year = int.tryParse(partes[0]);
      final month = int.tryParse(partes[1]);
      if (year != null && month != null) {
        final fechaMes = DateTime(year, month, 1);
        return DateFormat('MMMM yyyy', locale).format(fechaMes);
      }
    }
    return mesClave;
  }
}

class _ClienteVentas {
  _ClienteVentas({
    required this.clienteClave,
    required this.nombre,
    required this.monto,
  });

  final String clienteClave;
  final String nombre;
  final double monto;
}

extension on _ResumenComercialScreenState {
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
              _cargar();
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
              _cargar();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFiltroPeriodo(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Histórico'),
          selected: _periodo == _PeriodoComercial.historico,
          onSelected: (_) {
            setState(() {
              _periodo = _PeriodoComercial.historico;
            });
            _cargar();
          },
        ),
        ChoiceChip(
          label: const Text('Hoy'),
          selected: _periodo == _PeriodoComercial.hoy,
          onSelected: (_) {
            setState(() {
              _periodo = _PeriodoComercial.hoy;
            });
            _cargar();
          },
        ),
        ChoiceChip(
          label: const Text('7D'),
          selected: _periodo == _PeriodoComercial.sieteDias,
          onSelected: (_) {
            setState(() {
              _periodo = _PeriodoComercial.sieteDias;
            });
            _cargar();
          },
        ),
        ChoiceChip(
          label: const Text('30D'),
          selected: _periodo == _PeriodoComercial.treintaDias,
          onSelected: (_) {
            setState(() {
              _periodo = _PeriodoComercial.treintaDias;
            });
            _cargar();
          },
        ),
        ChoiceChip(
          label: const Text('Este mes'),
          selected: _periodo == _PeriodoComercial.esteMes,
          onSelected: (_) {
            setState(() {
              _periodo = _PeriodoComercial.esteMes;
            });
            _cargar();
          },
        ),
        ChoiceChip(
          label: const Text('Este año'),
          selected: _periodo == _PeriodoComercial.esteAnio,
          onSelected: (_) {
            setState(() {
              _periodo = _PeriodoComercial.esteAnio;
            });
            _cargar();
          },
        ),
        ChoiceChip(
          label: const Text('Elegir período'),
          selected: _periodo == _PeriodoComercial.personalizado,
          onSelected: (_) {
            setState(() {
              _periodo = _PeriodoComercial.personalizado;
            });
            _cargar();
          },
        ),
      ],
    );
  }
}

class _MedioPagoResumen {
  _MedioPagoResumen({required this.medio, required this.monto});

  final String medio;
  final double monto;
}

