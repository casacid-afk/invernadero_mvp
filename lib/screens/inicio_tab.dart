import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
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
import 'clientes_screen.dart';
import 'cuentas_por_cobrar_screen.dart';
import 'resumenes_cobro_screen.dart';

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

  /// Construye el bloque de accesos rápidos (lista compacta)
  Widget _buildBloqueAccion(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );

    Widget _quickTile({
      required IconData icon,
      required String label,
      required VoidCallback onPressed,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
            child: Row(
              children: [
                Icon(icon, size: 22, color: accentColor),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: textStyle)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: _cardDecorationPastel(context, AppPastel.ventas),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Accesos rápidos',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: 0.2,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          _quickTile(
            icon: Icons.add_circle_outline,
            label: 'Registrar siembra',
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
          ),
          _quickTile(
            icon: Icons.shopping_cart_outlined,
            label: 'Registrar venta',
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
          ),
          _quickTile(
            icon: Icons.swap_horiz,
            label: 'Registrar traspaso',
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
          ),
          _quickTile(
            icon: Icons.remove_circle_outline,
            label: 'Registrar merma',
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
          ),
          _quickTile(
            icon: Icons.payments_outlined,
            label: 'Registrar gasto',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => GastosScreen(firestoreRepo: widget.firestoreRepo),
                ),
              );
            },
          ),
          _quickTile(
            icon: Icons.insights_outlined,
            label: 'Resumen económico',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ResumenEconomicoScreen(firestoreRepo: widget.firestoreRepo),
                ),
              );
            },
          ),
          _quickTile(
            icon: Icons.people_outline,
            label: 'Clientes',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ClientesScreen(firestoreRepo: widget.firestoreRepo),
                ),
              );
            },
          ),
          _quickTile(
            icon: Icons.receipt_long_outlined,
            label: 'Cuentas por cobrar',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CuentasPorCobrarScreen(firestoreRepo: widget.firestoreRepo),
                ),
              );
            },
          ),
          _quickTile(
            icon: Icons.description_outlined,
            label: 'Resúmenes de cobro',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ResumenesCobroScreen(firestoreRepo: widget.firestoreRepo),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Widget helper para crear módulos con header consistente y fondo pastel por tipo
  Widget _buildModuleCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
    VoidCallback? onTap,
    PastelVariant pastel = AppPastel.neutral,
  }) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: pastel.accent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.2,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );

    final container = Container(
      decoration: _cardDecorationPastel(context, pastel),
      child: onTap != null
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: content,
              ),
            )
          : content,
    );
    return container;
  }

  Widget _buildCardSiembras(BuildContext context) {
    final siembrasHoy = _contarSiembrasHoy();
    final siembrasPorCultivo = _contarSiembrasHoyPorCultivo();
    const pastel = AppPastel.siembras;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: pastel.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Hoy: $siembrasHoy',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: pastel.accent,
          fontSize: 13,
        ),
      ),
    );

    return _buildModuleCard(
      context: context,
      title: 'Siembras',
      icon: Icons.eco,
      pastel: pastel,
      trailing: badge,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SiembrasListaScreen(motor: widget.motor),
          ),
        );
      },
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: CultivoKeys.todas.map((cultivoKey) {
          final cantidad = siembrasPorCultivo[cultivoKey] ?? 0;
          final label = CultivoLabels.obtenerLabel(cultivoKey);
          return Text(
            '$label: $cantidad',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCardFlujo(BuildContext context) {
    return _buildModuleCard(
      context: context,
      title: 'Flujo',
      icon: Icons.timeline_outlined,
      pastel: AppPastel.sugerencia,
      trailing: TextButton(
        style: TextButton.styleFrom(
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => FlujoScreen(motor: widget.motor),
            ),
          );
        },
        child: Text(
          'Abrir',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
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
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCardSugerenciaSiembra(BuildContext context) {
    final theme = Theme.of(context);
    Widget content;

    if (_cargandoSugerencias && _sugerencias.isEmpty) {
      content = const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (_errorSugerencias != null && _sugerencias.isEmpty) {
      content = Text(
        _errorSugerencias!,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.red.shade700,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: CultivoKeys.todas.map((cultivoKey) {
          final s = _sugerencias[cultivoKey];
          final label = CultivoLabels.obtenerLabel(cultivoKey);
          final bodyStyle = theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          );

          if (s == null) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('$label: sin datos de ventas recientes', style: bodyStyle),
            );
          }

          Color estadoColor = AppColors.textSecondary;
          if (s.estado == 'Sembrar ahora') estadoColor = Colors.red.shade700;
          else if (s.estado == 'Vigilar') estadoColor = Colors.orange.shade700;
          else if (s.estado == 'Bien por ahora') estadoColor = Colors.green.shade700;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                if (s.ventas28Dias == 0) ...[
                  Text('Sin ventas recientes', style: bodyStyle),
                  Text('Stock: ${s.stockVendible} u. vendible | ${s.stockEnProceso} u. en proceso', style: bodyStyle),
                  Text('Sugerencia: 0 u.', style: bodyStyle?.copyWith(fontWeight: FontWeight.w700)),
                ] else ...[
                  Text('Demanda sem.: ${s.demandaSemanalPromedio.toStringAsFixed(1)} u.', style: bodyStyle),
                  Text('Stock: ${s.stockVendible} u. vendible | ${s.stockEnProceso} u. en proceso', style: bodyStyle),
                  Text('Cobertura: ${s.coberturaTotalSemanas.toStringAsFixed(1)} sem.', style: bodyStyle),
                  Text('Sugerencia: ${s.siembraSugerida} u.', style: bodyStyle?.copyWith(fontWeight: FontWeight.w700)),
                ],
                Text('Estado: ${s.estado}', style: bodyStyle?.copyWith(color: estadoColor)),
              ],
            ),
          );
        }).toList(),
      );
    }

    return _buildModuleCard(
      context: context,
      title: 'Sugerencia de siembra',
      icon: Icons.spa_outlined,
      pastel: AppPastel.sugerencia,
      child: content,
    );
  }

  Widget _buildCardAlertaSiembras(BuildContext context) {
    final estados = _calcularEstadoSiembrasHoyPorCultivo();
    final todosOk = estados.values.every((e) => e['estado'] == 'ok');
    final theme = Theme.of(context);

    final cultivosConMeta = CultivoKeys.todas.where((cultivoKey) {
      final estado = estados[cultivoKey]!;
      final meta = estado['meta'] as int;
      return meta > 0;
    }).toList();

    Widget content;
    if (todosOk) {
      content = Row(
        children: [
          Icon(Icons.check_circle_outline, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'Siembras de hoy en meta',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: cultivosConMeta.map((cultivoKey) {
          final estado = estados[cultivoKey]!;
          final siembras = estado['siembras'] as int;
          final meta = estado['meta'] as int;
          final esOk = estado['estado'] == 'ok';
          final label = CultivoLabels.obtenerLabel(cultivoKey);

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  esOk ? Icons.check_circle_outline : Icons.info_outline,
                  size: 18,
                  color: esOk ? Colors.green.shade700 : Colors.orange.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  '$label: $siembras / $meta',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
      icon: Icons.notifications_outlined,
      pastel: AppPastel.stock,
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

  /// Estilo común para tarjetas: borde suave, radio consistente, sombra muy suave
  static BoxDecoration _cardDecoration(BuildContext context) {
    return BoxDecoration(
      color: AppPastel.neutral.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppPastel.neutral.border, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  /// Tarjeta con fondo pastel por tipo de módulo (siembras, ventas, stock, sugerencia, neutral)
  static BoxDecoration _cardDecorationPastel(BuildContext context, PastelVariant pastel) {
    return BoxDecoration(
      color: pastel.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: pastel.border, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invernadero',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Panel de hoy',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ajustes',
            onPressed: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (context) => const AjustesScreen(),
                    ),
                  )
                  .then((_) {
                    _cargarAlertasYCoberturas();
                  });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          
          _buildBloqueAccion(context),
          const SizedBox(height: 10),
          _buildCardSiembras(context),
          const SizedBox(height: 10),
          _buildCardAlertaSiembras(context),
          const SizedBox(height: 10),
          _buildCardSugerenciaSiembra(context),
          const SizedBox(height: 10),
          _buildCardFlujo(context),
          const SizedBox(height: 16),
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


