import 'package:flutter/material.dart';
import '../data/invernadero_firestore_repo.dart';
import '../domain/motor_invernadero.dart';
import '../domain/movimiento.dart';
import '../domain/cultivos.dart';
import '../dev/dev_seed.dart';
import '../dev/dev_validaciones.dart';
import '../dev/dev_config.dart';
import '../services/alertas_cobertura_service.dart';
import '../services/ajustes_service.dart';
import 'ajustes/ajustes_screen.dart';
import 'siembras/siembra_nueva_screen.dart';
import 'siembras/siembras_lista_screen.dart';
import 'flujo/flujo_screen.dart';
import 'ventas_screen.dart';
import 'traspaso_screen.dart';
import 'merma_screen.dart';
import 'gastos_screen.dart';
import 'resumen_economico_screen.dart';

class InicioTab extends StatefulWidget {
  final MotorInvernadero motor;
  final InvernaderoFirestoreRepo firestoreRepo;

  static final GlobalKey<_InicioTabState> globalKey =
      GlobalKey<_InicioTabState>();

  const InicioTab({super.key, required this.motor, required this.firestoreRepo});

  @override
  State<InicioTab> createState() => _InicioTabState();
}

class _InicioTabState extends State<InicioTab> {
  DevScenario _scenarioSeleccionado = DevScenario.normal;
  String? _errorValidacion;
  Map<String, String> _coberturas = {};

  // Configuración simple para sugerencia de siembra (MVP)
  static const Map<String, int> _SEMANAS_CICLO = {
    CultivoKeys.lechuga: 6,
    CultivoKeys.cilantro: 10,
    CultivoKeys.rucula: 10,
    CultivoKeys.acelga: 10,
    CultivoKeys.perejil: 10,
  };

  static const double _STOCK_SEGURIDAD_SEMANAS = 1.0;

  bool _cargandoSugerencias = false;
  String? _errorSugerencias;
  Map<String, _SugerenciaSiembra> _sugerencias = {};

  /// Metas diarias de siembras por cultivo
  static const Map<String, int> METAS_DIARIAS_POR_CULTIVO = {
    CultivoKeys.lechuga: 5,
    CultivoKeys.cilantro: 3,
    CultivoKeys.perejil: 2,
    CultivoKeys.rucula: 4,
  };

  @override
  void initState() {
    super.initState();
    _cargarAlertasYCoberturas();
    _cargarSugerenciasSiembra();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recargar alertas cuando la pantalla vuelve a ser visible
    _cargarAlertasYCoberturas();
  }

  Future<void> _cargarAlertasYCoberturas() async {
    // Cargar metas desde ajustes (con fallback a valores por defecto)
    final metas = await AjustesService.cargarMetas();

    // Calcular coberturas actuales usando las metas efectivas
    final coberturas = <String, String>{};
    for (final cultivoKey in CultivoKeys.todas) {
      final meta = metas[cultivoKey] ?? 0;
      coberturas[cultivoKey] = widget.motor.calcularCobertura(cultivoKey, meta: meta);
    }

    // Actualizar alertas según cobertura actual
    await AlertasCoberturaService.actualizarAlertasSegunCobertura(coberturas);

    if (mounted) {
      setState(() {
        _coberturas = coberturas;
      });
    }
  }

  Future<void> refrescarSugerencias() async {
    await _cargarSugerenciasSiembra();
  }

  Future<void> _aplicarSeed() async {
    widget.motor.reset();
    seed(widget.motor, scenario: _scenarioSeleccionado);
    for (final cultivoKey in CultivoKeys.todas) {
      try {
        final stockActual = widget.motor.calcularStockFinalPorCultivo(cultivoKey);
        await widget.firestoreRepo.guardarStockActualPorCultivo(cultivoKey, stockActual);
      } catch (e) {
        debugPrint('Firestore guardarStockActualPorCultivo($cultivoKey): $e');
      }
    }
    _ejecutarValidaciones();
    _cargarAlertasYCoberturas();
    _cargarSugerenciasSiembra();
  }

