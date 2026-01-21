import 'package:flutter/material.dart';

/// Widget reutilizable para mostrar badge de cobertura
/// Muestra badge rojo "Sembrar hoy" si cobertura == 🔴
/// Muestra badge amarillo "Atención" si cobertura == 🟡
/// No muestra nada si cobertura == 🟢
class CoberturaBadge extends StatelessWidget {
  final String cobertura;
  final VoidCallback? onTap;

  const CoberturaBadge({super.key, required this.cobertura, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (cobertura == '🔴') {
      return _buildBadge(context, 'Sembrar hoy', Colors.red, onTap: onTap);
    } else if (cobertura == '🟡') {
      return _buildBadge(context, 'Atención', Colors.orange);
    }
    // 🟢 o cualquier otro estado: no mostrar badge
    return const SizedBox.shrink();
  }

  Widget _buildBadge(
    BuildContext context,
    String texto,
    MaterialColor color, {
    VoidCallback? onTap,
  }) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: color.shade50,
        border: Border.all(color: color.shade300, width: 1.5),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: color.shade900,
          fontSize: 11,
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: badge,
      );
    }

    return badge;
  }
}
