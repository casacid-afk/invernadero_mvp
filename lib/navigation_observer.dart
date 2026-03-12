import 'package:flutter/material.dart';

/// Observador de navegación global para detectar cuándo las pantallas
/// vuelven a quedar visibles (por ejemplo, después de hacer pop de otra ruta).
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

