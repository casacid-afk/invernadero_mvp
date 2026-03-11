import 'package:flutter/material.dart';

import '../data/invernadero_firestore_repo.dart';

class CuentasPorCobrarScreen extends StatelessWidget {
  final InvernaderoFirestoreRepo firestoreRepo;

  const CuentasPorCobrarScreen({
    super.key,
    required this.firestoreRepo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Cuentas por cobrar'),
      ),
      body: const Center(
        child: Text('MVP: cuentas por cobrar próximamente'),
      ),
    );
  }
}

