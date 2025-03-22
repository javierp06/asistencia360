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
import '../../core/config/api_config.dart';

class EmployeeReportsScreen extends StatefulWidget {
  const EmployeeReportsScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeReportsScreen> createState() => _EmployeeReportsScreenState();
}

class _EmployeeReportsScreenState extends State<EmployeeReportsScreen> {
  DateTimeRange dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  bool _isLoading = true;
  List<dynamic> _attendanceData = [];
  String? _employeeId;
  String? _employeeName;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final storage = const FlutterSecureStorage();
      final employeeId = await storage.read(key: 'empleadoId');
      final userName = await storage.read(key: 'userName');
      
      setState(() {
        _employeeId = employeeId;
        _employeeName = userName;
      });
      
      _fetchAttendanceData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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
    if (_employeeId == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      
      // Usar solo la URL básica con el ID del empleado
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/asistencia/$_employeeId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // Filtrar datos por rango de fechas en el frontend
        final filteredData = data.where((record) {
          if (record['fecha'] == null) return false;
          
          final recordDate = DateTime.parse(record['fecha']);
          return recordDate.isAfter(dateRange.start.subtract(const Duration(days: 1))) && 
                 recordDate.isBefore(dateRange.end.add(const Duration(days: 1)));
        }).toList();
        
        setState(() {
          _attendanceData = filteredData;
          _isLoading = false;
        });
      } else {
        throw Exception('Error al cargar datos de asistencia');
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

  Future<void> _exportReport() async {
    final scaffold = ScaffoldMessenger.of(context);
    
    if (_employeeId == null) {
      scaffold.showSnackBar(
        const SnackBar(content: Text('No se pudo identificar el empleado')),
      );
      return;
    }
    
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
                          'Registro Personal de Asistencia',
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

                // Información del empleado y período
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Información Personal',
                        style: pw.TextStyle(font: ttfBold, fontSize: 14),
                      ),
                      pw.Divider(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Empleado:', style: pw.TextStyle(font: ttf)),
                          pw.Text(
                            _employeeName ?? 'Usuario',
                            style: pw.TextStyle(font: ttf),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 5),
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
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
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
                      _buildPdfMetricRow('Tasa de asistencia', '${attendanceRate.toStringAsFixed(1)}%', ttf),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // Tabla de registros
                pw.Text('Mis Registros de Asistencia',
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
        name: 'Mi_Asistencia_${dateFormat.format(dateRange.start)}_${dateFormat.format(dateRange.end)}',
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
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Reportes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportReport,
            tooltip: 'Descargar reporte',
          ),
        ],
      ),
      drawer: const CustomDrawer(isAdmin: false),
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
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                // Cabecera con información personal
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
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            child: const Icon(Icons.person),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Mi Historial de Asistencias',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _employeeName ?? 'Usuario',
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _fetchAttendanceData,
                            tooltip: 'Actualizar datos',
                          ),
                        ],
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
                          isAdmin: false,
                          selectedEmployeeId: _employeeId != null ? int.tryParse(_employeeId!) : null,
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