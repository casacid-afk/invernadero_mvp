import 'package:flutter/material.dart';
import '../data/invernadero_firestore_repo.dart';

class MovimientosTabScreen extends StatefulWidget {
  final InvernaderoFirestoreRepo firestoreRepo;

  const MovimientosTabScreen({super.key, required this.firestoreRepo});

  @override
  State<MovimientosTabScreen> createState() => _MovimientosTabScreenState();
}

class _MovimientosTabScreenState extends State<MovimientosTabScreen> {
  List<Map<String, dynamic>>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _items = null;
    });
    try {
      final list = await widget.firestoreRepo.obtenerMovimientos();
      if (mounted) {
        setState(() {
          _items = list.reversed.toList();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  String _formatFecha(dynamic value) {
    if (value == null) return '—';
    if (value is String) {
      final d = DateTime.tryParse(value);
      if (d != null) return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      return value;
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Movimientos'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[700]),
              const SizedBox(height: 16),
              Text(
                'Error al cargar movimientos',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                textAlign: TextAlign.center,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }
    if (_items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items!.isEmpty) {
      return Center(
        child: Text(
          'No hay movimientos aún',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _items!.length,
      itemBuilder: (context, index) {
        final m = _items![index];
        final tipo = m['tipo']?.toString() ?? '—';
        final cultivoKey = m['cultivoKey']?.toString() ?? '—';
        final cantidad = m['cantidad'];
        final cantidadStr = cantidad != null ? cantidad.toString() : '—';
        final loteId = m['loteId']?.toString() ?? '—';
        final etapaOrigen = m['etapaOrigen']?.toString();
        final etapaDestino = m['etapaDestino']?.toString();
        final etapas = <String>[];
        if (etapaOrigen != null && etapaOrigen.isNotEmpty) etapas.add(etapaOrigen);
        if (etapaDestino != null && etapaDestino.isNotEmpty) etapas.add(etapaDestino);
        final etapaStr = etapas.isEmpty ? '—' : etapas.join(' → ');
        final detalle = m['detalle']?.toString();
        final fecha = _formatFecha(m['fecha']);

        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          child: ListTile(
            title: Text(
              '$tipo · $cultivoKey · $cantidadStr',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loteId != '—') Text('Lote: $loteId', style: Theme.of(context).textTheme.bodySmall),
                if (etapaStr != '—') Text('Etapa: $etapaStr', style: Theme.of(context).textTheme.bodySmall),
                if (detalle != null && detalle.isNotEmpty) Text(detalle, style: Theme.of(context).textTheme.bodySmall),
                Text('Fecha: $fecha', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
