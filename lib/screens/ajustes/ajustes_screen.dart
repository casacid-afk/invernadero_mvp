import 'package:flutter/material.dart';
import '../../domain/cultivos.dart';
import '../../services/ajustes_service.dart';
import '../../utils/parsers.dart';

class AjustesScreen extends StatefulWidget {
  const AjustesScreen({super.key});

  @override
  State<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, int> _metasIniciales = {};
  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _cargarMetas();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarMetas() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final metas = await AjustesService.cargarMetas();

      for (final cultivoKey in CultivoKeys.todas) {
        final meta = metas[cultivoKey] ?? 0;
        _metasIniciales[cultivoKey] = meta;
        _controllers[cultivoKey] = TextEditingController(text: meta.toString());
        _controllers[cultivoKey]!.addListener(() {
          _verificarCambios();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar metas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _verificarCambios() {
    bool hayCambios = false;
    for (final cultivoKey in CultivoKeys.todas) {
      final controller = _controllers[cultivoKey];
      if (controller != null) {
        final valorActual = parsearIntConDefault(controller.text, 0);
        final valorInicial = _metasIniciales[cultivoKey] ?? 0;
        if (valorActual != valorInicial) {
          hayCambios = true;
          break;
        }
      }
    }

    if (hayCambios != _hasChanges) {
      setState(() {
        _hasChanges = hayCambios;
      });
    }
  }

  Future<void> _guardarMeta(String cultivoKey) async {
    final controller = _controllers[cultivoKey];
    if (controller == null) return;

    final valorTexto = controller.text.trim();
    if (valorTexto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un valor válido'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final meta = int.tryParse(valorTexto);
    if (meta == null || meta < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La meta debe ser un número entero mayor o igual a 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await AjustesService.guardarMeta(cultivoKey, meta);
      _metasIniciales[cultivoKey] = meta;
      _verificarCambios();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Meta de ${CultivoLabels.obtenerLabel(cultivoKey)} guardada: $meta',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _guardarTodas() async {
    bool error = false;
    for (final cultivoKey in CultivoKeys.todas) {
      final controller = _controllers[cultivoKey];
      if (controller == null) continue;

      final valorTexto = controller.text.trim();
      if (valorTexto.isEmpty) {
        error = true;
        continue;
      }

      final meta = int.tryParse(valorTexto);
      if (meta == null || meta < 0) {
        error = true;
        continue;
      }

      try {
        await AjustesService.guardarMeta(cultivoKey, meta);
        _metasIniciales[cultivoKey] = meta;
      } catch (e) {
        error = true;
      }
    }

    _verificarCambios();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error
                ? 'Algunas metas no se pudieron guardar'
                : 'Todas las metas guardadas correctamente',
          ),
          backgroundColor: error ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        actions: [
          if (_hasChanges)
            TextButton.icon(
              onPressed: _guardarTodas,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text(
                'Guardar todo',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: CultivoKeys.todas.length,
              itemBuilder: (context, index) {
                final cultivoKey = CultivoKeys.todas[index];
                final controller = _controllers[cultivoKey];
                final cultivoLabel = CultivoLabels.obtenerLabel(cultivoKey);

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
                                cultivoLabel,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.save),
                              onPressed: () => _guardarMeta(cultivoKey),
                              tooltip: 'Guardar meta de $cultivoLabel',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Meta diaria',
                            hintText: 'Ingresa la meta diaria',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.track_changes),
                            suffixText: 'unidades',
                          ),
                          onSubmitted: (_) => _guardarMeta(cultivoKey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
