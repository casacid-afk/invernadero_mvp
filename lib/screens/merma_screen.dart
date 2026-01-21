import 'package:flutter/material.dart';
import '../domain/motor_invernadero.dart';

class MermaScreen extends StatelessWidget {
  final MotorInvernadero motor;

  const MermaScreen({super.key, required this.motor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Registrar Merma'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Pantalla de merma en desarrollo',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}

