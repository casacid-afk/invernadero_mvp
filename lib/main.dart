import 'package:flutter/material.dart';
import 'domain/motor_invernadero.dart';
import 'domain/etapa.dart';
import 'domain/cultivos.dart';
import 'dev/dev_seed.dart';
import 'dev/dev_validaciones.dart';
import 'dev/dev_config.dart';
import 'services/alertas_cobertura_service.dart';
import 'services/ajustes_service.dart';
import 'screens/ajustes/ajustes_screen.dart';
import 'screens/siembras/siembra_nueva_screen.dart';
import 'screens/siembras/siembras_lista_screen.dart';
import 'screens/flujo/flujo_screen.dart';
import 'screens/ventas_screen.dart';
import 'screens/traspaso_screen.dart';
import 'screens/merma_screen.dart';
import 'domain/movimiento.dart';
import 'widgets/cobertura_badge.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Invernadero MVP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const InvernaderoHomePage(),
    );
  }
}

class InvernaderoHomePage extends StatefulWidget {
  const InvernaderoHomePage({super.key});

  @override
  State<InvernaderoHomePage> createState() => _InvernaderoHomePageState();
}

class _InvernaderoHomePageState extends State<InvernaderoHomePage> {
  late final MotorInvernadero motor;
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
    motor = MotorInvernadero();
    if (DEV_MODE) {
      _aplicarSeed();
    }
    _cargarAlertasYCoberturas();
  }

  Future<void> _cargarAlertasYCoberturas() async {
    // Cargar metas desde ajustes (con fallback a valores por defecto)
    final metas = await AjustesService.cargarMetas();

    // Calcular coberturas actuales usando las metas efectivas
    final coberturas = <String, String>{};
    for (final cultivoKey in CultivoKeys.todas) {
      final meta = metas[cultivoKey] ?? 0;
      coberturas[cultivoKey] = motor.calcularCobertura(cultivoKey, meta: meta);
    }

    // Actualizar alertas según cobertura actual
    // Guarda estados persistentes para 🔴 y 🟡
    await AlertasCoberturaService.actualizarAlertasSegunCobertura(coberturas);

    if (mounted) {
      setState(() {
        _coberturas = coberturas;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recargar alertas cuando la pantalla vuelve a ser visible
    // Esto asegura que las alertas se actualicen después de navegar
    _cargarAlertasYCoberturas();
  }

  void _aplicarSeed() {
    motor.reset(); // Asegurar que el motor esté limpio antes del seed
    seed(motor, scenario: _scenarioSeleccionado);
    _ejecutarValidaciones();
    _cargarAlertasYCoberturas(); // Actualizar alertas después del seed
  }

  void _ejecutarValidaciones() {
    if (!DEV_MODE) return;
    try {
      assertConsistencia(motor);
      _errorValidacion = null;
    } catch (e) {
      _errorValidacion = e.toString();
    }
  }

  String _formatearEtapa(Etapa etapa) {
    return etapa.name
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
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

  /// Formatea la hora de una fecha como "HH:mm" o "hoy/ayer + hora"
  String _formatearHora(DateTime fecha) {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final ayer = hoy.subtract(const Duration(days: 1));
    final fechaComparar = DateTime(fecha.year, fecha.month, fecha.day);

    final hora = '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

    if (fechaComparar == hoy) {
      return 'hoy $hora';
    } else if (fechaComparar == ayer) {
      return 'ayer $hora';
    } else {
      return hora;
    }
  }

  /// Obtiene las últimas 3 siembras no anuladas
  List<Movimiento> _obtenerUltimasSiembras() {
    final siembras = motor.movimientos
        .where((m) => m.tipo == TipoMovimiento.siembra && !m.anulado)
        .toList();
    siembras.sort((a, b) => b.fecha.compareTo(a.fecha));
    return siembras.take(3).toList();
  }

  /// Obtiene el nombre del cultivo desde un movimiento de siembra
  String _obtenerCultivoDeSiembra(Movimiento movimiento) {
    try {
      final lote = motor.lotes.firstWhere(
        (l) => l.id == movimiento.loteId,
      );
      return CultivoLabels.obtenerLabel(lote.cultivoKey);
    } catch (_) {
      return 'Cultivo desconocido';
    }
  }

  /// Cuenta las siembras no anuladas del día actual
  int _contarSiembrasHoy() {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final manana = hoy.add(const Duration(days: 1));

    return motor.movimientos
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
    final siembrasHoy = motor.movimientos.where((m) =>
        m.tipo == TipoMovimiento.siembra &&
        !m.anulado &&
        m.fecha.isAfter(hoy.subtract(const Duration(milliseconds: 1))) &&
        m.fecha.isBefore(manana));

    for (final movimiento in siembrasHoy) {
      try {
        final lote = motor.lotes.firstWhere(
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
                      builder: (context) => SiembraNuevaScreen(motor: motor),
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
                      builder: (context) => VentasScreen(motor: motor),
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
                      builder: (context) => TraspasoScreen(motor: motor),
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
                      builder: (context) => MermaScreen(motor: motor),
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

  /// Construye el bloque RESUMEN con cards de Siembras, Alerta y Flujo
  Widget _buildBloqueResumen(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card Siembras
        _buildCardSiembras(context),
        const SizedBox(height: 12),
        // Card Alerta siembras
        _buildCardAlertaSiembras(context),
        const SizedBox(height: 12),
        // Card Flujo
        _buildCardFlujo(context),
      ],
    );
  }

  /// Construye el bloque ESTADO con Stock por cultivo, Stock por etapa y Últimas siembras
  Widget _buildBloqueEstado(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stock por cultivo (con coberturas)
        _buildModuleCard(
          context: context,
          title: 'Stock por Cultivo',
          icon: Icons.inventory_2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: CultivoKeys.todas.map((cultivoKey) {
              final cobertura = _coberturas[cultivoKey] ?? '🟢';
              final stock = motor.calcularStockPorCultivo(cultivoKey);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            CultivoLabels.obtenerLabel(cultivoKey),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(width: 8),
                          Text(cobertura, style: const TextStyle(fontSize: 20)),
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: CoberturaBadge(
                              cobertura: cobertura,
                              onTap: cobertura == '🔴'
                                  ? () => _abrirSiembraRapida(
                                      context,
                                      cultivoKey,
                                      stock,
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      stock.toString(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        // Stock por etapa
        _buildModuleCard(
          context: context,
          title: 'Stock por Etapa',
          icon: Icons.layers,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: Etapa.values.map((etapa) {
              final stock = motor.calcularStockPorEtapa(etapa);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildStockItem(_formatearEtapa(etapa), stock),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        // Últimas siembras
        _buildUltimasSiembras(context),
      ],
    );
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
                    // para reflejar cambios en las metas
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
            
            // ========== BLOQUE RESUMEN ==========
            _buildBloqueResumen(context),
            const SizedBox(height: 16),
            
            // ========== BLOQUE ESTADO ==========
            _buildBloqueEstado(context),
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

  Widget _buildStockItem(String label, int valor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        Text(
          valor.toString(),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
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
            builder: (context) => SiembrasListaScreen(motor: motor),
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
              builder: (context) => FlujoScreen(motor: motor),
            ),
          );
        },
        child: const Text('Abrir'),
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FlujoScreen(motor: motor),
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

  Widget _buildUltimasSiembras(BuildContext context) {
    final ultimasSiembras = _obtenerUltimasSiembras();

    Widget content;
    if (ultimasSiembras.isEmpty) {
      content = Text(
        'No hay siembras registradas',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.grey,
        ),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: ultimasSiembras.asMap().entries.map((entry) {
          final index = entry.key;
          final movimiento = entry.value;
          final cultivo = _obtenerCultivoDeSiembra(movimiento);
          final cantidad = movimiento.cantidad ?? 0;
          final hora = _formatearHora(movimiento.fecha);
          final esPrimeraSiembra = index == 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    cultivo,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                Text(
                  '$cantidad',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  hora,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                if (esPrimeraSiembra) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _mostrarDialogoDeshacerSiembra(
                      context,
                      movimiento,
                      cultivo,
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Deshacer',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      );
    }

    return _buildModuleCard(
      context: context,
      title: 'Últimas siembras',
      icon: Icons.history,
      trailing: ultimasSiembras.isNotEmpty
          ? TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SiembrasListaScreen(motor: motor),
                  ),
                );
              },
              child: const Text('Ver todas'),
            )
          : null,
      onTap: ultimasSiembras.isNotEmpty
          ? () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SiembrasListaScreen(motor: motor),
                ),
              );
            }
          : null,
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
          motor: motor,
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

  Future<void> _mostrarDialogoDeshacerSiembra(
    BuildContext context,
    Movimiento movimiento,
    String cultivo,
  ) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anular siembra'),
        content: Text('¿Anular esta siembra de $cultivo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Anular'),
          ),
        ],
      ),
    );

    if (confirmado == true && mounted) {
      try {
        motor.anularMovimiento(movimiento.id);
        setState(() {});
        _cargarAlertasYCoberturas();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Siembra anulada'),
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al anular siembra: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
