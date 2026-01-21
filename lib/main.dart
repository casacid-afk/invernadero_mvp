import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'domain/motor_invernadero.dart';
import 'domain/etapa.dart';
import 'domain/cultivos.dart';
import 'domain/movimiento.dart';
import 'dev/dev_seed.dart';
import 'dev/dev_validaciones.dart';
import 'dev/dev_config.dart';
import 'services/app_repository.dart';
import 'services/bootstrap_service.dart';
import 'services/firestore_cierres_service.dart';
import 'screens/ventas_screen.dart';
import 'screens/reportes_screen.dart';
import 'screens/siembras/siembras_lista_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Firebase
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // Si falla Firebase, continuar sin Firestore (modo offline)
  }
  
  final motor = MotorInvernadero();
  final repository = AppRepository(motor);
  
  // Configurar Firestore para cierres (si Firebase está disponible)
  try {
    final firestoreService = FirestoreCierresService(invernaderoId: 'invernadero_principal');
    motor.configurarFirestore(firestoreService);
  } catch (e) {
    // Si falla, continuar sin Firestore (fallback a memoria)
  }
  
  await BootstrapService.ensureSeeded(repository);
  
  // Cargar cierres desde Firestore
  await BootstrapService.cargarCierres(repository);
  
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
  
  // Meta diaria global
  static const int META_DIARIA = 50;

  // Metas diarias por cultivo
  static const Map<String, int> METAS_DIARIAS_POR_CULTIVO = {
    'lechuga': 50,
    'cilantro': 20,
    'rucula': 5,
    'perejil': 5,
  };

  @override
  void initState() {
    super.initState();
    motor = MotorInvernadero();
    if (DEV_MODE) {
      _aplicarSeed();
    }
  }

  void _aplicarSeed() {
    motor.reset(); // Asegurar que el motor esté limpio antes del seed
    seed(motor, scenario: _scenarioSeleccionado);
    _ejecutarValidaciones();
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
     return etapa.name.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
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

  int _calcularSiembrasHoy() {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final finHoy = inicioHoy.add(const Duration(days: 1));

    return motor.movimientos
        .where((movimiento) =>
            movimiento.tipo == TipoMovimiento.siembra &&
            !movimiento.anulado &&
            movimiento.fecha.isAfter(inicioHoy.subtract(const Duration(milliseconds: 1))) &&
            movimiento.fecha.isBefore(finHoy))
        .fold(0, (suma, movimiento) => suma + (movimiento.cantidad ?? 0));
  }

  /// Obtiene el estado y texto de la meta diaria
  Map<String, dynamic> _obtenerEstadoMetaDiaria() {
    final hoy = _calcularSiembrasHoy();
    
    if (hoy >= META_DIARIA) {
      return {
        'estado': 'ok',
        'texto': 'Meta hoy: OK ($hoy/$META_DIARIA)',
        'color': Colors.green,
      };
    } else if (hoy > 0) {
      return {
        'estado': 'bajo',
        'texto': 'Meta hoy: Bajo ($hoy/$META_DIARIA)',
        'color': Colors.orange,
      };
    } else {
      return {
        'estado': 'deficit',
        'texto': 'Meta hoy: Déficit (0/$META_DIARIA)',
        'color': Colors.red,
      };
    }
  }

  double _calcularPromedio7Dias() {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final inicio7DiasAtras = inicioHoy.subtract(const Duration(days: 7));

    final siembras7Dias = motor.movimientos
        .where((movimiento) =>
            movimiento.tipo == TipoMovimiento.siembra &&
            !movimiento.anulado &&
            movimiento.fecha.isAfter(inicio7DiasAtras.subtract(const Duration(milliseconds: 1))) &&
            movimiento.fecha.isBefore(inicioHoy))
        .fold(0, (suma, movimiento) => suma + (movimiento.cantidad ?? 0));

    return siembras7Dias / 7.0;
  }

  bool _debeMostrarAlerta() {
    final siembrasHoy = _calcularSiembrasHoy();
    final promedio7Dias = _calcularPromedio7Dias();
    return siembrasHoy < promedio7Dias;
  }

  int _calcularSiembras7Dias() {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final finHoy = inicioHoy.add(const Duration(days: 1));
    final inicio7DiasAtras = inicioHoy.subtract(const Duration(days: 6));

    return motor.movimientos
        .where((movimiento) =>
            movimiento.tipo == TipoMovimiento.siembra &&
            !movimiento.anulado &&
            movimiento.fecha.isAfter(inicio7DiasAtras.subtract(const Duration(milliseconds: 1))) &&
            movimiento.fecha.isBefore(finHoy))
        .fold(0, (suma, movimiento) => suma + (movimiento.cantidad ?? 0));
  }

  int _calcularSiembras30Dias() {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final finHoy = inicioHoy.add(const Duration(days: 1));
    final inicio30DiasAtras = inicioHoy.subtract(const Duration(days: 29));

    return motor.movimientos
        .where((movimiento) =>
            movimiento.tipo == TipoMovimiento.siembra &&
            !movimiento.anulado &&
            movimiento.fecha.isAfter(inicio30DiasAtras.subtract(const Duration(milliseconds: 1))) &&
            movimiento.fecha.isBefore(finHoy))
        .fold(0, (suma, movimiento) => suma + (movimiento.cantidad ?? 0));
  }

  double _calcularVentasPromedioDiario30Dias() {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final finHoy = inicioHoy.add(const Duration(days: 1));
    final inicio30DiasAtras = inicioHoy.subtract(const Duration(days: 29));

    final ventas30Dias = motor.movimientos
        .where((movimiento) =>
            movimiento.tipo == TipoMovimiento.venta &&
            !movimiento.anulado &&
            movimiento.fecha.isAfter(inicio30DiasAtras.subtract(const Duration(milliseconds: 1))) &&
            movimiento.fecha.isBefore(finHoy))
        .fold(0, (suma, movimiento) => suma + (movimiento.cantidad ?? 0));

    return ventas30Dias / 30.0;
  }

  double? _calcularCobertura() {
    final ventasPromedio = _calcularVentasPromedioDiario30Dias();
    if (ventasPromedio <= 0) {
      return null; // Evitar división por 0
    }
    final siembras7Dias = _calcularSiembras7Dias();
    return siembras7Dias / ventasPromedio;
  }

  /// Calcula las siembras de hoy para un cultivo específico
  int _calcularSiembrasHoyPorCultivo(String cultivoKey) {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final finHoy = inicioHoy.add(const Duration(days: 1));

    return motor.movimientos
        .where((movimiento) =>
            movimiento.tipo == TipoMovimiento.siembra &&
            !movimiento.anulado &&
            movimiento.fecha.isAfter(inicioHoy.subtract(const Duration(milliseconds: 1))) &&
            movimiento.fecha.isBefore(finHoy))
        .map((movimiento) {
          try {
            final lote = motor.obtenerLote(movimiento.loteId);
            return lote.cultivoKey == cultivoKey ? movimiento.cantidad ?? 0 : 0;
          } catch (e) {
            return 0;
          }
        })
        .fold(0, (suma, cantidad) => suma + cantidad);
  }

  /// Calcula las siembras de los últimos 7 días para un cultivo específico
  int _calcularSiembras7DiasPorCultivo(String cultivoKey) {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final finHoy = inicioHoy.add(const Duration(days: 1));
    final inicio7DiasAtras = inicioHoy.subtract(const Duration(days: 6));

    return motor.movimientos
        .where((movimiento) =>
            movimiento.tipo == TipoMovimiento.siembra &&
            !movimiento.anulado &&
            movimiento.fecha.isAfter(inicio7DiasAtras.subtract(const Duration(milliseconds: 1))) &&
            movimiento.fecha.isBefore(finHoy))
        .map((movimiento) {
          try {
            final lote = motor.obtenerLote(movimiento.loteId);
            return lote.cultivoKey == cultivoKey ? movimiento.cantidad ?? 0 : 0;
          } catch (e) {
            return 0;
          }
        })
        .fold(0, (suma, cantidad) => suma + cantidad);
  }

  /// Calcula el promedio diario de ventas de los últimos 30 días para un cultivo específico
  double _calcularVentasPromedioDiario30DiasPorCultivo(String cultivoKey) {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final finHoy = inicioHoy.add(const Duration(days: 1));
    final inicio30DiasAtras = inicioHoy.subtract(const Duration(days: 29));

    final ventas30Dias = motor.movimientos
        .where((movimiento) =>
            movimiento.tipo == TipoMovimiento.venta &&
            !movimiento.anulado &&
            movimiento.fecha.isAfter(inicio30DiasAtras.subtract(const Duration(milliseconds: 1))) &&
            movimiento.fecha.isBefore(finHoy))
        .map((movimiento) {
          try {
            final lote = motor.obtenerLote(movimiento.loteId);
            return lote.cultivoKey == cultivoKey ? movimiento.cantidad ?? 0 : 0;
          } catch (e) {
            return 0;
          }
        })
        .fold(0, (suma, cantidad) => suma + cantidad);

    return ventas30Dias / 30.0;
  }

  /// Calcula la cobertura en días para un cultivo específico
  double? _calcularCoberturaPorCultivo(String cultivoKey) {
    final ventasPromedio = _calcularVentasPromedioDiario30DiasPorCultivo(cultivoKey);
    if (ventasPromedio <= 0) {
      return null; // Evitar división por 0
    }
    final siembras7Dias = _calcularSiembras7DiasPorCultivo(cultivoKey);
    return siembras7Dias / ventasPromedio;
  }

  /// Obtiene la lista de coberturas por cultivo (solo cultivos con ventas > 0)
  /// Ordenada por menor cobertura primero (más riesgoso arriba)
  List<MapEntry<String, double>> _obtenerCoberturasPorCultivo() {
    final coberturas = <String, double>{};

    // Obtener cultivos únicos de los movimientos
    final cultivosConVentas = <String>{};
    for (final movimiento in motor.movimientos) {
      if (movimiento.tipo == TipoMovimiento.venta && !movimiento.anulado) {
        try {
          final lote = motor.obtenerLote(movimiento.loteId);
          cultivosConVentas.add(lote.cultivoKey);
        } catch (e) {
          // Ignorar si no se puede obtener el lote
        }
      }
    }

    // Calcular cobertura solo para cultivos con ventas
    for (final cultivoKey in cultivosConVentas) {
      final cobertura = _calcularCoberturaPorCultivo(cultivoKey);
      if (cobertura != null) {
        coberturas[cultivoKey] = cobertura;
      }
    }

    // Ordenar por menor cobertura primero
    final entradas = coberturas.entries.toList();
    entradas.sort((a, b) => a.value.compareTo(b.value));

    return entradas;
  }

  @override
  Widget build(BuildContext context) {
    // Calcular stocks usando keys internas
    final stockLechuga = motor.calcularStockPorCultivo(CultivoKeys.lechuga);
    final stockCilantro = motor.calcularStockPorCultivo(CultivoKeys.cilantro);
    final stockAcelga = motor.calcularStockPorCultivo(CultivoKeys.acelga);
    final stockRucula = motor.calcularStockPorCultivo(CultivoKeys.rucula);
    final stockPerejil = motor.calcularStockPorCultivo(CultivoKeys.perejil);
    final totalMovimientos = motor.movimientos.length;
    final movimientosAnulados = motor.movimientos.where((m) => m.anulado).length;
    final siembrasHoy = _calcularSiembrasHoy();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Invernadero MVP'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Botón para ir a ventas
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VentasScreen(motor: motor),
                    ),
                  ).then((_) {
                    // Actualizar la pantalla al regresar
                    setState(() {});
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.shopping_cart,
                            size: 32,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Registrar Venta',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Registrar una nueva venta de cultivos',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                      if (siembrasHoy > 0) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Hoy sembrado: $siembrasHoy',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ),
                              if (_debeMostrarAlerta()) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.orange.withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        size: 16,
                                        color: Colors.orange.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Bajo promedio (7d)',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.orange.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      // Badge de meta diaria (siempre visible)
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildBadgeMetaDiaria(),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '7d: ${_calcularSiembras7Dias()} · 30d: ${_calcularSiembras30Dias()}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                            ),
                            const SizedBox(height: 4),
                            _buildCoberturaPorCultivo(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Botón para ir a reportes
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReportesScreen(motor: motor),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bar_chart,
                        size: 32,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reportes',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ver reportes diarios de ventas',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Botón para ver siembras
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SiembrasListaScreen(motor: motor),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.spa,
                        size: 32,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Siembras',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ver historial de siembras realizadas',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
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
            // Stock por cultivo
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock por Cultivo',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildStockItem(CultivoLabels.obtenerLabel(CultivoKeys.lechuga), stockLechuga),
                    const SizedBox(height: 8),
                    _buildStockItem(CultivoLabels.obtenerLabel(CultivoKeys.cilantro), stockCilantro),
                    const SizedBox(height: 8),
                    _buildStockItem(CultivoLabels.obtenerLabel(CultivoKeys.acelga), stockAcelga),
                    const SizedBox(height: 8),
                    _buildStockItem(CultivoLabels.obtenerLabel(CultivoKeys.rucula), stockRucula),
                    const SizedBox(height: 8),
                    _buildStockItem(CultivoLabels.obtenerLabel(CultivoKeys.perejil), stockPerejil),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Stock por etapa
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock por Etapa',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ...Etapa.values.map((etapa) {
                      final stock = motor.calcularStockPorEtapa(etapa);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _buildStockItem(
                          _formatearEtapa(etapa),
                          stock,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Movimientos
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Movimientos',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildStockItem('Total', totalMovimientos),
                    const SizedBox(height: 8),
                    _buildStockItem('Anulados', movimientosAnulados),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockItem(String label, int valor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
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

  /// Obtiene el color del semáforo según la cobertura en días
  Color _obtenerColorSemáforo(double coberturaDias) {
    if (coberturaDias >= 21) {
      return Colors.green;
    } else if (coberturaDias >= 7) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Widget _buildCoberturaPorCultivo() {
    final coberturas = _obtenerCoberturasPorCultivo();

    if (coberturas.isEmpty) {
      return Text(
        'Cobertura por cultivo: sin ventas (30d)',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
      );
    }

    // Limitar a 2-4 líneas máximo
    final maxCultivos = (coberturas.length > 4) ? 4 : coberturas.length;
    final cultivosAMostrar = coberturas.take(maxCultivos).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: cultivosAMostrar.map((entry) {
        final label = CultivoLabels.obtenerLabel(entry.key);
        final coberturaDias = entry.value;
        final colorSemáforo = _obtenerColorSemáforo(coberturaDias);
        
        // Calcular meta diaria para este cultivo
        final hoyCultivo = _calcularSiembrasHoyPorCultivo(entry.key);
        final metaCultivo = METAS_DIARIAS_POR_CULTIVO[entry.key];
        
        // Determinar color y estado de la meta
        Color? colorMeta;
        if (metaCultivo != null) {
          if (hoyCultivo >= metaCultivo) {
            colorMeta = Colors.green;
          } else if (hoyCultivo > 0) {
            colorMeta = Colors.orange;
          } else {
            colorMeta = Colors.red;
          }
        }
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: colorSemáforo,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$label: ~${coberturaDias.toStringAsFixed(0)}d',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
            ),
            if (metaCultivo != null && colorMeta != null) ...[
              const SizedBox(width: 8),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: colorMeta,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '· Meta: $hoyCultivo/$metaCultivo',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
              ),
            ],
          ],
        );
      }).toList(),
    );
  }

  Widget _buildBadgeMetaDiaria() {
    final estadoMeta = _obtenerEstadoMetaDiaria();
    final colorEstado = estadoMeta['color'] as Color;
    final textoEstado = estadoMeta['texto'] as String;
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: colorEstado.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorEstado.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: colorEstado,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            textoEstado,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorEstado.shade700,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
