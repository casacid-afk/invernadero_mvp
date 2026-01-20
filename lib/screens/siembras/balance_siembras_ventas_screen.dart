import 'package:flutter/material.dart';

import '../../domain/motor_invernadero.dart';
import '../../domain/movimiento.dart';
import '../../domain/cultivos.dart';

class BalanceSiembrasVentasScreen extends StatefulWidget {
  final MotorInvernadero motor;

  const BalanceSiembrasVentasScreen({
    super.key,
    required this.motor,
  });

  @override
  State<BalanceSiembrasVentasScreen> createState() =>
      _BalanceSiembrasVentasScreenState();
}

class _BalanceSiembrasVentasScreenState
    extends State<BalanceSiembrasVentasScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _periodoSeleccionado = 0; // 0 = 7 días, 1 = 30 días

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _periodoSeleccionado = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _obtenerDiasPeriodo() {
    return _periodoSeleccionado == 0 ? 7 : 30;
  }

  DateTime _obtenerFechaInicio() {
    final ahora = DateTime.now();
    final dias = _obtenerDiasPeriodo();
    return ahora.subtract(Duration(days: dias));
  }

  String? _obtenerCultivoKeyDeLote(String loteId) {
    try {
      final lote = widget.motor.lotes.firstWhere((l) => l.id == loteId);
      return lote.cultivoKey;
    } catch (_) {
      return null;
    }
  }

  Map<String, BalanceCultivo> _calcularBalancePorCultivo() {
    final fechaInicio = _obtenerFechaInicio();
    final ahora = DateTime.now();

    final balance = <String, BalanceCultivo>{};

    // Inicializar todos los cultivos
    for (final cultivoKey in CultivoKeys.todas) {
      balance[cultivoKey] = BalanceCultivo(
        cultivoKey: cultivoKey,
        siembras: 0,
        ventas: 0,
      );
    }

    // Procesar movimientos no anulados en el periodo
    for (final movimiento in widget.motor.movimientos) {
      if (movimiento.anulado) continue;
      if (movimiento.fecha.isBefore(fechaInicio) ||
          movimiento.fecha.isAfter(ahora)) {
        continue;
      }

      final cultivoKey = _obtenerCultivoKeyDeLote(movimiento.loteId);
      if (cultivoKey == null || !CultivoKeys.todas.contains(cultivoKey)) {
        continue;
      }

      final balanceCultivo = balance[cultivoKey]!;

      if (movimiento.tipo == TipoMovimiento.siembra) {
        // Contar siembras (cada movimiento cuenta como 1)
        balanceCultivo.siembras++;
      } else if (movimiento.tipo == TipoMovimiento.venta) {
        // Sumar cantidad de ventas
        balanceCultivo.ventas += movimiento.cantidad ?? 0;
      }
    }

    return balance;
  }

  @override
  Widget build(BuildContext context) {
    final balances = _calcularBalancePorCultivo();
    final balancesLista = balances.values.toList()
      ..sort((a, b) => a.cultivoKey.compareTo(b.cultivoKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Balance Siembras vs Ventas'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '7 días'),
            Tab(text: '30 días'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildListaBalance(balancesLista),
          _buildListaBalance(balancesLista),
        ],
      ),
    );
  }

  Widget _buildListaBalance(List<BalanceCultivo> balances) {
    if (balances.isEmpty) {
      return const Center(
        child: Text('No hay datos disponibles'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: balances.length,
      itemBuilder: (context, index) {
        final balance = balances[index];
        final balanceValor = balance.siembras - balance.ventas;
        final tieneAlerta = balanceValor < 0;
        final vigilar = balanceValor == 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        CultivoLabels.obtenerLabel(balance.cultivoKey),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    if (tieneAlerta)
                      Icon(
                        Icons.warning,
                        color: Colors.red,
                        size: 24,
                      )
                    else if (vigilar)
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange,
                        size: 24,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    Chip(
                      label: Text('Siembras: ${balance.siembras}'),
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                    ),
                    Chip(
                      label: Text('Ventas: ${balance.ventas}'),
                      backgroundColor:
                          Theme.of(context).colorScheme.secondaryContainer,
                    ),
                    Chip(
                      label: Text('Balance: $balanceValor'),
                      backgroundColor: tieneAlerta
                          ? Colors.red.shade100
                          : vigilar
                              ? Colors.orange.shade100
                              : Colors.green.shade100,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: tieneAlerta
                            ? Colors.red.shade900
                            : vigilar
                                ? Colors.orange.shade900
                                : Colors.green.shade900,
                      ),
                    ),
                  ],
                ),
                if (tieneAlerta)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '⚠️ ALERTA: Balance negativo',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  )
                else if (vigilar)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '👁️ VIGILAR: Balance en cero',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class BalanceCultivo {
  final String cultivoKey;
  int siembras;
  int ventas;

  BalanceCultivo({
    required this.cultivoKey,
    required this.siembras,
    required this.ventas,
  });
}

