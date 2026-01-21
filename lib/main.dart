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
  Set<String> _alertasActivas = {};
  Map<String, String> _coberturas = {};

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
    // Si cobertura == 🔴, se activa la alerta (persistente)
    // Si cobertura != 🔴, se desactiva la alerta
    await AlertasCoberturaService.actualizarAlertasSegunCobertura(coberturas);

    // Cargar alertas activas desde SharedPreferences
    final alertasActivas =
        await AlertasCoberturaService.obtenerAlertasActivas();

    if (mounted) {
      setState(() {
        _coberturas = coberturas;
        _alertasActivas = alertasActivas;
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

  @override
  Widget build(BuildContext context) {
    final stockLechuga = motor.calcularStockPorCultivo('lechuga');
    final stockTomate = motor.calcularStockPorCultivo('tomate');
    final totalMovimientos = motor.movimientos.length;
    final movimientosAnulados = motor.movimientos
        .where((m) => m.anulado)
        .length;

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
            // Cards de cultivo con alertas
            ...CultivoKeys.todas.map((cultivoKey) {
              // Recalcular cobertura en tiempo real usando la meta efectiva
              // Nota: esto se calcula de forma síncrona, pero las metas se cargan en _cargarAlertasYCoberturas
              // Para una mejor experiencia, usamos el valor de _coberturas que ya tiene las metas aplicadas
              final cobertura = _coberturas[cultivoKey] ?? '🟢';
              final stock = motor.calcularStockPorCultivo(cultivoKey);
              // La alerta se muestra si la cobertura es 🔴 (stock == 0)
              // La persistencia se maneja en SharedPreferences (se actualiza en _cargarAlertasYCoberturas)
              // para que no desaparezca por navegación ni rebuild
              // La alerta solo desaparece cuando se registra una siembra válida o la cobertura deja de ser 🔴
              // Verificamos tanto la cobertura actual como el estado persistente para mantener la persistencia
              final tieneAlertaPersistente = _alertasActivas.contains(
                cultivoKey,
              );
              final mostrarAlerta = cobertura == '🔴' && tieneAlertaPersistente;

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
                              CultivoLabels.obtenerLabel(cultivoKey),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(cobertura, style: const TextStyle(fontSize: 24)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Stock: $stock',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (mostrarAlerta)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red.shade300),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Text(
                              'Sembrar hoy',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade900,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
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
                    _buildStockItem('Lechuga', stockLechuga),
                    const SizedBox(height: 8),
                    _buildStockItem('Tomate', stockTomate),
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
                        child: _buildStockItem(_formatearEtapa(etapa), stock),
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
}
