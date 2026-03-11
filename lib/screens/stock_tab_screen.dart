import 'package:flutter/material.dart';
import '../data/invernadero_firestore_repo.dart';
import '../domain/motor_invernadero.dart';
import '../domain/etapa.dart';
import '../domain/cultivos.dart';
import '../services/alertas_cobertura_service.dart';
import '../services/ajustes_service.dart';
import '../widgets/cobertura_badge.dart';
import 'siembras/siembra_nueva_screen.dart';

class StockTabScreen extends StatefulWidget {
  final MotorInvernadero motor;
  final InvernaderoFirestoreRepo firestoreRepo;

  const StockTabScreen({super.key, required this.motor, required this.firestoreRepo});

  @override
  State<StockTabScreen> createState() => _StockTabScreenState();
}

class _StockTabScreenState extends State<StockTabScreen> {
  Map<String, String> _coberturas = {};

  @override
  void initState() {
    super.initState();
    _cargarCoberturas();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cargarCoberturas();
  }

  Future<void> _cargarCoberturas() async {
    // Cargar metas desde ajustes
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

  /// Widget helper para crear módulos con header consistente
  Widget _buildModuleCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 10),
            child,
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

    // Recargar coberturas al volver
    if (resultado == true && mounted) {
      _cargarCoberturas();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Stock'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
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
                final stock = widget.motor.calcularStockPorCultivo(cultivoKey);
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
                final stock = widget.motor.calcularStockPorEtapa(etapa);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _buildStockItem(_formatearEtapa(etapa), stock),
                );
              }).toList(),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

