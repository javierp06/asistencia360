import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_saver/file_saver.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'widgets/date_range_filter.dart';
import 'widgets/attendance_report.dart';
import '../../core/widgets/custom_drawer.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTimeRange dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  bool isAdmin = false;  // Default to false for safety
  bool _isLoading = true; // Set to true initially since we'll be loading role
  String? selectedEmployeeId;
  List<dynamic> _attendanceData = [];

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    try {
      final storage = const FlutterSecureStorage();
      // Check user role
      final role = await storage.read(key: 'role');
      
      setState(() {
        isAdmin = role == 'admin';
        _isLoading = false;
      });
      
      // Now fetch data after role is determined
      _fetchAttendanceData();
    } catch (e) {
      setState(() {
        isAdmin = false; // Default to non-admin on error
        _isLoading = false;
      });
    }
  }

  // Función para actualizar el rango de fechas
  void _updateDateRange(DateTimeRange range) {
    setState(() {
      dateRange = range;
      _isLoading = true;
    });

    _fetchAttendanceData();
  }

  Future<void> _fetchAttendanceData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      
      // Determinar la URL correcta según sea vista de admin o empleado específico
      final Uri url;
      
      if (isAdmin && selectedEmployeeId != null) {
        url = Uri.parse('https://timecontrol-backend.onrender.com/asistencia/$selectedEmployeeId');
      } else if (isAdmin) {
        url = Uri.parse('https://timecontrol-backend.onrender.com/asistencia');
      } else {
        final employeeId = await storage.read(key: 'empleadoId');
        url = Uri.parse('https://timecontrol-backend.onrender.com/asistencia/$employeeId');
      }
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // Filtrar datos por rango de fechas
        final filteredData = data.where((record) {
          final recordDate = DateTime.parse(record['fecha']);
          return recordDate.isAfter(dateRange.start.subtract(const Duration(days: 1))) && 
                 recordDate.isBefore(dateRange.end.add(const Duration(days: 1)));
        }).toList();
        
        setState(() {
          _attendanceData = filteredData;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load attendance data');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    }
  }

  // Función para exportar el reporte como PDF
  Future<void> _exportReport() async {
    final scaffold = ScaffoldMessenger.of(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Crear documento PDF
      final pdf = pw.Document();

      // Usar fuentes integradas
      final ttf = pw.Font.helvetica();
      final ttfBold = pw.Font.helveticaBold();

      // Formateador para fechas
      final dateFormat = DateFormat('dd/MM/yyyy');

      // Calcular métricas de asistencia
      int totalDays = 0;
      int presentDays = 0;
      int absentDays = 0;
      int lateArrivals = 0;
      double totalHours = 0;
      
      if (_attendanceData.isNotEmpty) {
        for (var record in _attendanceData) {
          totalDays++;
          
          final entryTime = record['hora_entrada'];
          final exitTime = record['hora_salida'];
          
          if (entryTime != null && exitTime != null) {
            presentDays++;
            
            // Calcular horas trabajadas
            final entry = _parseTimeString(entryTime);
            final exit = _parseTimeString(exitTime);
            
            if (entry != null && exit != null) {
              final hoursWorked = exit.difference(entry).inMinutes / 60.0;
              totalHours += hoursWorked;
              
              // Verificar si llegó tarde (después de las 8:00 AM)
              final scheduledEntry = DateTime(
                entry.year, entry.month, entry.day, 8, 0
              );
              
              if (entry.isAfter(scheduledEntry)) {
                lateArrivals++;
              }
            }
          } else {
            absentDays++;
          }
        }
      }
      
      double attendanceRate = totalDays > 0 ? (presentDays / totalDays) * 100 : 0;
      double averageHoursPerDay = presentDays > 0 ? totalHours / presentDays : 0;

      // Añadir página al PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Encabezado con logo e información de la empresa
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'TOURIST OPTION',
                          style: pw.TextStyle(font: ttfBold, fontSize: 18),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'Reporte de Asistencia',
                          style: pw.TextStyle(font: ttf, fontSize: 14),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(border: pw.Border.all()),
                      child: pw.Text(
                        'INFORME',
                        style: pw.TextStyle(font: ttfBold),
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 20),

                // Información del período
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(5),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Información del Reporte',
                        style: pw.TextStyle(font: ttfBold, fontSize: 14),
                      ),
                      pw.Divider(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Período:', style: pw.TextStyle(font: ttf)),
                          pw.Text(
                            '${dateFormat.format(dateRange.start)} - ${dateFormat.format(dateRange.end)}',
                            style: pw.TextStyle(font: ttf),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 5),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Fecha de generación:', style: pw.TextStyle(font: ttf)),
                          pw.Text(
                            dateFormat.format(DateTime.now()),
                            style: pw.TextStyle(font: ttf),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // Resumen de asistencia
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(5),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Resumen de Asistencia',
                        style: pw.TextStyle(font: ttfBold, fontSize: 14),
                      ),
                      pw.Divider(),
                      _buildPdfMetricRow('Días totales', totalDays.toString(), ttf),
                      _buildPdfMetricRow('Días presentes', presentDays.toString(), ttf),
                      _buildPdfMetricRow('Días ausentes', absentDays.toString(), ttf),
                      _buildPdfMetricRow('Llegadas tardías', lateArrivals.toString(), ttf),
                      _buildPdfMetricRow('Total de horas', totalHours.toStringAsFixed(2), ttf),
                      _buildPdfMetricRow('Promedio de horas/día', averageHoursPerDay.toStringAsFixed(2), ttf),
                      _buildPdfMetricRow(
                          'Tasa de asistencia', '${attendanceRate.toStringAsFixed(1)}%', ttf),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // Tabla de registros
                pw.Text('Registros de Asistencia',
                    style: pw.TextStyle(font: ttfBold, fontSize: 14)),
                pw.SizedBox(height: 10),
                
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.5),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(1),
                    3: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    // Encabezado de la tabla
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('Fecha', style: pw.TextStyle(font: ttfBold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('Entrada', style: pw.TextStyle(font: ttfBold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('Salida', style: pw.TextStyle(font: ttfBold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('Horas', style: pw.TextStyle(font: ttfBold)),
                        ),
                      ],
                    ),
                    
                    // Filas de datos
                    ..._attendanceData.map((record) {
                      final date = DateTime.parse(record['fecha']);
                      final entryTime = record['hora_entrada'] ?? '--:--';
                      final exitTime = record['hora_salida'] ?? '--:--';
                      
                      double hoursWorked = 0;
                      if (record['hora_entrada'] != null && record['hora_salida'] != null) {
                        final entry = _parseTimeString(record['hora_entrada']);
                        final exit = _parseTimeString(record['hora_salida']);
                        
                        if (entry != null && exit != null) {
                          hoursWorked = exit.difference(entry).inMinutes / 60.0;
                        }
                      }
                      
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(dateFormat.format(date), style: pw.TextStyle(font: ttf)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(entryTime, style: pw.TextStyle(font: ttf)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(exitTime, style: pw.TextStyle(font: ttf)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              hoursWorked > 0 ? hoursWorked.toStringAsFixed(2) : '--',
                              style: pw.TextStyle(font: ttf),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),

                pw.Spacer(),

                // Pie de página
                pw.Center(
                  child: pw.Text(
                    'Documento generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(font: ttf, fontSize: 10),
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Generar el PDF como bytes
      final bytes = await pdf.save();

      // Cerrar diálogo de carga
      Navigator.of(context).pop();

      // Usar FileSaver para descargar el PDF
      await FileSaver.instance.saveFile(
        name: 'Reporte_Asistencia_${dateFormat.format(dateRange.start)}_${dateFormat.format(dateRange.end)}',
        bytes: bytes,
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );

      scaffold.showSnackBar(
        const SnackBar(content: Text('PDF descargado con éxito')),
      );
    } catch (e) {
      // Cerrar el diálogo de carga
      Navigator.pop(context);

      scaffold.showSnackBar(
        SnackBar(content: Text('Error al generar el PDF: $e')),
      );
    }
  }

  // Función auxiliar para construir filas en el PDF
  pw.Widget _buildPdfMetricRow(String label, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font)),
          pw.Text(value, style: pw.TextStyle(font: font)),
        ],
      ),
    );
  }

  // Función auxiliar para convertir strings de hora a DateTime
  DateTime? _parseTimeString(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day, hour, minute);
      }
    } catch (e) {
      // Ignorar errores de formato
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportReport,
            tooltip: 'Exportar reporte',
          ),
        ],
      ),
      drawer: CustomDrawer(isAdmin: isAdmin),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode 
                ? [Colors.grey.shade900, Colors.grey.shade800] 
                : [Colors.blue.shade50, Colors.blue.shade100],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                // Filtro de fechas con estilo mejorado
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Reporte de asistencias',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _fetchAttendanceData,
                            tooltip: 'Actualizar datos',
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '(${DateFormat('dd/MM/yyyy').format(dateRange.start)} - ${DateFormat('dd/MM/yyyy').format(dateRange.end)})',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DateRangeFilter(
                        dateRange: dateRange,
                        onDateRangeChanged: _updateDateRange,
                      ),
                    ],
                  ),
                ),

                // Contenido del reporte
                Expanded(
                  child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: AttendanceReport(
                          dateRange: dateRange,
                          isAdmin: isAdmin,
                          selectedEmployeeId: selectedEmployeeId != null ? int.tryParse(selectedEmployeeId!) : null,
                           // Desactivar las gráficas
                        ),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
