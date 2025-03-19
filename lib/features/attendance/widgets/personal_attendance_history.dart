import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart'; // Añadir esta importación
import 'package:flutter/cupertino.dart';

class PersonalAttendanceHistory extends StatefulWidget {
  final bool showSummary;
  final String? employeeName;
  final String? employeeId;
  
  const PersonalAttendanceHistory({
    Key? key, 
    this.showSummary = true, 
    this.employeeName,
    this.employeeId
  }) : super(key: key);

  @override
  State<PersonalAttendanceHistory> createState() => _PersonalAttendanceHistoryState();
}

class _PersonalAttendanceHistoryState extends State<PersonalAttendanceHistory> {
  bool _isLoading = true;
  List<Map<String, dynamic>> attendanceRecords = [];
  String? errorMessage;
  Map<String, dynamic> attendanceSummary = {
    'totalDays': 0,
    'presentDays': 0,
    'absentDays': 0,
    'totalHours': 0.0,
    'lateArrivals': 0,
  };

  @override
  void initState() {
    super.initState();
    // Inicializar datos de localización para español e inglés
    initializeDateFormatting('es', null).then((_) => _fetchAttendanceData());
  }

  @override
  void didUpdateWidget(PersonalAttendanceHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employeeId != widget.employeeId) {
      _fetchAttendanceData();
    }
  }

  Future<void> _fetchAttendanceData() async {
    setState(() {
      _isLoading = true;
      errorMessage = null;
    });

    try {
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      
      // Agregar depuración para verificar ID del empleado
      
      // Construir la URL correcta con el ID numérico del empleado
      final url = widget.employeeId != null 
          ? Uri.parse('https://timecontrol-backend.onrender.com/asistencia?id_empleado=${widget.employeeId}')
          : Uri.parse('https://timecontrol-backend.onrender.com/asistencia');
      
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        
        // Verificar si hay registros para este empleado específico
        if (responseData.isEmpty) {
          setState(() {
            attendanceRecords = [];
            attendanceSummary = {
              'totalDays': 0,
              'presentDays': 0,
              'absentDays': 0,
              'totalHours': 0.0,
              'lateArrivals': 0,
            };
            _isLoading = false;
          });
          return;
        }
        
        // Filtrar aquí para asegurar que son registros del empleado correcto
        final filteredRecords = widget.employeeId != null
            ? responseData.where((record) => 
                record['id_empleado'].toString() == widget.employeeId.toString()).toList()
            : responseData;
        
        
        if (filteredRecords.isEmpty) {
          setState(() {
            attendanceRecords = [];
            attendanceSummary = {
              'totalDays': 0,
              'presentDays': 0,
              'absentDays': 0,
              'totalHours': 0.0,
              'lateArrivals': 0,
            };
            _isLoading = false;
          });
          return;
        }
        
        // Continuar procesando solo los registros del empleado correcto
        final records = filteredRecords.map((record) {
          // Calcular horas trabajadas
          final entryTime = record['hora_entrada'] ?? '--:--';
          final exitTime = record['hora_salida'] ?? '--:--';
          
          double hoursWorked = 0;
          final status = entryTime != '--:--' && exitTime != '--:--' ? 'Presente' : 'Ausente';
          
          // Calcular horas trabajadas si hay entrada y salida
          if (status == 'Presente' && entryTime != exitTime) {
            // Parsear tiempos para cálculo de horas
            final entry = entryTime.split(':');
            final exit = exitTime.split(':');
            
            if (entry.length >= 2 && exit.length >= 2) {
              final entryHour = int.tryParse(entry[0]) ?? 0;
              final entryMinute = int.tryParse(entry[1]) ?? 0;
              final exitHour = int.tryParse(exit[0]) ?? 0;
              final exitMinute = int.tryParse(exit[1]) ?? 0;
              
              // Calcular diferencia en horas
              hoursWorked = (exitHour - entryHour) + (exitMinute - entryMinute) / 60;
              if (hoursWorked < 0) hoursWorked += 24; // Si cruza medianoche
            }
          }
          
          return {
            'id': record['id_asistencia'],
            'date': DateTime.parse(record['fecha']),
            'checkIn': entryTime, // Mantener el formato original para cálculos
            'checkInFormatted': _formatTimeToAMPM(entryTime), // Añadir versión formateada
            'checkOut': exitTime, // Mantener el formato original para cálculos
            'checkOutFormatted': _formatTimeToAMPM(exitTime), // Añadir versión formateada
            'status': status,
            'hoursWorked': hoursWorked,
            'employeeName': record['empleado'] != null 
                ? '${record['empleado']['nombre']} ${record['empleado']['apellido']}' 
                : '',
          };
        }).toList();
        
        // Ordenar por fecha (más reciente primero)
        records.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
        
        // Calcular estadísticas
        _calculateStatistics(records);
        
        setState(() {
          attendanceRecords = records;
          _isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Error al cargar datos: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        errorMessage = 'Error de conexión: $error';
        _isLoading = false;
      });
    }
  }

  void _calculateStatistics(List<Map<String, dynamic>> records) {
    final totalDays = records.length;
    final presentDays = records.where((r) => r['status'] == 'Presente').length;
    final absentDays = totalDays - presentDays;
    final totalHours = records.fold(0.0, (sum, record) => sum + (record['hoursWorked'] as double));
    
    // Contar llegadas tarde (ejemplo: después de 8:00)
    final lateArrivals = records.where((r) {
      if (r['checkIn'] == '--:--') return false;
      
      final entry = r['checkIn'].split(':');
      if (entry.length < 2) return false;
      
      final entryHour = int.tryParse(entry[0]) ?? 0;
      final entryMinute = int.tryParse(entry[1]) ?? 0;
      
      // Considerar tarde si llega después de 8:00
      return entryHour > 8 || (entryHour == 8 && entryMinute > 0);
    }).length;
    
    attendanceSummary = {
      'totalDays': totalDays,
      'presentDays': presentDays,
      'absentDays': absentDays,
      'totalHours': totalHours,
      'lateArrivals': lateArrivals,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchAttendanceData,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (attendanceRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.employeeName != null 
                  ? 'No hay registros de asistencia para ${widget.employeeName}'
                  : 'No hay registros de asistencia disponibles',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchAttendanceData,
              child: const Text('Actualizar'),
            ),
          ],
        ),
      );
    }

    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded( // Añadir Expanded para controlar texto largo
                  child: Text(
                    widget.employeeName != null 
                        ? 'Historial de ${widget.employeeName}' 
                        : 'Mi Historial de Asistencia',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis, // Cortar texto con ...
                    maxLines: 2, // Permitir hasta 2 líneas
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _fetchAttendanceData,
                  tooltip: 'Actualizar datos',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.showSummary) _buildSummary(),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: attendanceRecords.length,
                itemBuilder: (context, index) {
                  final record = attendanceRecords[index];
                  return _buildAttendanceCard(context, record);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen del mes',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSummaryItem('Días presentes', '${attendanceSummary['presentDays']}', Colors.green),
                  const SizedBox(width: 12),
                  _buildSummaryItem('Ausencias', '${attendanceSummary['absentDays']}', Colors.red),
                  const SizedBox(width: 12),
                  _buildSummaryItem('Horas trabajadas', '${attendanceSummary['totalHours'].toStringAsFixed(1)}', Colors.blue),
                  const SizedBox(width: 12),
                  _buildSummaryItem('Llegadas tarde', '${attendanceSummary['lateArrivals']}', Colors.orange),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummaryItem(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
  
  Widget _buildAttendanceCard(BuildContext context, Map<String, dynamic> record) {
    final date = record['date'] as DateTime;
    final isPresent = record['status'] == 'Presente';
    
    // Usar formato de fecha con localización
    final dateFormat = DateFormat('EEEE, d MMM, yyyy', 'es');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPresent ? Colors.green : Colors.red,
          child: Icon(
            isPresent ? Icons.check : Icons.close,
            color: Colors.white,
          ),
        ),
        title: Text(
          dateFormat.format(date),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          isPresent 
              ? 'Entrada: ${record['checkInFormatted']} - Salida: ${record['checkOutFormatted']} (${record['hoursWorked'].toStringAsFixed(1)} hrs)' 
              : 'No se registró asistencia',
        ),
        trailing: widget.employeeId != null ? IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () {
            _showEditAttendanceDialog(context, record);
          },
        ) : null,
      ),
    );
  }

  void _showEditAttendanceDialog(BuildContext context, Map<String, dynamic> record) {
    // Analizar las horas y minutos de entrada y salida
    final entryTime = _parseTime(record['checkInFormatted']);
    final exitTime = _parseTime(record['checkOutFormatted']);
    
    // Variables para almacenar los valores seleccionados
    TimeOfDay selectedEntryTime = entryTime;
    TimeOfDay selectedExitTime = exitTime;
    
    final date = record['date'] as DateTime;
    final dateFormat = DateFormat('EEEE, d MMM, yyyy', 'es');
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).dialogTheme.backgroundColor ?? 
                    Theme.of(context).colorScheme.surface,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black54
                      : Colors.black26,
                  blurRadius: 10.0,
                  offset: const Offset(0.0, 10.0),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header y Fecha (mantén el código existente)...
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withAlpha(50),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.edit_calendar,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Editar Asistencia',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Fecha
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, 
                             color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            dateFormat.format(date),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Título de sección
                  _buildSectionAdaptive(context, 'Horario de Registro', Icons.access_time),
                  const SizedBox(height: 16),
                  
                  // Hora de entrada - Wheel Picker
                  Text('Hora de entrada',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTimePicker(
                    context, 
                    selectedEntryTime,
                    (TimeOfDay time) { selectedEntryTime = time; },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Hora de salida - Wheel Picker
                  Text('Hora de salida',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTimePicker(
                    context, 
                    selectedExitTime,
                    (TimeOfDay time) { selectedExitTime = time; },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Botones
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('CANCELAR', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          // Convertir los tiempos seleccionados a formato 24 horas
                          final entryTime24 = _formatTimeOfDayTo24(selectedEntryTime);
                          final exitTime24 = _formatTimeOfDayTo24(selectedExitTime);
                          
                          _updateAttendance(
                            record['id'].toString(),
                            entryTime24,
                            exitTime24
                          );
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.save, size: 16, color: Theme.of(context).colorScheme.onPrimary),
                            const SizedBox(width: 4),
                            Text('GUARDAR', 
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onPrimary
                                )
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateAttendance(String attendanceId, String entry, String exit) async {
    
    try {
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      
      final url = Uri.parse('https://timecontrol-backend.onrender.com/asistencia/$attendanceId');
      
      // Registrar la solicitud para depuración
      
     
      
      // Aumentar el timeout para dar más tiempo al servidor
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'hora_entrada': entry,
          'hora_salida': exit,
        }),
      ).timeout(const Duration(seconds: 30)); // Aumentar el timeout

     
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro actualizado correctamente')),
        );
        _fetchAttendanceData();
      } else {
        // Mostrar un mensaje más detallado
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: ${response.statusCode} - ${response.body}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (error) {
      
      // Mostrar diálogo con opciones para el usuario
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error de Conexión'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ocurrió un error al actualizar la asistencia.'),
              const SizedBox(height: 8),
              Text('Detalles: $error', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 16),
              const Text('Posibles soluciones:'),
              const SizedBox(height: 8),
              const Text('• Verificar tu conexión a internet'),
              const Text('• El servidor podría estar ocupado, intenta más tarde'),
              const Text('• Contacta al administrador del sistema'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateAttendance(attendanceId, entry, exit); // Reintentar
              },
              child: const Text('REINTENTAR'),
            ),
          ],
        ),
      );
    }
  }
}

