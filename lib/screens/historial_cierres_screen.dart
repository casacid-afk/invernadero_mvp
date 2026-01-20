import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../domain/motor_invernadero.dart';
import '../domain/cierre_jornada.dart';

class HistorialCierresScreen extends StatelessWidget {
  final MotorInvernadero motor;

  const HistorialCierresScreen({
    super.key,
    required this.motor,
  });

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  String _formatearFechaCSV(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  String _generarCSV(List<CierreJornada> cierres) {
    final buffer = StringBuffer();
    
    // Encabezados
    buffer.writeln('Fecha,Ventas,Unidades,Total $');
    
    // Datos
    for (final cierre in cierres) {
      buffer.writeln(
        '${_formatearFechaCSV(cierre.fecha)},'
        '${cierre.cantidadVentas},'
        '${cierre.unidadesVendidas},'
        '${cierre.totalDolares.toStringAsFixed(2)}',
      );
    }
    
    return buffer.toString();
  }

  String _generarNombreArchivo(List<CierreJornada> cierres) {
    if (cierres.isEmpty) {
      final ahora = DateTime.now();
      return 'cierres_${ahora.year}${ahora.month.toString().padLeft(2, '0')}.csv';
    }
    
    // Usar el mes del primer cierre (más reciente)
    final fechaPrimerCierre = cierres.first.fecha;
    return 'cierres_${fechaPrimerCierre.year}${fechaPrimerCierre.month.toString().padLeft(2, '0')}.csv';
  }

  Future<void> _exportarCSV(BuildContext context) async {
    final cierres = List<CierreJornada>.from(motor.cierresJornada)
      ..sort((a, b) => b.fecha.compareTo(a.fecha));

    if (cierres.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay cierres para exportar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final csvContent = _generarCSV(cierres);
      final nombreArchivo = _generarNombreArchivo(cierres);

      // Obtener directorio temporal
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$nombreArchivo');
      
      // Escribir CSV
      await file.writeAsString(csvContent);

      // Compartir o descargar según plataforma
      if (Platform.isAndroid || Platform.isIOS) {
        // Móvil: compartir
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Exportación de cierres de jornada',
        );
      } else {
        // Web/Desktop: descargar (usar share también funciona)
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Exportación de cierres de jornada',
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV exportado: $nombreArchivo'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar CSV: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _generarNombreArchivoPDF(List<CierreJornada> cierres) {
    if (cierres.isEmpty) {
      final ahora = DateTime.now();
      return 'cierres_${ahora.year}${ahora.month.toString().padLeft(2, '0')}.pdf';
    }
    
    // Usar el mes del primer cierre (más reciente)
    final fechaPrimerCierre = cierres.first.fecha;
    return 'cierres_${fechaPrimerCierre.year}${fechaPrimerCierre.month.toString().padLeft(2, '0')}.pdf';
  }

  String _obtenerNombreMes(int mes) {
    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return meses[mes - 1];
  }

  DateTime _obtenerMesAnterior(DateTime fecha) {
    if (fecha.month == 1) {
      return DateTime(fecha.year - 1, 12, 1);
    } else {
      return DateTime(fecha.year, fecha.month - 1, 1);
    }
  }

  List<CierreJornada> _filtrarCierresPorMes(List<CierreJornada> cierres, int año, int mes) {
    return cierres.where((cierre) {
      return cierre.fecha.year == año && cierre.fecha.month == mes;
    }).toList();
  }

  List<CierreJornada> _filtrarCierresHastaFecha(List<CierreJornada> cierres, DateTime fechaLimite) {
    final fechaFin = DateTime(fechaLimite.year, fechaLimite.month + 1, 1);
    return cierres.where((cierre) {
      return cierre.fecha.isBefore(fechaFin);
    }).toList();
  }

  List<CierreJornada> _obtenerCierresAcumuladoTemporada(List<CierreJornada> todosCierres, DateTime fechaFin) {
    // Ordenar por fecha ascendente para obtener el primero
    final cierresOrdenados = List<CierreJornada>.from(todosCierres)
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
    
    if (cierresOrdenados.isEmpty) return [];
    
    final fechaInicio = cierresOrdenados.first.fecha;
    final fechaFinMes = DateTime(fechaFin.year, fechaFin.month + 1, 1);
    
    return todosCierres.where((cierre) {
      return cierre.fecha.isAfter(fechaInicio.subtract(const Duration(days: 1))) &&
             cierre.fecha.isBefore(fechaFinMes);
    }).toList();
  }

  Map<String, dynamic> _calcularTotales(List<CierreJornada> cierres) {
    return {
      'ventas': cierres.fold<int>(0, (suma, c) => suma + c.cantidadVentas),
      'unidades': cierres.fold<int>(0, (suma, c) => suma + c.unidadesVendidas),
      'dolares': cierres.fold<double>(0.0, (suma, c) => suma + c.totalDolares),
    };
  }

  Future<void> _exportarPDF(BuildContext context) async {
    final todosCierres = List<CierreJornada>.from(motor.cierresJornada)
      ..sort((a, b) => b.fecha.compareTo(a.fecha));

    if (todosCierres.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay cierres para exportar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Determinar mes actual (del primer cierre más reciente)
      final fechaMesActual = todosCierres.first.fecha;
      final añoActual = fechaMesActual.year;
      final mesActual = fechaMesActual.month;
      
      // Filtrar cierres del mes actual
      final cierresMesActual = _filtrarCierresPorMes(todosCierres, añoActual, mesActual);
      
      // Calcular totales del mes actual
      final totalesActual = _calcularTotales(cierresMesActual);
      
      // Obtener mes anterior
      final fechaMesAnterior = _obtenerMesAnterior(fechaMesActual);
      final cierresMesAnterior = _filtrarCierresPorMes(
        todosCierres,
        fechaMesAnterior.year,
        fechaMesAnterior.month,
      );
      final totalesAnterior = _calcularTotales(cierresMesAnterior);
      final hayDatosAnterior = cierresMesAnterior.isNotEmpty;
      
      // Calcular acumulado temporada (desde el primer cierre hasta fin del mes actual)
      final fechaFinTemporada = DateTime(añoActual, mesActual + 1, 1);
      final cierresAcumulado = _obtenerCierresAcumuladoTemporada(todosCierres, fechaFinTemporada);
      final totalesAcumulado = _calcularTotales(cierresAcumulado);
      
      // Fecha/hora de exportación
      final ahora = DateTime.now();
      final fechaExportacion = '${ahora.day}/${ahora.month}/${ahora.year} ${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}';

      // Crear PDF
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Encabezado
                pw.Text(
                  'Reporte Mensual – ${_obtenerNombreMes(mesActual)} $añoActual',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                
                // Sección: Resumen (tabla diaria del mes)
                pw.Text(
                  'Resumen',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    // Encabezados
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Fecha',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Ventas',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Unidades',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Total \$',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    // Filas de datos
                    ...cierresMesActual.map((cierre) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(_formatearFecha(cierre.fecha)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              cierre.cantidadVentas.toString(),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              cierre.unidadesVendidas.toString(),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '\$${cierre.totalDolares.toStringAsFixed(2)}',
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      );
                    }),
                    // Fila de totales
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'TOTALES',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            totalesActual['ventas'].toString(),
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            totalesActual['unidades'].toString(),
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '\$${totalesActual['dolares'].toStringAsFixed(2)}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                
                // Sección: Comparativo
                pw.Text(
                  'Comparativo: Mes Actual vs Mes Anterior',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    // Encabezados
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Métrica',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Actual',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Anterior',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Diferencia',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '%',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    // Ventas
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Ventas'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            totalesActual['ventas'].toString(),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            hayDatosAnterior ? totalesAnterior['ventas'].toString() : 'Sin datos',
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            hayDatosAnterior 
                                ? (totalesActual['ventas'] as int - totalesAnterior['ventas'] as int).toString()
                                : '-',
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            hayDatosAnterior && totalesAnterior['ventas'] > 0
                                ? '${(((totalesActual['ventas'] as int - totalesAnterior['ventas'] as int) / totalesAnterior['ventas'] as int) * 100).toStringAsFixed(1)}%'
                                : '-',
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    // Unidades
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Unidades'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            totalesActual['unidades'].toString(),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            hayDatosAnterior ? totalesAnterior['unidades'].toString() : 'Sin datos',
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            hayDatosAnterior 
                                ? (totalesActual['unidades'] as int - totalesAnterior['unidades'] as int).toString()
                                : '-',
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            hayDatosAnterior && totalesAnterior['unidades'] > 0
                                ? '${(((totalesActual['unidades'] as int - totalesAnterior['unidades'] as int) / totalesAnterior['unidades'] as int) * 100).toStringAsFixed(1)}%'
                                : '-',
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    // Total $
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Total \$',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '\$${totalesActual['dolares'].toStringAsFixed(2)}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            hayDatosAnterior 
                                ? '\$${totalesAnterior['dolares'].toStringAsFixed(2)}'
                                : 'Sin datos',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            hayDatosAnterior 
                                ? '\$${(totalesActual['dolares'] as double - totalesAnterior['dolares'] as double).toStringAsFixed(2)}'
                                : '-',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            hayDatosAnterior && totalesAnterior['dolares'] > 0
                                ? '${(((totalesActual['dolares'] as double - totalesAnterior['dolares'] as double) / totalesAnterior['dolares'] as double) * 100).toStringAsFixed(1)}%'
                                : '-',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                
                // Sección: Acumulado Temporada
                pw.Text(
                  'Acumulado Temporada',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    // Encabezados
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Métrica',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Total',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    // Ventas
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Ventas'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            totalesAcumulado['ventas'].toString(),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    // Unidades
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Unidades'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            totalesAcumulado['unidades'].toString(),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    // Total $
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Total \$',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '\$${totalesAcumulado['dolares'].toStringAsFixed(2)}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Spacer(),
                
                // Pie: fecha/hora exportación
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Exportado el $fechaExportacion',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Compartir/Imprimir PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF generado: ${_generarNombreArchivoPDF(cierresMesActual)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _mostrarDetalle(BuildContext context, CierreJornada cierre) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cierre del ${_formatearFecha(cierre.fecha)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetalleItem('Fecha', _formatearFecha(cierre.fecha)),
            const SizedBox(height: 12),
            _buildDetalleItem('Ventas', cierre.cantidadVentas.toString()),
            const SizedBox(height: 12),
            _buildDetalleItem('Unidades Vendidas', cierre.unidadesVendidas.toString()),
            const SizedBox(height: 12),
            _buildDetalleItem(
              'Total \$',
              '\$${cierre.totalDolares.toStringAsFixed(2)}',
              isHighlight: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleItem(String label, String valor, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          valor,
          style: TextStyle(
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            fontSize: isHighlight ? 18 : 16,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cierres = List<CierreJornada>.from(motor.cierresJornada)
      ..sort((a, b) => b.fecha.compareTo(a.fecha));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Historial de Cierres'),
        actions: [
          if (cierres.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Exportar PDF',
              onPressed: () => _exportarPDF(context),
            ),
            IconButton(
              icon: const Icon(Icons.file_download),
              tooltip: 'Exportar CSV',
              onPressed: () => _exportarCSV(context),
            ),
          ],
        ],
      ),
      body: cierres.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay cierres registrados',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: cierres.length,
              itemBuilder: (context, index) {
                final cierre = cierres[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.lock,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      _formatearFecha(cierre.fecha),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    subtitle: Text(
                      '${cierre.cantidadVentas} ventas • ${cierre.unidadesVendidas} unidades',
                    ),
                    trailing: Text(
                      '\$${cierre.totalDolares.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    onTap: () => _mostrarDetalle(context, cierre),
                  ),
                );
              },
            ),
    );
  }
}

