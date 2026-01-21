import 'package:flutter/material.dart';
import '../domain/motor_invernadero.dart';

class TraspasoScreen extends StatelessWidget {
  final MotorInvernadero motor;

  const TraspasoScreen({super.key, required this.motor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Registrar Traspaso'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Pantalla de traspaso en desarrollo',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}