// Añadir función helper para convertir formato de hora
String _formatTimeToAMPM(String time24) {
  if (time24 == '--:--' || time24.isEmpty) {
    return '--:--';
  }
  
  // Separar horas y minutos
  final parts = time24.split(':');
  if (parts.length < 2) return time24;
  
  int hour = int.tryParse(parts[0]) ?? 0;
  final minutes = parts[1];
  
  // Determinar AM/PM
  final period = hour >= 12 ? 'PM' : 'AM';
  
  // Convertir a formato 12 horas
  hour = hour > 12 ? hour - 12 : hour;
  hour = hour == 0 ? 12 : hour; // Convertir 0 horas a 12 AM
  
  return '$hour:$minutes $period';
}

// Función para convertir de formato AM/PM a formato 24 horas
String _convertToTime24(String timeAMPM) {
  if (timeAMPM == '--:--' || timeAMPM.isEmpty) {
    return '--:--';
  }
  
  // Limpiar espacios extra
  timeAMPM = timeAMPM.trim();
  
  // Verificar si ya está en formato 24 horas (sin AM/PM)
  if (!timeAMPM.toLowerCase().contains('am') && !timeAMPM.toLowerCase().contains('pm')) {
    return timeAMPM;
  }
  
  // Extraer AM/PM
  bool isPM = timeAMPM.toLowerCase().contains('pm');
  
  // Remover AM/PM
  timeAMPM = timeAMPM.toLowerCase().replaceAll('am', '').replaceAll('pm', '').trim();
  
  // Separar hora y minutos
  final parts = timeAMPM.split(':');
  if (parts.length < 2) return timeAMPM;
  
  int hour = int.tryParse(parts[0].trim()) ?? 0;
  final minutes = parts[1].trim();
  
  // Ajustar hora según AM/PM
  if (isPM && hour < 12) {
    hour += 12;
  } else if (!isPM && hour == 12) {
    hour = 0;
  }
  
  // Formato con ceros a la izquierda
  final hourFormatted = hour.toString().padLeft(2, '0');
  
  return '$hourFormatted:$minutes';
}

