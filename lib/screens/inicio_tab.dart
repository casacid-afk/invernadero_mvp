import 'package:flutter/material.dart';
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

class InicioTab extends StatefulWidget {
  final MotorInvernadero motor;

  const InicioTab({super.key, required this.motor});

  @override
  State<InicioTab> createState() => _InicioTabState();
}

class _InicioTabState extends State<InicioTab> {
  DevScenario _scenarioSeleccionado = DevScenario.normal;
  String? _errorValidacion;
  Map<String, String> _coberturas = {};

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
    if (DEV_MODE) {
      _aplicarSeed();
    }
    _cargarAlertasYCoberturas();
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

  void _aplicarSeed() {
    widget.motor.reset();
    seed(widget.motor, scenario: _scenarioSeleccionado);
    _ejecutarValidaciones();
    _cargarAlertasYCoberturas();
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
                      builder: (context) => SiembraNuevaScreen(motor: widget.motor),
                    ),
                  ).then((_) {
                    setState(() {});
                    _cargarAlertasYCoberturas();
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
                      builder: (context) => VentasScreen(motor: widget.motor),
                    ),
                  ).then((_) {
                    setState(() {});
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
                      builder: (context) => TraspasoScreen(motor: widget.motor),
                    ),
                  ).then((_) {
                    setState(() {});
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
                      builder: (context) => MermaScreen(motor: widget.motor),
                    ),
                  ).then((_) {
                    setState(() {});
                  });
                },
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text('+ Registrar merma'),
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
                onPressed: () {
                  _aplicarSeed();
                  setState(() {});
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
          // DESACTIVADO TEMPORALMENTE: bloque contador/resumen de siembras
          if (false) ...[
            _buildCardSiembras(context),
            const SizedBox(height: 12),
          ],
          
          // ========== MÓDULO ALERTA SIEMBRAS ==========
          // DESACTIVADO TEMPORALMENTE: bloque alerta siembras (hoy)
          if (false) ...[
            _buildCardAlertaSiembras(context),
            const SizedBox(height: 12),
          ],
          
          // ========== MÓDULO FLUJO ==========
          _buildCardFlujo(context),
          ],
        ),
      ),
    );
  }
}

