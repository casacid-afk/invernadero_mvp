import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../data/invernadero_firestore_repo.dart';
import '../navigation_observer.dart';
import 'resumen_cobro_detalle_screen.dart';

class ResumenesCobroScreen extends StatefulWidget {
  final InvernaderoFirestoreRepo firestoreRepo;

  const ResumenesCobroScreen({
    super.key,
    required this.firestoreRepo,
  });

  @override
  State<ResumenesCobroScreen> createState() => _ResumenesCobroScreenState();
}

enum _FiltroResumenCobro { pendientes, pagados, obsoletos, todos }
enum _FiltroPeriodoResumen { todos, manual, semanal, mensual, anual }
enum _OrdenResumenCobro {
  masNuevos,
  masAntiguos,
  mayorMonto,
  menorMonto,
  clienteAZ,
}

class _ResumenesCobroScreenState extends State<ResumenesCobroScreen>
    with RouteAware {
  final DateFormat _formatoFecha =
      DateFormat('dd-MM-yyyy HH:mm', 'es_CL');

  bool _cargando = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  _FiltroResumenCobro _filtro = _FiltroResumenCobro.pendientes;
  String _query = '';
  _FiltroPeriodoResumen _filtroPeriodo = _FiltroPeriodoResumen.todos;
  _OrdenResumenCobro _orden = _OrdenResumenCobro.masNuevos;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Se llama cuando esta pantalla vuelve a quedar visible porque
  /// se hizo pop de otra ruta que estaba encima.
  @override
  void didPopNext() {
    _cargar();
  }

  /// Fecha clave común para ordenar y elegir el resumen activo por cliente.
  /// Prioriza updatedAt; si no existe o no es parseable, usa createdAt.
  DateTime? _fechaClaveResumen(Map<String, dynamic> data) {
    final rawUpdated = data['updatedAt'];
    final rawCreated = data['createdAt'];

    DateTime? fecha;
    if (rawUpdated is Timestamp) {
      fecha = rawUpdated.toDate();
    } else if (rawUpdated is DateTime) {
      fecha = rawUpdated;
    } else if (rawUpdated != null) {
      fecha = DateTime.tryParse(rawUpdated.toString());
    }
    fecha ??= () {
      if (rawCreated is Timestamp) {
        return rawCreated.toDate();
      } else if (rawCreated is DateTime) {
        return rawCreated;
      } else if (rawCreated != null) {
        return DateTime.tryParse(rawCreated.toString());
      }
      return null;
    }();

    return fecha;
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final snapshot = await widget.firestoreRepo.resumenesCobro.get();
      final items = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      // Clasificar resúmenes obsoletos: no pagados cuyas ventas ya no están abiertas
      final obsoletosIds =
          await _detectarResumenesObsoletos(items, widget.firestoreRepo);

      if (!mounted) return;
      setState(() {
        _items = items
            .map((r) => {
                  ...r,
                  'esObsoleto': obsoletosIds.contains(r['id']),
                })
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al cargar resúmenes de cobro: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _itemsFiltrados {
    if (_filtro == _FiltroResumenCobro.todos) {
      return _items;
    }

    final base = _items.where((r) {
      final estado = r['estado']?.toString();
      final esObsoleto = r['esObsoleto'] == true;
      if (_filtro == _FiltroResumenCobro.pagados) {
        return estado == 'pagado';
      }
      if (_filtro == _FiltroResumenCobro.obsoletos) {
        return esObsoleto;
      }
      // Pendientes: todo lo que no sea 'pagado' y no esté obsoleto
      return estado != 'pagado' && !esObsoleto;
    }).toList();

    if (_filtro != _FiltroResumenCobro.pendientes) {
      return base;
    }

    // Para "Pendientes", elegir un único resumen "abierto" activo por cliente,
    // usando la misma prioridad que en otras pantallas: updatedAt desc,
    // luego createdAt desc.
    final Map<String, Map<String, dynamic>> porCliente = {};
    final List<Map<String, dynamic>> sinCliente = [];

    for (final r in base) {
      final clienteId = r['clienteId']?.toString();
      if (clienteId == null || clienteId.isEmpty) {
        sinCliente.add(r);
        continue;
      }

      final existente = porCliente[clienteId];
      if (existente == null) {
        porCliente[clienteId] = r;
        continue;
      }

      final fechaNuevo = _fechaClaveResumen(r);
      final fechaExistente = _fechaClaveResumen(existente);

      if (fechaExistente == null && fechaNuevo == null) {
        // Si ninguna tiene fecha interpretable, mantener el primero.
        continue;
      }
      if (fechaExistente == null && fechaNuevo != null) {
        porCliente[clienteId] = r;
        continue;
      }
      if (fechaExistente != null &&
          fechaNuevo != null &&
          fechaNuevo.isAfter(fechaExistente)) {
        porCliente[clienteId] = r;
      }
    }

    final resultado = <Map<String, dynamic>>[];
    resultado.addAll(porCliente.values);
    resultado.addAll(sinCliente);
    return resultado;
  }

  List<Map<String, dynamic>> get _itemsFiltradosPorPeriodo {
    final base = _itemsFiltrados;
    if (_filtroPeriodo == _FiltroPeriodoResumen.todos) {
      return base;
    }

    final String valorFiltro = switch (_filtroPeriodo) {
      _FiltroPeriodoResumen.todos => '',
      _FiltroPeriodoResumen.manual => 'manual',
      _FiltroPeriodoResumen.semanal => 'semanal',
      _FiltroPeriodoResumen.mensual => 'mensual',
      _FiltroPeriodoResumen.anual => 'anual',
    };

    return base.where((r) {
      final tipo = r['tipoPeriodo']?.toString();
      if (tipo == null || tipo.isEmpty) return false;
      return tipo == valorFiltro;
    }).toList();
  }

  List<Map<String, dynamic>> get _itemsFiltradosYBuscados {
    final base = _itemsFiltradosPorPeriodo;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return base;

    return base.where((r) {
      final nombre = r['clienteNombre']?.toString().toLowerCase().trim() ?? '';
      return nombre.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get _itemsOrdenados {
    final lista = List<Map<String, dynamic>>.from(_itemsFiltradosYBuscados);

    int _compararFechaClave(Map<String, dynamic> a, Map<String, dynamic> b) {
      final aFecha = _fechaClaveResumen(a);
      final bFecha = _fechaClaveResumen(b);

      if (aFecha == null && bFecha == null) return 0;
      if (aFecha == null) return -1;
      if (bFecha == null) return 1;
      return aFecha.compareTo(bFecha);
    }

    lista.sort((a, b) {
      switch (_orden) {
        case _OrdenResumenCobro.masNuevos:
          return -_compararFechaClave(a, b);
        case _OrdenResumenCobro.masAntiguos:
          return _compararFechaClave(a, b);
        case _OrdenResumenCobro.mayorMonto:
          final aRaw = a['totalPendiente'];
          final bRaw = b['totalPendiente'];
          final aVal = aRaw is num ? aRaw.toDouble() : 0.0;
          final bVal = bRaw is num ? bRaw.toDouble() : 0.0;
          return bVal.compareTo(aVal);
        case _OrdenResumenCobro.menorMonto:
          final aRaw = a['totalPendiente'];
          final bRaw = b['totalPendiente'];
          final aVal = aRaw is num ? aRaw.toDouble() : 0.0;
          final bVal = bRaw is num ? bRaw.toDouble() : 0.0;
          return aVal.compareTo(bVal);
        case _OrdenResumenCobro.clienteAZ:
          final aNom = a['clienteNombre']?.toString().toLowerCase().trim() ?? '';
          final bNom = b['clienteNombre']?.toString().toLowerCase().trim() ?? '';
          return aNom.compareTo(bNom);
      }
    });

    return lista;
  }

  int get _cantidadResumenesVisibles => _itemsFiltradosYBuscados.length;

  double get _totalResumidoVisible {
    double total = 0;
    for (final r in _itemsFiltradosYBuscados) {
      final totalRaw = r['totalPendiente'];
      if (totalRaw is num) {
        total += totalRaw.toDouble();
      }
    }
    return total;
  }

  String _descripcionFiltroEstado() {
    switch (_filtro) {
      case _FiltroResumenCobro.pendientes:
        return 'Pendientes';
      case _FiltroResumenCobro.pagados:
        return 'Pagados';
      case _FiltroResumenCobro.obsoletos:
        return 'Obsoletos';
      case _FiltroResumenCobro.todos:
        return 'Todos';
    }
  }

  String _descripcionFiltroPeriodo() {
    switch (_filtroPeriodo) {
      case _FiltroPeriodoResumen.todos:
        return 'Todos';
      case _FiltroPeriodoResumen.manual:
        return 'Manual';
      case _FiltroPeriodoResumen.semanal:
        return 'Semanal';
      case _FiltroPeriodoResumen.mensual:
        return 'Mensual';
      case _FiltroPeriodoResumen.anual:
        return 'Anual';
    }
  }

  String _construirTextoResumenLista() {
    final buffer = StringBuffer();
    buffer.writeln('Resumen de resúmenes de cobro');
    buffer.writeln();
    buffer.writeln('Filtro estado: ${_descripcionFiltroEstado()}');
    buffer.writeln('Filtro período: ${_descripcionFiltroPeriodo()}');
    final q = _query.trim();
    if (q.isNotEmpty) {
      buffer.writeln('Búsqueda: "$q"');
    }
    buffer.writeln(
        'Cantidad de resúmenes: $_cantidadResumenesVisibles');
    buffer.writeln(
        'Monto total visible: ${NumberFormat.currency(locale: 'es_CL', symbol: r'$ ', decimalDigits: 0).format(_totalResumidoVisible)}');
    buffer.writeln();
    buffer.writeln('Detalle:');

    for (final r in _itemsOrdenados) {
      final cliente =
          r['clienteNombre']?.toString().trim().isNotEmpty == true
              ? r['clienteNombre'].toString().trim()
              : 'Cliente';
      final totalRaw = r['totalPendiente'];
      final total = (totalRaw is num) ? totalRaw.toDouble() : 0.0;
      final estado = r['estado']?.toString() ?? 'borrador';
      final esObsoleto = r['esObsoleto'] == true;
      final tipoPeriodo = r['tipoPeriodo']?.toString();

      final estadoLabel =
          esObsoleto ? 'obsoleto (sin deuda)' : estado;

      buffer.write('- $cliente: ');
      buffer.write(
          NumberFormat.currency(locale: 'es_CL', symbol: r'$ ', decimalDigits: 0)
              .format(total));
      buffer.write(' | Estado: $estadoLabel');
      if (tipoPeriodo != null && tipoPeriodo.isNotEmpty) {
        buffer.write(' | Período: $tipoPeriodo');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  Future<void> _copiarResumenLista() async {
    if (_itemsOrdenados.isEmpty) return;
    final texto = _construirTextoResumenLista();
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resumen copiado al portapapeles')),
    );
  }

  Future<void> _compartirResumenLista() async {
    if (_itemsOrdenados.isEmpty) return;
    final texto = _construirTextoResumenLista();
    await Share.share(texto);
  }

  String get _mensajeVacioPorFiltro {
    switch (_filtro) {
      case _FiltroResumenCobro.pendientes:
        return 'No hay resúmenes pendientes';
      case _FiltroResumenCobro.pagados:
        return 'No hay resúmenes pagados';
      case _FiltroResumenCobro.obsoletos:
        return 'No hay resúmenes obsoletos';
      case _FiltroResumenCobro.todos:
        return 'No hay resúmenes de cobro guardados';
    }
  }

  String _formatearCreatedAt(dynamic createdAt) {
    if (createdAt == null) return '';
    if (createdAt is Timestamp) {
      return _formatoFecha.format(createdAt.toDate());
    }
    if (createdAt is DateTime) {
      return _formatoFecha.format(createdAt);
    }
    final d = DateTime.tryParse(createdAt.toString());
    if (d == null) return '';
    return _formatoFecha.format(d);
  }

  Widget _buildFiltroChips() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: const Text('Pendientes'),
          selected: _filtro == _FiltroResumenCobro.pendientes,
          onSelected: (value) {
            if (!value) return;
            setState(() {
              _filtro = _FiltroResumenCobro.pendientes;
            });
          },
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Pagados'),
          selected: _filtro == _FiltroResumenCobro.pagados,
          onSelected: (value) {
            if (!value) return;
            setState(() {
              _filtro = _FiltroResumenCobro.pagados;
            });
          },
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Obsoletos'),
          selected: _filtro == _FiltroResumenCobro.obsoletos,
          onSelected: (value) {
            if (!value) return;
            setState(() {
              _filtro = _FiltroResumenCobro.obsoletos;
            });
          },
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Todos'),
          selected: _filtro == _FiltroResumenCobro.todos,
          onSelected: (value) {
            if (!value) return;
            setState(() {
              _filtro = _FiltroResumenCobro.todos;
            });
          },
        ),
      ],
    );
  }

  Widget _buildFiltroPeriodoChips() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Período: Todos'),
          selected: _filtroPeriodo == _FiltroPeriodoResumen.todos,
          onSelected: (value) {
            if (!value) return;
            setState(() {
              _filtroPeriodo = _FiltroPeriodoResumen.todos;
            });
          },
        ),
        ChoiceChip(
          label: const Text('Manual'),
          selected: _filtroPeriodo == _FiltroPeriodoResumen.manual,
          onSelected: (value) {
            if (!value) return;
            setState(() {
              _filtroPeriodo = _FiltroPeriodoResumen.manual;
            });
          },
        ),
        ChoiceChip(
          label: const Text('Semanal'),
          selected: _filtroPeriodo == _FiltroPeriodoResumen.semanal,
          onSelected: (value) {
            if (!value) return;
            setState(() {
              _filtroPeriodo = _FiltroPeriodoResumen.semanal;
            });
          },
        ),
        ChoiceChip(
          label: const Text('Mensual'),
          selected: _filtroPeriodo == _FiltroPeriodoResumen.mensual,
          onSelected: (value) {
            if (!value) return;
            setState(() {
              _filtroPeriodo = _FiltroPeriodoResumen.mensual;
            });
          },
        ),
        ChoiceChip(
          label: const Text('Anual'),
          selected: _filtroPeriodo == _FiltroPeriodoResumen.anual,
          onSelected: (value) {
            if (!value) return;
            setState(() {
              _filtroPeriodo = _FiltroPeriodoResumen.anual;
            });
          },
        ),
      ],
    );
  }

  Widget _buildOrdenDropdown() {
    return DropdownButtonFormField<_OrdenResumenCobro>(
      value: _orden,
      decoration: const InputDecoration(
        labelText: 'Ordenar por',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(
          value: _OrdenResumenCobro.masNuevos,
          child: Text('Más nuevos primero'),
        ),
        DropdownMenuItem(
          value: _OrdenResumenCobro.masAntiguos,
          child: Text('Más antiguos primero'),
        ),
        DropdownMenuItem(
          value: _OrdenResumenCobro.mayorMonto,
          child: Text('Mayor monto'),
        ),
        DropdownMenuItem(
          value: _OrdenResumenCobro.menorMonto,
          child: Text('Menor monto'),
        ),
        DropdownMenuItem(
          value: _OrdenResumenCobro.clienteAZ,
          child: Text('Cliente A-Z'),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _orden = value;
        });
      },
    );
  }

  Widget _buildBuscador() {
    return TextField(
      decoration: const InputDecoration(
        labelText: 'Buscar cliente',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(),
      ),
      onChanged: (value) {
        setState(() {
          _query = value;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Resúmenes de cobro'),
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
                : _items.isEmpty
                    ? const Center(
                        child: Text('No hay resúmenes de cobro guardados'),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildFiltroChips(),
                          const SizedBox(height: 12),
                          _buildFiltroPeriodoChips(),
                          const SizedBox(height: 12),
                          _buildOrdenDropdown(),
                          const SizedBox(height: 12),
                          _buildBuscador(),
                          const SizedBox(height: 12),
                          if (_itemsFiltradosYBuscados.isNotEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Resumen de lista',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Cantidad de resúmenes: $_cantidadResumenesVisibles',
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Monto total visible: ${NumberFormat.currency(
                                        locale: 'es_CL',
                                        symbol: r'$ ',
                                        decimalDigits: 0,
                                      ).format(_totalResumidoVisible)}',
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed:
                                                _itemsOrdenados.isEmpty
                                                    ? null
                                                    : _copiarResumenLista,
                                            icon: const Icon(Icons.copy),
                                            label: const Text(
                                                'Copiar resumen'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed:
                                                _itemsOrdenados.isEmpty
                                                    ? null
                                                    : _compartirResumenLista,
                                            icon: const Icon(Icons.share),
                                            label: const Text(
                                                'Compartir resumen'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (_itemsFiltradosYBuscados.isNotEmpty)
                            const SizedBox(height: 12),
                          Expanded(
                            child: _itemsFiltrados.isEmpty
                                ? Center(
                                    child: Text(_mensajeVacioPorFiltro),
                                  )
                                : _itemsFiltradosYBuscados.isEmpty
                                    ? const Center(
                                        child: Text(
                                            'No hay resúmenes para esa búsqueda'),
                                      )
                                    : RefreshIndicator(
                                        onRefresh: _cargar,
                                        child: ListView.separated(
                                          itemCount: _itemsOrdenados.length,
                                          separatorBuilder: (_, __) =>
                                              const Divider(height: 8),
                                          itemBuilder: (context, index) {
                                            final r = _itemsOrdenados[index];
                                            final nombre =
                                                r['clienteNombre']
                                                        ?.toString() ??
                                                    'Cliente';
                                            final createdAt =
                                                _formatearCreatedAt(
                                                    r['createdAt']);
                                            final totalRaw =
                                                r['totalPendiente'];
                                            final total = (totalRaw is num)
                                                ? totalRaw.toDouble()
                                                : 0.0;
                                            final estado =
                                                r['estado']?.toString() ??
                                                    'borrador';
                                            final esObsoleto =
                                                r['esObsoleto'] == true;
                                            final cantidadEntregasRaw =
                                                r['cantidadEntregas'];
                                            final int? cantidadEntregas =
                                                (cantidadEntregasRaw is num)
                                                    ? cantidadEntregasRaw
                                                        .toInt()
                                                    : null;

                                            final lineas = <String>[];
                                            if (createdAt.isNotEmpty) {
                                              lineas.add(createdAt);
                                            }
                                            if (cantidadEntregas != null) {
                                              lineas.add(
                                                  'Entregas incluidas: $cantidadEntregas');
                                            }
                                            if (esObsoleto) {
                                              lineas.add(
                                                  'Estado: obsoleto (sin deuda)');
                                            } else {
                                              lineas.add('Estado: $estado');
                                            }

                                            return ListTile(
                                              title: Text(
                                                nombre,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              subtitle:
                                                  Text(lineas.join('\n')),
                                              trailing: Text(
                                                NumberFormat.currency(
                                                  locale: 'es_CL',
                                                  symbol: r'$ ',
                                                  decimalDigits: 0,
                                                ).format(total),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              isThreeLine: true,
                                              onTap: () async {
                                                final refrescar =
                                                    await Navigator.of(context)
                                                        .push(
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        ResumenCobroDetalleScreen(
                                                      firestoreRepo:
                                                          widget.firestoreRepo,
                                                      resumenId:
                                                          r['id'] as String,
                                                    ),
                                                  ),
                                                );
                                                if (refrescar == true) {
                                                  _cargar();
                                                }
                                              },
                                            );
                                          },
                                        ),
                                      ),
                          ),
                        ],
                      ),
      ),
    );
  }
}

/// Detecta qué resúmenes no pagados son obsoletos porque ya no tienen ventas abiertas.
Future<Set<String>> _detectarResumenesObsoletos(
  List<Map<String, dynamic>> items,
  InvernaderoFirestoreRepo repo,
) async {
  final Set<String> obsoletos = {};

  for (final r in items) {
    final estado = r['estado']?.toString();
    if (estado == 'pagado') continue;

    final dynamic ventaIdsRaw = r['ventaIds'];
    if (ventaIdsRaw is! List) continue;

    final ventaIds = ventaIdsRaw
        .map((e) => e?.toString())
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toList();
    if (ventaIds.isEmpty) continue;

    var tieneAbiertas = false;

    // Firestore whereIn soporta hasta 10 IDs; hacer chunks por seguridad.
    const chunkSize = 10;
    for (var i = 0; i < ventaIds.length; i += chunkSize) {
      final chunk = ventaIds.sublist(
        i,
        i + chunkSize > ventaIds.length ? ventaIds.length : i + chunkSize,
      );
      try {
        final snapshot = await repo.ventas
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final estadoCobro = data['estadoCobro']?.toString();
          if (estadoCobro == 'abierta') {
            tieneAbiertas = true;
            break;
          }
        }
        if (tieneAbiertas) break;
      } catch (_) {
        // Si falla la lectura, consideramos el resumen como no obsoleto por seguridad.
        tieneAbiertas = true;
        break;
      }
    }

    if (!tieneAbiertas) {
      final id = r['id']?.toString();
      if (id != null && id.isNotEmpty) {
        obsoletos.add(id);
      }
    }
  }

  return obsoletos;
}