  Future<void> _cargarSugerenciasSiembra() async {
    setState(() {
      _cargandoSugerencias = true;
      _errorSugerencias = null;
    });

    try {
      final ahora = DateTime.now();
      final desde = ahora.subtract(const Duration(days: 28));

      final movimientos = await widget.firestoreRepo.obtenerMovimientos();
      final ventasPorCultivo = <String, int>{};

      for (final mov in movimientos) {
        if (mov['tipo'] != 'venta') continue;
        final fechaRaw = mov['fecha'];
        if (fechaRaw is! String) continue;
        final fecha = DateTime.tryParse(fechaRaw);
        if (fecha == null || fecha.isBefore(desde)) continue;

        final cultivoKey = mov['cultivoKey']?.toString();
        if (cultivoKey == null || cultivoKey.isEmpty) continue;
        final cantidadRaw = mov['cantidad'];
        final cantidad = cantidadRaw is num ? cantidadRaw.toInt() : 0;
        if (cantidad <= 0) continue;

        ventasPorCultivo[cultivoKey] =
            (ventasPorCultivo[cultivoKey] ?? 0) + cantidad;
      }

      final sugerencias = <String, _SugerenciaSiembra>{};

      for (final cultivoKey in CultivoKeys.todas) {
        final ventas28Dias = ventasPorCultivo[cultivoKey] ?? 0;
        final stockTotal = widget.motor.calcularStockPorCultivo(cultivoKey);
        final stockVendible =
            widget.motor.calcularStockFinalPorCultivo(cultivoKey);
        final stockEnProceso = stockTotal - stockVendible;

        if (ventas28Dias == 0) {
          sugerencias[cultivoKey] = _SugerenciaSiembra(
            cultivoKey: cultivoKey,
            ventas28Dias: 0,
            demandaSemanalPromedio: 0,
            stockVendible: stockVendible,
            stockTotal: stockTotal,
            stockEnProceso: stockEnProceso,
            coberturaTotalSemanas: 0,
            siembraSugerida: 0,
            estado: 'Sin ventas recientes',
          );
        } else {
          final demandaSemanalPromedio = ventas28Dias / 4.0;
          final baseDemanda = demandaSemanalPromedio;

          final coberturaTotalSemanas = stockTotal / baseDemanda;

          final semanasCiclo = _SEMANAS_CICLO[cultivoKey] ?? 8;
          final demandaDuranteCiclo =
              demandaSemanalPromedio * semanasCiclo.toDouble();
          final stockSeguridad =
              demandaSemanalPromedio * _STOCK_SEGURIDAD_SEMANAS;

          final siembraSugeridaDouble =
              demandaDuranteCiclo + stockSeguridad - stockTotal;
          int siembraSugerida;
          if (siembraSugeridaDouble <= 0) {
            siembraSugerida = 0;
          } else if (cultivoKey == CultivoKeys.lechuga) {
            final base = siembraSugeridaDouble.round();
            siembraSugerida = ((base + 699) ~/ 700) * 700;
          } else {
            siembraSugerida = siembraSugeridaDouble.round();
          }

          String estado;
          if (coberturaTotalSemanas < semanasCiclo) {
            estado = 'Sembrar ahora';
          } else if (coberturaTotalSemanas >=
              semanasCiclo + _STOCK_SEGURIDAD_SEMANAS) {
            estado = 'Bien por ahora';
          } else {
            estado = 'Vigilar';
          }

          sugerencias[cultivoKey] = _SugerenciaSiembra(
            cultivoKey: cultivoKey,
            ventas28Dias: ventas28Dias,
            demandaSemanalPromedio: demandaSemanalPromedio,
            stockVendible: stockVendible,
            stockTotal: stockTotal,
            stockEnProceso: stockEnProceso,
            coberturaTotalSemanas: coberturaTotalSemanas,
            siembraSugerida: siembraSugerida,
            estado: estado,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _sugerencias = sugerencias;
        _cargandoSugerencias = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorSugerencias = e.toString();
        _cargandoSugerencias = false;
      });
    }
  }

  void _ejecutarValidaciones() {
    if (!DEV_MODE) return;
    try {
      assertConsistencia(widget.motor);
      _errorValidacion = null;
    } catch (e) {
      _errorValidacion = e.toString();
    }
  }

  String _formatearEscenario(DevScenario scenario) {
    switch (scenario) {
      case DevScenario.normal:
        return 'Normal';
      case DevScenario.mermaAlta:
        return 'Merma Alta';
      case DevScenario.cosechaParcial:
        return 'Cosecha Parcial';
    }
  }

  /// Cuenta las siembras no anuladas del día actual
  int _contarSiembrasHoy() {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final manana = hoy.add(const Duration(days: 1));

    return widget.motor.movimientos
        .where((m) =>
            m.tipo == TipoMovimiento.siembra &&
            !m.anulado &&
            m.fecha.isAfter(hoy.subtract(const Duration(milliseconds: 1))) &&
            m.fecha.isBefore(manana))
        .length;
  }

  /// Cuenta las siembras del día actual agrupadas por cultivo
  Map<String, int> _contarSiembrasHoyPorCultivo() {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final manana = hoy.add(const Duration(days: 1));

    // Inicializar el mapa con todos los cultivos en 0
    final conteo = <String, int>{};
    for (final cultivoKey in CultivoKeys.todas) {
      conteo[cultivoKey] = 0;
    }

    // Filtrar siembras del día y agrupar por cultivo
    final siembrasHoy = widget.motor.movimientos.where((m) =>
        m.tipo == TipoMovimiento.siembra &&
        !m.anulado &&
        m.fecha.isAfter(hoy.subtract(const Duration(milliseconds: 1))) &&
        m.fecha.isBefore(manana));

    for (final movimiento in siembrasHoy) {
      try {
        final lote = widget.motor.lotes.firstWhere(
          (l) => l.id == movimiento.loteId,
        );
        final cultivoKey = lote.cultivoKey;
        conteo[cultivoKey] = (conteo[cultivoKey] ?? 0) + 1;
      } catch (_) {
        // Si no se encuentra el lote, ignorar el movimiento
      }
    }

    return conteo;
  }

  /// Calcula el estado de siembras de hoy por cultivo comparando con meta diaria
  Map<String, Map<String, dynamic>> _calcularEstadoSiembrasHoyPorCultivo() {
    final siembrasHoy = _contarSiembrasHoyPorCultivo();
    final estados = <String, Map<String, dynamic>>{};

    for (final cultivoKey in CultivoKeys.todas) {
      final siembras = siembrasHoy[cultivoKey] ?? 0;
      final meta = METAS_DIARIAS_POR_CULTIVO[cultivoKey] ?? 0;
      final estado = siembras >= meta ? 'ok' : 'bajo';

      estados[cultivoKey] = {
        'siembras': siembras,
        'meta': meta,
        'estado': estado,
      };
    }

    return estados;
  }

  /// Construye el bloque ACCIÓN con botones para registrar operaciones
  Widget _buildBloqueAccion(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acción',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Botón Registrar Siembra
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SiembraNuevaScreen(
                        motor: widget.motor,
                        firestoreRepo: widget.firestoreRepo,
                      ),
                    ),
                  ).then((_) {
                    setState(() {});
                    _cargarAlertasYCoberturas();
                    _cargarSugerenciasSiembra();
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('+ Registrar siembra'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Botón Registrar Venta
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => VentasScreen(motor: widget.motor, firestoreRepo: widget.firestoreRepo),
                    ),
                  ).then((_) {
                    setState(() {});
                    _cargarSugerenciasSiembra();
                  });
                },
                icon: const Icon(Icons.shopping_cart),
                label: const Text('+ Registrar venta'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Botón Registrar Traspaso
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => TraspasoScreen(
                        motor: widget.motor,
                        firestoreRepo: widget.firestoreRepo,
                      ),
                    ),
                  ).then((_) {
                    setState(() {});
                    _cargarSugerenciasSiembra();
                  });
                },
                icon: const Icon(Icons.swap_horiz),
                label: const Text('+ Registrar traspaso'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Botón Registrar Merma
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => MermaScreen(
                        motor: widget.motor,
                        firestoreRepo: widget.firestoreRepo,
                      ),
                    ),
                  ).then((_) {
                    setState(() {});
                    _cargarSugerenciasSiembra();
                  });
                },
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text('+ Registrar merma'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Botón Registrar Gasto
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => GastosScreen(
                        firestoreRepo: widget.firestoreRepo,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.payments),
                label: const Text('Registrar gasto'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Botón Resumen económico
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ResumenEconomicoScreen(
                        firestoreRepo: widget.firestoreRepo,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.insights),
                label: const Text('Resumen económico'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget helper para crear módulos con header consistente
  Widget _buildModuleCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final content = Padding(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );

    if (onTap != null) {
      return Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: content,
        ),
      );
    }

    return Card(child: content);
  }

  Widget _buildCardSiembras(BuildContext context) {
    final siembrasHoy = _contarSiembrasHoy();
    final siembrasPorCultivo = _contarSiembrasHoyPorCultivo();

    final badge = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(
            'Hoy: ',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            siembrasHoy.toString(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );

    return _buildModuleCard(
      context: context,
      title: 'Siembras',
      icon: Icons.eco,
      trailing: badge,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SiembrasListaScreen(motor: widget.motor),
          ),
        );
      },
      child: Text(
        CultivoKeys.todas
            .map((cultivoKey) {
              final cantidad = siembrasPorCultivo[cultivoKey] ?? 0;
              final label = CultivoLabels.obtenerLabel(cultivoKey);
              return '$label: $cantidad';
            })
            .join('  |  '),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildCardFlujo(BuildContext context) {
    return _buildModuleCard(
      context: context,
      title: 'Flujo',
      icon: Icons.timeline,
      trailing: TextButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => FlujoScreen(motor: widget.motor),
            ),
          );
        },
        child: const Text('Abrir'),
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FlujoScreen(motor: widget.motor),
          ),
        );
      },
      child: Text(
        '7D / 30D',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildCardSugerenciaSiembra(BuildContext context) {
    Widget content;

    if (_cargandoSugerencias && _sugerencias.isEmpty) {
      content = const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (_errorSugerencias != null && _sugerencias.isEmpty) {
      content = Text(
        _errorSugerencias!,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Colors.red),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: CultivoKeys.todas.map((cultivoKey) {
          final s = _sugerencias[cultivoKey];
          final label = CultivoLabels.obtenerLabel(cultivoKey);

          if (s == null) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                '$label: sin datos de ventas recientes',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 2),
                if (s.ventas28Dias == 0) ...[
                  Text(
                    'Sin ventas recientes',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Stock vendible: ${s.stockVendible} u. | En proceso: ${s.stockEnProceso} u.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Sugerencia de siembra: 0 u.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ] else ...[
                  Text(
                    'Demanda semanal: ${s.demandaSemanalPromedio.toStringAsFixed(1)} u.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Stock vendible: ${s.stockVendible} u. | En proceso: ${s.stockEnProceso} u.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Cobertura total: ${s.coberturaTotalSemanas.toStringAsFixed(1)} semanas',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Sugerencia de siembra: ${s.siembraSugerida} u.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
                Text(
                  'Estado: ${s.estado}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: s.estado == 'Sembrar ahora'
                            ? Colors.red
                            : s.estado == 'Vigilar'
                                ? Colors.orange[700]
                                : Colors.green[700],
                      ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    return _buildModuleCard(
      context: context,
      title: 'Sugerencia de siembra',
      icon: Icons.spa,
      child: content,
    );
  }

  Widget _buildCardAlertaSiembras(BuildContext context) {
    final estados = _calcularEstadoSiembrasHoyPorCultivo();
    final todosOk = estados.values.every((e) => e['estado'] == 'ok');

    // Filtrar cultivos con meta > 0 para evitar ruido
    final cultivosConMeta = CultivoKeys.todas.where((cultivoKey) {
      final estado = estados[cultivoKey]!;
      final meta = estado['meta'] as int;
      return meta > 0;
    }).toList();

    Widget content;
    if (todosOk) {
      content = Row(
        children: [
          const Text('✅'),
          const SizedBox(width: 8),
          Text(
            'Siembras de hoy en meta',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: cultivosConMeta.map((cultivoKey) {
          final estado = estados[cultivoKey]!;
          final siembras = estado['siembras'] as int;
          final meta = estado['meta'] as int;
          final esOk = estado['estado'] == 'ok';
          final label = CultivoLabels.obtenerLabel(cultivoKey);

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Text(
                  esOk ? '✓' : '!',
                  style: TextStyle(
                    color: esOk ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$label: $siembras / $meta',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    return _buildModuleCard(
      context: context,
      title: 'Alerta siembras (hoy)',
      icon: Icons.notifications,
      child: content,
    );
  }

  Future<void> _abrirSiembraRapida(
    BuildContext context,
    String cultivoKey,
    int stockActual,
  ) async {
    // Calcular cantidad sugerida: max(0, metaEfectiva - stockActual)
    final metaEfectiva = await AjustesService.obtenerMetaEfectiva(cultivoKey);
    if (!mounted) return;
    
    final cantidadSugerida = (metaEfectiva - stockActual)
        .clamp(0, double.infinity)
        .toInt();

    // Navegar a pantalla de siembra con valores preseleccionados
    if (!mounted) return;
    final resultado = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SiembraNuevaScreen(
          motor: widget.motor,
          firestoreRepo: widget.firestoreRepo,
          initialCultivoKey: cultivoKey,
          initialCantidad: cantidadSugerida > 0 ? cantidadSugerida : null,
          esSiembraRapida: true,
        ),
      ),
    );

    // Recargar coberturas y alertas al volver
    if (resultado == true && mounted) {
      _cargarAlertasYCoberturas();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Invernadero MVP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Ajustes',
            onPressed: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (context) => const AjustesScreen(),
                    ),
                  )
                  .then((_) {
                    // Recargar alertas y coberturas cuando se regresa de Ajustes
                    _cargarAlertasYCoberturas();
                  });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Selector de escenario (solo en modo DEV)
          if (DEV_MODE) ...[
            DropdownButtonFormField<DevScenario>(
              value: _scenarioSeleccionado,
              decoration: const InputDecoration(
                labelText: 'Escenario DEV',
                border: OutlineInputBorder(),
              ),
              items: DevScenario.values.map((scenario) {
                return DropdownMenuItem<DevScenario>(
                  value: scenario,
                  child: Text(_formatearEscenario(scenario)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _scenarioSeleccionado = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            // Botón Reset + Seed (solo en modo DEV)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _aplicarSeed();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reset + Seed'),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Card de error DEV (solo en modo DEV)
          if (DEV_MODE && _errorValidacion != null)
            Card(
              color: Colors.red.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade900),
                        const SizedBox(width: 8),
                        Text(
                          'ERROR DEV - Validación de Consistencia',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade900,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorValidacion!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.red.shade900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_errorValidacion != null) const SizedBox(height: 16),
          
          // ========== BLOQUE ACCIÓN ==========
          _buildBloqueAccion(context),
          const SizedBox(height: 16),
          
          // ========== MÓDULO SIEMBRAS ==========
          _buildCardSiembras(context),
          const SizedBox(height: 12),
          
          // ========== MÓDULO ALERTA SIEMBRAS ==========
          _buildCardAlertaSiembras(context),
          const SizedBox(height: 12),
          
          // ========== MÓDULO SUGERENCIA SIEMBRA ==========
          _buildCardSugerenciaSiembra(context),
          const SizedBox(height: 12),
          
          // ========== MÓDULO FLUJO ==========
          _buildCardFlujo(context),
          ],
        ),
      ),
    );
  }
}

class _SugerenciaSiembra {
  final String cultivoKey;
  final int ventas28Dias;
  final double demandaSemanalPromedio;
  final int stockVendible;
  final int stockTotal;
  final int stockEnProceso;
  final double coberturaTotalSemanas;
  final int siembraSugerida;
  final String estado;

  _SugerenciaSiembra({
    required this.cultivoKey,
    required this.ventas28Dias,
    required this.demandaSemanalPromedio,
    required this.stockVendible,
    required this.stockTotal,
    required this.stockEnProceso,
    required this.coberturaTotalSemanas,
    required this.siembraSugerida,
    required this.estado,
  });
}


