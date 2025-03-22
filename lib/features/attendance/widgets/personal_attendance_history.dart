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
  final bool isAdmin; // Añadir esta propiedad

  const PersonalAttendanceHistory({
    Key? key,
    this.showSummary = true,
    this.employeeName,
    this.employeeId,
    this.isAdmin = false, // Valor predeterminado falso para seguridad
  }) : super(key: key);

  @override
  State<PersonalAttendanceHistory> createState() =>
      _PersonalAttendanceHistoryState();
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
      final url =
          widget.employeeId != null
              ? Uri.parse(
                'https://timecontrol-backend.onrender.com/asistencia?id_empleado=${widget.employeeId}',
              )
              : Uri.parse(
                'https://timecontrol-backend.onrender.com/asistencia',
              );

      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

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
        final filteredRecords =
            widget.employeeId != null
                ? responseData
                    .where(
                      (record) =>
                          record['id_empleado'].toString() ==
                          widget.employeeId.toString(),
                    )
                    .toList()
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
        final records =
            filteredRecords.map((record) {
              // Calcular horas trabajadas
              final entryTime = record['hora_entrada'] ?? '--:--';
              final exitTime = record['hora_salida'] ?? '--:--';

              double hoursWorked = 0;
              final status =
                  entryTime != '--:--' && exitTime != '--:--'
                      ? 'Presente'
                      : 'Ausente';

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
                  hoursWorked =
                      (exitHour - entryHour) + (exitMinute - entryMinute) / 60;
                  if (hoursWorked < 0) hoursWorked += 24; // Si cruza medianoche
                }
              }

              return {
                'id': record['id_asistencia'],
                'date': DateTime.parse(record['fecha']),
                'checkIn':
                    entryTime, // Mantener el formato original para cálculos
                'checkInFormatted': _formatTimeToAMPM(
                  entryTime,
                ), // Añadir versión formateada
                'checkOut':
                    exitTime, // Mantener el formato original para cálculos
                'checkOutFormatted': _formatTimeToAMPM(
                  exitTime,
                ), // Añadir versión formateada
                'status': status,
                'hoursWorked': hoursWorked,
                'employeeName':
                    record['empleado'] != null
                        ? '${record['empleado']['nombre']} ${record['empleado']['apellido']}'
                        : '',
              };
            }).toList();

        // Ordenar por fecha (más reciente primero)
        records.sort(
          (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
        );

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
    final totalHours = records.fold(
      0.0,
      (sum, record) => sum + (record['hoursWorked'] as double),
    );

    // Contar llegadas tarde (ejemplo: después de 8:00)
    final lateArrivals =
        records.where((r) {
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
                Expanded(
                  // Añadir Expanded para controlar texto largo
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
    final theme = Theme.of(context);
    return Card(
      elevation: 3,
      shadowColor: theme.shadowColor.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: theme.primaryColor, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Resumen del mes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 24, thickness: 1),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryItemEnhanced(
                    title: 'Días Totales',
                    value: attendanceSummary['totalDays'].toString(),
                    icon: Icons.calendar_month,
                    color: theme.primaryColor,
                  ),
                  const SizedBox(width: 16),
                  _buildSummaryItemEnhanced(
                    title: 'Días Presentes',
                    value: attendanceSummary['presentDays'].toString(),
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 16),
                  _buildSummaryItemEnhanced(
                    title: 'Ausencias',
                    value: attendanceSummary['absentDays'].toString(),
                    icon: Icons.cancel,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 16),
                  _buildSummaryItemEnhanced(
                    title: 'Horas Totales',
                    value: attendanceSummary['totalHours'].toStringAsFixed(1),
                    icon: Icons.access_time,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 16),
                  _buildSummaryItemEnhanced(
                    title: 'Llegadas Tarde',
                    value: attendanceSummary['lateArrivals'].toString(),
                    icon: Icons.watch_later,
                    color: Colors.orange,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
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

  Widget _buildSummaryItemEnhanced({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(
    BuildContext context,
    Map<String, dynamic> record,
  ) {
    final date = record['date'] as DateTime;
    final isPresent = record['status'] == 'Presente';
    final dateFormat = DateFormat('EEEE, d MMM, yyyy', 'es');
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      elevation: 2,
      shadowColor: theme.shadowColor.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              isPresent
                  ? Colors.green.withOpacity(0.3)
                  : Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor:
                isPresent
                    ? Colors.green.withOpacity(0.8)
                    : Colors.red.withOpacity(0.8),
            child: Icon(
              isPresent ? Icons.check : Icons.close,
              color: Colors.white,
            ),
          ),
          title: Text(
            dateFormat.format(date),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: theme.textTheme.titleMedium?.color,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                isPresent
                    ? 'Entrada: ${record['checkInFormatted']} - Salida: ${record['checkOutFormatted']}'
                    : 'No se registró asistencia',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
              if (isPresent)
                Text(
                  '${record['hoursWorked'].toStringAsFixed(1)} horas trabajadas',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.primaryColor,
                  ),
                ),
            ],
          ),
          trailing:
              widget.isAdmin
                  ? ElevatedButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Editar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      _showEditAttendanceDialog(context, record);
                    },
                  )
                  : null,
        ),
      ),
    );
  }

  void _showEditAttendanceDialog(
    BuildContext context,
    Map<String, dynamic> record,
  ) {
    // Analizar las horas y minutos de entrada y salida
    final entryTime = _parseTime(record['checkInFormatted']);
    final exitTime = _parseTime(record['checkOutFormatted']);

    // Variables para almacenar los valores seleccionados
    TimeOfDay selectedEntryTime = entryTime;
    TimeOfDay selectedExitTime = exitTime;

    final date = record['date'] as DateTime;
    final dateFormat = DateFormat('EEEE, d MMM, yyyy', 'es');
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 5,
            backgroundColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      offset: const Offset(0.0, 10.0),
                      blurRadius: 20.0,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.edit_calendar,
                            color: theme.primaryColor,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Editar Registro de Asistencia',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Fecha
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(
                            0.3,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                dateFormat.format(date),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Secciones con títulos más atractivos
                      _buildSectionTitle(
                        context,
                        'Horario de Entrada/Salida',
                        Icons.access_time,
                      ),
                      const SizedBox(height: 16),

                      // Hora de entrada con mejor estilo
                      Text(
                        'Hora de entrada',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTimePicker(context, selectedEntryTime, (
                        TimeOfDay time,
                      ) {
                        selectedEntryTime = time;
                      }),

                      const SizedBox(height: 24),

                      // Hora de salida con mejor estilo
                      Text(
                        'Hora de salida',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTimePicker(context, selectedExitTime, (
                        TimeOfDay time,
                      ) {
                        selectedExitTime = time;
                      }),

                      const SizedBox(height: 32),

                      // Botones con mejor diseño
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('CANCELAR'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              final entryFormatted = _formatTimeOfDayTo24(
                                selectedEntryTime,
                              );
                              final exitFormatted = _formatTimeOfDayTo24(
                                selectedExitTime,
                              );

                              _updateAttendance(
                                record['id'].toString(),
                                entryFormatted,
                                exitFormatted,
                              );

                              // No cerramos el diálogo aquí, se cerrará en _updateAttendance si es exitoso
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('GUARDAR CAMBIOS'),
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

  Future<void> _updateAttendance(
    String attendanceId,
    String entry,
    String exit,
  ) async {
    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      setState(() {
        _isLoading = true;
      });

      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'token');

      // Asegurar que tenemos los formatos correctos
      final entryTime = entry.split(':').take(2).join(':');
      final exitTime = exit.split(':').take(2).join(':');

      print(
        'Enviando actualización: ID=$attendanceId, entrada=$entryTime, salida=$exitTime',
      );

      final url = Uri.parse(
        'https://timecontrol-backend.onrender.com/asistencia/$attendanceId',
      );

      final response = await http
          .put(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'hora_entrada': entryTime,
              'hora_salida': exitTime,
            }),
          )
          .timeout(const Duration(seconds: 30));

      // Cerrar el diálogo de carga
      Navigator.of(context).pop();

      print('Respuesta del servidor: ${response.statusCode}');
      print('Cuerpo de respuesta: ${response.body}');

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        Navigator.of(context).pop(); // Cerrar el diálogo de edición

        // Mostrar diálogo de éxito
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 28),
                  const SizedBox(width: 10),
                  const Text('¡Actualizado!'),
                ],
              ),
              content: const Text(
                'Registro de asistencia actualizado correctamente.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );

        _fetchAttendanceData(); // Recargar los datos
      } else {
        // Mostrar diálogo de error
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[600], size: 28),
                  const SizedBox(width: 10),
                  const Text('Error'),
                ],
              ),
              content: Text(
                'Error al actualizar: ${response.statusCode}\n${response.body}',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (error) {
      // Cerrar el diálogo de carga si existe
      Navigator.of(context, rootNavigator: true).pop();

      setState(() {
        _isLoading = false;
      });

      print('Error en actualización: $error');

      // Mostrar diálogo de error
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[600], size: 28),
                const SizedBox(width: 10),
                const Text('Error'),
              ],
            ),
            content: Text('Error de conexión: $error'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
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
  if (!timeAMPM.toLowerCase().contains('am') &&
      !timeAMPM.toLowerCase().contains('pm')) {
    return timeAMPM;
  }

  // Extraer AM/PM
  bool isPM = timeAMPM.toLowerCase().contains('pm');

  // Remover AM/PM
  timeAMPM =
      timeAMPM.toLowerCase().replaceAll('am', '').replaceAll('pm', '').trim();

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

  const _SummaryItem({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// Agregar esta nueva versión del método para los títulos de sección que se adapta al tema
Widget _buildSectionAdaptive(
  BuildContext context,
  String title,
  IconData icon,
) {
  return Row(
    children: [
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
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
Widget _buildTimePicker(
  BuildContext context,
  TimeOfDay initialTime,
  Function(TimeOfDay) onTimeChanged,
) {
  final theme = Theme.of(context);

  return Container(
    height: 150,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: theme.colorScheme.primary.withOpacity(0.3),
        width: 1.5,
      ),
      color: theme.colorScheme.surface,
    ),
    child: CupertinoTheme(
      data: CupertinoThemeData(
        brightness: theme.brightness,
        primaryColor: theme.colorScheme.primary,
        textTheme: CupertinoTextThemeData(
          dateTimePickerTextStyle: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 16,
          ),
        ),
      ),
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.time,
        initialDateTime: DateTime(
          2023,
          1,
          1,
          initialTime.hour,
          initialTime.minute,
        ),
        onDateTimeChanged: (DateTime newDateTime) {
          onTimeChanged(
            TimeOfDay(hour: newDateTime.hour, minute: newDateTime.minute),
          );
        },
        use24hFormat: true,
        minuteInterval: 1,
      ),
    ),
  );
}

// Función auxiliar para analizar el texto de tiempo en formato AM/PM
TimeOfDay _parseTime(String timeText) {
  if (timeText == '--:--') {
    return TimeOfDay(hour: 8, minute: 0); // Valor predeterminado
  }

  try {
    // Eliminar espacios y extraer AM/PM
    timeText = timeText.trim();
    bool isPM = timeText.toLowerCase().contains('pm');

    // Quitar AM/PM
    timeText =
        timeText.toLowerCase().replaceAll('am', '').replaceAll('pm', '').trim();

    // Dividir horas y minutos
    List<String> parts = timeText.split(':');
    int hour = int.tryParse(parts[0].trim()) ?? 0;
    int minute = int.tryParse(parts[1].trim()) ?? 0;

    // Ajustar para PM
    if (isPM && hour < 12) hour += 12;
    if (!isPM && hour == 12) hour = 0;

    return TimeOfDay(hour: hour, minute: minute);
  } catch (e) {
    return TimeOfDay(
      hour: 8,
      minute: 0,
    ); // Valor predeterminado en caso de error
  }
}

// Función auxiliar para formatear TimeOfDay a formato 24 horas como String
String _formatTimeOfDayTo24(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute:00'; // Añadir segundos (00)
}
