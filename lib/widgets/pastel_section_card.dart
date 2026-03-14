import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Contenedor reutilizable con fondo pastel, borde suave y sombra.
/// Usar para envolver formularios, secciones o bloques informativos.
/// Los inputs dentro mantienen fondo claro por tema; el pastel va en el contenedor.
class PastelSectionCard extends StatelessWidget {
  const PastelSectionCard({
    super.key,
    required this.pastel,
    required this.child,
    this.padding,
    this.title,
    this.icon,
  });

  final PastelVariant pastel;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final String? title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (title != null || icon != null) {
      return Container(
        decoration: _decoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: pastel.accent, size: 22),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title ?? '',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: 14,
                right: 14,
                bottom: 12,
                top: 2,
              ),
              child: child,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: _decoration(),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }

  BoxDecoration _decoration() {
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
}

/// Fondo pastel para toda el área de contenido (p. ej. body de Scaffold).
/// Útil para pantallas de listas donde no se usa Card.
BoxDecoration pastelBodyDecoration(PastelVariant pastel) {
  return BoxDecoration(
    color: pastel.background,
  );
}