class _SummaryItem extends StatelessWidget {
  final String title;
  final String value;

  const _SummaryItem({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// Agregar esta nueva versión del método para los títulos de sección que se adapta al tema
Widget _buildSectionAdaptive(BuildContext context, String title, IconData icon) {
  return Row(
    children: [
      Icon(
        icon, 
        size: 18, 
        color: Theme.of(context).colorScheme.primary
      ),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ],
  );
}

// Función para construir un selector de tiempo tipo rueda
Widget _buildTimePicker(BuildContext context, TimeOfDay initialTime, Function(TimeOfDay) onTimeChanged) {
  return Container(
    height: 150,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey.shade700
            : Colors.grey.shade300,
      ),
    ),
    child: CupertinoTheme(
      data: CupertinoThemeData(
        brightness: Theme.of(context).brightness,
        textTheme: CupertinoTextThemeData(
          dateTimePickerTextStyle: TextStyle(
            fontSize: 20,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.time,
        initialDateTime: DateTime(
          2023, 1, 1, initialTime.hour, initialTime.minute
        ),
        use24hFormat: false,
        onDateTimeChanged: (DateTime newTime) {
          onTimeChanged(TimeOfDay(hour: newTime.hour, minute: newTime.minute));
        },
      ),
    ),
  );
}

// Función auxiliar para analizar el texto de tiempo en formato AM/PM
TimeOfDay _parseTime(String timeText) {
  if (timeText == '--:--') {
    return TimeOfDay(hour: 8, minute: 0);  // Valor predeterminado
  }
  
  try {
    // Eliminar espacios y extraer AM/PM
    timeText = timeText.trim();
    bool isPM = timeText.toLowerCase().contains('pm');
    
    // Quitar AM/PM
    timeText = timeText.toLowerCase().replaceAll('am', '').replaceAll('pm', '').trim();
    
    // Dividir horas y minutos
    List<String> parts = timeText.split(':');
    int hour = int.tryParse(parts[0].trim()) ?? 0;
    int minute = int.tryParse(parts[1].trim()) ?? 0;
    
    // Ajustar para PM
    if (isPM && hour < 12) hour += 12;
    if (!isPM && hour == 12) hour = 0;
    
    return TimeOfDay(hour: hour, minute: minute);
  } catch (e) {
    return TimeOfDay(hour: 8, minute: 0);  // Valor predeterminado en caso de error
  }
}

// Función auxiliar para formatear TimeOfDay a formato 24 horas como String
String _formatTimeOfDayTo24(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute:00'; // Añadir segundos (00)
}