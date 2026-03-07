import 'package:flutter/material.dart';
import '../data/invernadero_firestore_repo.dart';
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          InicioTab(motor: widget.motor, firestoreRepo: widget.firestoreRepo),
          SiembrasListaScreen(motor: widget.motor),
          VentasScreen(motor: widget.motor, firestoreRepo: widget.firestoreRepo),
          StockTabScreen(motor: widget.motor),
          MovimientosTabScreen(),
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

