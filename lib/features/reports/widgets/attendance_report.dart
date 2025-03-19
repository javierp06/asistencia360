import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../../core/widgets/metrics_card.dart';

class AttendanceReport extends StatefulWidget {
  final DateTimeRange dateRange;
  final bool isAdmin;
  final int? selectedEmployeeId;
  
  const AttendanceReport({
    Key? key, 
    required this.dateRange, 
    required this.isAdmin,
    this.selectedEmployeeId,
  }) : super(key: key);

  @override
  State<AttendanceReport> createState() => _AttendanceReportState();
}

class _AttendanceReportState extends State<AttendanceReport> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _attendanceData = [];
  Map<String, dynamic> _metrics = {
    'totalDays': 0,
    'presentDays': 0,
    'absentDays': 0,
    'lateArrivals': 0,
    'earlyDepartures': 0,
    'averageHoursPerDay': 0.0,
    'totalHours': 0.0,
    'attendanceRate': 0.0,
  };
  
  @override
  void initState() {
    super.initState();
    _fetchAttendanceData();
  }
  
  @override
  void didUpdateWidget(AttendanceReport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dateRange != widget.dateRange || 
        oldWidget.selectedEmployeeId != widget.selectedEmployeeId) {
      _fetchAttendanceData();
    }
  }
  
  Future<void> _fetchAttendanceData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      
      // Determine the correct URL based on whether admin view or specific employee
      final Uri url;
      if (widget.isAdmin && widget.selectedEmployeeId != null) {
        url = Uri.parse('https://timecontrol-backend.onrender.com/asistencia/${widget.selectedEmployeeId}');
      } else if (widget.isAdmin) {
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
        
        // Filter data by date range
        final filteredData = data.where((record) {
          final recordDate = DateTime.parse(record['fecha']);
          return recordDate.isAfter(widget.dateRange.start.subtract(const Duration(days: 1))) && 
                 recordDate.isBefore(widget.dateRange.end.add(const Duration(days: 1)));
        }).toList();
        
        // Calculate metrics
        _calculateMetrics(filteredData);
        
        setState(() {
          _attendanceData = filteredData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Error al cargar datos: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }
  
  void _calculateMetrics(List<dynamic> data) {
    // Count total days in the date range (excluding weekends)
    final int totalDays = _calculateBusinessDays(widget.dateRange.start, widget.dateRange.end);
    
    // Count present days (days with attendance records)
    final Set<String> presentDays = data
        .map<String>((record) => record['fecha'] as String)
        .toSet();
    
    // Count late arrivals (after 9:00 AM)
    int lateArrivals = 0;
    int earlyDepartures = 0;
    double totalHours = 0;
    
    for (final record in data) {
      // Process late arrivals
      if (record['hora_entrada'] != null) {
        final entryTime = _parseTimeString(record['hora_entrada']);
        if (entryTime.hour >= 9 && entryTime.minute > 0) {
          lateArrivals++;
        }
      }
      
      // Process early departures (before 5:00 PM)
      if (record['hora_salida'] != null) {
        final exitTime = _parseTimeString(record['hora_salida']);
        if (exitTime.hour < 17) {
          earlyDepartures++;
        }
      }
      
      // Calculate hours worked
      if (record['hora_entrada'] != null && record['hora_salida'] != null) {
        final entryTime = _parseTimeString(record['hora_entrada']);
        final exitTime = _parseTimeString(record['hora_salida']);
        
        final duration = exitTime.difference(entryTime);
        final hoursWorked = duration.inMinutes / 60.0;
        totalHours += hoursWorked;
      }
    }
    
    // Calculate average hours per day
    final double averageHours = presentDays.isNotEmpty ? totalHours / presentDays.length : 0;
    
    // Calculate attendance rate
    final double attendanceRate = totalDays > 0 ? (presentDays.length / totalDays) * 100 : 0;
    
    _metrics = {
      'totalDays': totalDays,
      'presentDays': presentDays.length,
      'absentDays': totalDays - presentDays.length,
      'lateArrivals': lateArrivals,
      'earlyDepartures': earlyDepartures,
      'averageHoursPerDay': averageHours,
      'totalHours': totalHours,
      'attendanceRate': attendanceRate,
    };
  }
  
  DateTime _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    final now = DateTime.now();
    return DateTime(
      now.year, 
      now.month, 
      now.day, 
      int.parse(parts[0]), 
      int.parse(parts[1]), 
      parts.length > 2 ? int.parse(parts[2]) : 0
    );
  }
  
  int _calculateBusinessDays(DateTime start, DateTime end) {
    int days = 0;
    for (DateTime date = start; 
         date.isBefore(end) || date.isAtSameMomentAs(end); 
         date = date.add(const Duration(days: 1))) {
      if (date.weekday < 6) { // Monday to Friday are workdays
        days++;
      }
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchAttendanceData,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reporte de Asistencia',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            'Período: ${DateFormat('dd/MM/yyyy').format(widget.dateRange.start)} - ${DateFormat('dd/MM/yyyy').format(widget.dateRange.end)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          
          // Tarjetas de métricas de asistencia
          _buildMetricsGrid(),
          
          const SizedBox(height: 32),
          
          // Tabla detallada de asistencia
          _buildAttendanceTable(),
        ],
      ),
    );
  }
  
  Widget _buildMetricsGrid() {
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.7, // Add this line to fix the overflow
      children: [
        MetricsCard(
          title: 'Tasa de Asistencia',
          value: '${_metrics['attendanceRate'].toStringAsFixed(1)}%',
          icon: Icons.check_circle,
          color: Colors.green,
        ),
        MetricsCard(
          title: 'Días Presentes',
          value: '${_metrics['presentDays']}/${_metrics['totalDays']}',
          icon: Icons.calendar_today,
          color: Colors.blue,
        ),
        MetricsCard(
          title: 'Llegadas Tardías',
          value: '${_metrics['lateArrivals']}',
          icon: Icons.watch_later,
          color: Colors.orange,
        ),
        MetricsCard(
          title: 'Salidas Tempranas',
          value: '${_metrics['earlyDepartures']}',
          icon: Icons.exit_to_app,
          color: Colors.purple,
        ),
        MetricsCard(
          title: 'Total Horas',
          value: '${_metrics['totalHours'].toStringAsFixed(1)}h',
          icon: Icons.access_time,
          color: Colors.teal,
        ),
        MetricsCard(
          title: 'Promedio Diario',
          value: '${_metrics['averageHoursPerDay'].toStringAsFixed(1)}h',
          icon: Icons.trending_up,
          color: Colors.deepPurple,
        ),
        MetricsCard(
          title: 'Ausencias',
          value: '${_metrics['absentDays']}',
          icon: Icons.person_off,
          color: Colors.red,
        ),
      ],
    );
  }
  
  Widget _buildAttendanceTable() {
    final columns = ['Fecha', 'Entrada', 'Salida', 'Horas'];
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Detalles de Asistencia',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
              rows: _attendanceData.map((record) {
                final entryTime = record['hora_entrada'] ?? '--:--';
                final exitTime = record['hora_salida'] ?? '--:--';
                
                // Calculate hours if both entry and exit times exist
                String hours = '--';
                if (record['hora_entrada'] != null && record['hora_salida'] != null) {
                  final entry = _parseTimeString(record['hora_entrada']);
                  final exit = _parseTimeString(record['hora_salida']);
                  final duration = exit.difference(entry);
                  hours = (duration.inMinutes / 60.0).toStringAsFixed(1);
                }
                
                return DataRow(cells: [
                  DataCell(Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(record['fecha'])))),
                  DataCell(Text(entryTime)),
                  DataCell(Text(exitTime)),
                  DataCell(Text('$hours h')),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}