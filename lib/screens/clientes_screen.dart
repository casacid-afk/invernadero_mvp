import 'package:flutter/material.dart';

import '../data/invernadero_firestore_repo.dart';

class ClientesScreen extends StatefulWidget {
  final InvernaderoFirestoreRepo firestoreRepo;

  const ClientesScreen({
    super.key,
    required this.firestoreRepo,
  });

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  bool _cargando = false;
  String? _error;
  List<Map<String, dynamic>> _clientes = [];

  @override
  void initState() {
    super.initState();
    _cargarClientes();
  }

  Future<void> _cargarClientes() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final items = await widget.firestoreRepo.obtenerClientes();
      if (!mounted) return;
      setState(() {
        _clientes = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al cargar clientes: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  Future<void> _mostrarDialogoNuevoCliente() async {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController();
    String tipo = 'restaurante';
    bool activo = true;

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nuevo cliente'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor ingrese un nombre';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: tipo,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'restaurante',
                        child: Text('Restaurante'),
                      ),
                      DropdownMenuItem(
                        value: 'supermercado',
                        child: Text('Supermercado'),
                      ),
                      DropdownMenuItem(
                        value: 'otro',
                        child: Text('Otro'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      tipo = value;
                    },
                  ),
                  const SizedBox(height: 16),
                  StatefulBuilder(
                    builder: (context, setStateDialog) {
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Activo'),
                        value: activo,
                        onChanged: (value) {
                          setStateDialog(() {
                            activo = value ?? true;
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                final nombre = nombreController.text.trim();
                try {
                  await widget.firestoreRepo.guardarCliente({
                    'nombre': nombre,
                    'tipo': tipo,
                    'activo': activo,
                  });
                  if (!mounted) return;
                  Navigator.of(context).pop(true);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al guardar cliente: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (resultado == true) {
      await _cargarClientes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Clientes'),
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
                : _clientes.isEmpty
                    ? const Center(
                        child: Text('No hay clientes aún'),
                      )
                    : ListView.separated(
                        itemCount: _clientes.length,
                        separatorBuilder: (_, __) => const Divider(height: 8),
                        itemBuilder: (context, index) {
                          final c = _clientes[index];
                          final nombre = c['nombre']?.toString() ?? '';
                          final tipo = c['tipo']?.toString() ?? '';
                          final activo = c['activo'] == true;

                          String tipoLabel;
                          switch (tipo) {
                            case 'restaurante':
                              tipoLabel = 'Restaurante';
                              break;
                            case 'supermercado':
                              tipoLabel = 'Supermercado';
                              break;
                            default:
                              tipoLabel = 'Otro';
                          }

                          return ListTile(
                            title: Text(nombre),
                            subtitle: Text(tipoLabel),
                            trailing: activo
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : const Icon(Icons.pause_circle_filled,
                                    color: Colors.grey),
                          );
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogoNuevoCliente,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

