import 'package:flutter/material.dart';
import '../data/invernadero_firestore_repo.dart';
import '../domain/cultivos.dart';
import '../domain/motor_invernadero.dart';
import 'inicio_tab.dart';
import 'siembras/siembras_lista_screen.dart';
import 'ventas_screen.dart';
import 'stock_tab_screen.dart';
import 'movimientos_tab_screen.dart';

class HomeShell extends StatefulWidget {
  final MotorInvernadero motor;
  final InvernaderoFirestoreRepo firestoreRepo;

  const HomeShell({super.key, required this.motor, required this.firestoreRepo});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _rehidratarDesdeFirestore();
  }

  Future<void> _rehidratarDesdeFirestore() async {
    try {
      final movimientos = await widget.firestoreRepo.obtenerMovimientos();

      if (movimientos.isNotEmpty) {
        widget.motor.rehidratarDesdeMovimientos(movimientos);
      } else {
        final data = await widget.firestoreRepo.obtenerStockActual();
        final cultivos = data?['cultivos'];
        final stockPorCultivo = <String, int>{};
        for (final cultivoKey in CultivoKeys.todas) {
          int disponible = 0;
          if (cultivos is Map) {
            final c = cultivos[cultivoKey];
            if (c is Map && c['disponible'] != null) {
              final d = c['disponible'];
              if (d is int) {
                disponible = d;
              } else if (d is num) {
                disponible = d.toInt();
              }
            }
          }
          stockPorCultivo[cultivoKey] = disponible;
        }
        final tieneStock = stockPorCultivo.values.any((v) => v > 0);
        if (tieneStock && widget.motor.lotes.isEmpty) {
          widget.motor.rehidratarStockFinalDesdeMapa(stockPorCultivo);
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Firestore rehidratación: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          InicioTab(motor: widget.motor, firestoreRepo: widget.firestoreRepo),
          SiembrasListaScreen(motor: widget.motor),
          VentasScreen(motor: widget.motor, firestoreRepo: widget.firestoreRepo),
          StockTabScreen(motor: widget.motor, firestoreRepo: widget.firestoreRepo),
          MovimientosTabScreen(firestoreRepo: widget.firestoreRepo),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.eco),
            label: 'Siembras',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Ventas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Stock',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz),
            label: 'Movimientos',
          ),
        ],
      ),
    );
  }
}

