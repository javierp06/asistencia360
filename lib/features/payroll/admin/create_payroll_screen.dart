import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../../core/config/api_config.dart';
import '../../../core/models/employee.dart';
import '../../../core/models/deduccion.dart';
// Cambiando a un Dialog en lugar de una pantalla completa
class CreatePayrollDialog extends StatefulWidget {
  const CreatePayrollDialog({Key? key}) : super(key: key);

  @override
  State<CreatePayrollDialog> createState() => _CreatePayrollDialogState();
}

class _CreatePayrollDialogState extends State<CreatePayrollDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool showCalculations = false;
  String? errorMessage;
  List<Employee> employees = [];
  Employee? selectedEmployee;

  // Controladores para los campos del formulario
  final TextEditingController _bonificacionesController =
      TextEditingController();
  final TextEditingController _horasExtraController = TextEditingController();

  // Solo usar el mes en lugar de mes y año
  String _periodoSeleccionado = '';

  // Variables calculadas
  double salarioBase = 0;
  double salarioBruto = 0;
  double deduccionRap = 0;
  double deduccionIhss = 0;
  double salarioNeto = 0;
  double horasExtraTotal = 0;

  // 1. Agrega esta variable de clase
  List<EmpleadoDeduccion> empleadoDeducciones = [];

  // Agrega estas variables de clase
  double totalHorasTrabajadas = 0; // Total de horas trabajadas en el mes
  final int horasBasesMensuales = 160; // Horas base mensuales (40h×4 semanas)

  @override
  void initState() {
    super.initState();
    _bonificacionesController.text = '0';
    _horasExtraController.text = '0';
    _fetchEmployees();

    // Listeners para actualizar cálculos
    _bonificacionesController.addListener(_updateCalculations);
    _horasExtraController.addListener(_updateCalculations);
  }

  @override
  void dispose() {
    _bonificacionesController.dispose();
    _horasExtraController.dispose();
    super.dispose();
  }

  // 3. Modifica el método _updateCalculations para usar deducciones personalizadas
  void _updateCalculations() {
    if (selectedEmployee == null) return;

    final bonificaciones = double.tryParse(_bonificacionesController.text) ?? 0;
    final horasExtra = double.tryParse(_horasExtraController.text) ?? 0;

    // Calcular salario base y bruto
    salarioBase = selectedEmployee!.salario;

    // Calcular valor de las horas extras (1.5 veces el valor hora normal)
    final valorHoraNormal = salarioBase / horasBasesMensuales; // 40h×4 semanas
    horasExtraTotal = horasExtra * valorHoraNormal * 1.5;

    salarioBruto = salarioBase + bonificaciones + horasExtraTotal;

    // Calcular deducciones personalizadas
    double totalDeducciones = 0;
  
    if (empleadoDeducciones.isNotEmpty) {
      // Si hay deducciones asignadas, usarlas
      for (final empDeduccion in empleadoDeducciones) {
        if (empDeduccion.activo) {
          final deduccion = empDeduccion.deduccion;
          final montoDeduccion = salarioBruto * (deduccion.porcentaje / 100);
          totalDeducciones += montoDeduccion;
        }
      }
    } else {
      // Si no hay deducciones personalizadas, usar las estándar
      deduccionRap = salarioBruto * 0.04;
      deduccionIhss = salarioBruto * 0.025;
      totalDeducciones = deduccionRap + deduccionIhss;
    }

    // Calcular salario neto
    salarioNeto = salarioBruto - totalDeducciones;

    setState(() {
      showCalculations = true;
    });
  }

  Future<void> _fetchEmployees() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'token');

      if (token == null) {
        setState(() {
          errorMessage = 'No se encontró token de autenticación';
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('https://timecontrol-backend.onrender.com/empleados'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);

        if (responseData.isEmpty) {
          setState(() {
            errorMessage = 'No hay empleados disponibles';
            isLoading = false;
          });
          return;
        }

        final loadedEmployees =
            responseData.map((data) => Employee.fromJson(data)).toList();

        setState(() {
          employees = loadedEmployees;
          isLoading = false;
        });

        // Debug para verificar que hay empleados
      } else {
        setState(() {
          errorMessage = 'Error al cargar empleados: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        errorMessage = 'Error de conexión: $error';
        isLoading = false;
      });
    }
  }

  // 1. Modifica el método _fetchEmployeePayrollsAndSetNextPeriod para calcular automáticamente
  Future<void> _fetchEmployeePayrollsAndSetNextPeriod() async {
    if (selectedEmployee == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'token');

      final response = await http.get(
        Uri.parse(
          'https://timecontrol-backend.onrender.com/nominas/empleado/${selectedEmployee!.id}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> payrolls = data['nominas'] ?? [];

        // Establecer el siguiente período basado en el historial de nóminas
        final nextPeriod = _calculateNextPayrollPeriod(payrolls);

        setState(() {
          _periodoSeleccionado = nextPeriod;
          isLoading = false;
        });
        
        // Calcular automáticamente las horas extras al seleccionar un empleado y período
        _calculateOvertimeFromAttendance();
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Error al cargar nóminas: ${response.statusCode}';
        });
      }
    } catch (error) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error: $error';
      });
    }
  }

  // Calcular el siguiente período basado en nóminas existentes
  String _calculateNextPayrollPeriod(List<dynamic> payrolls) {
    // Si no hay nóminas previas, usar el mes actual
    if (payrolls.isEmpty) {
      final now = DateTime.now();
      return '${now.year}-${now.month.toString().padLeft(2, '0')}';
    }

    // Encontrar el período más reciente
    String? latestPeriod;
    DateTime latestDate = DateTime(1900);

    for (var payroll in payrolls) {
      if (payroll['periodo'] != null) {
        final String period = payroll['periodo'];
        // Parsear formato YYYY-MM
        if (period.contains('-') && period.length >= 7) {
          try {
            final parts = period.split('-');
            final year = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final date = DateTime(year, month);

            if (date.isAfter(latestDate)) {
              latestDate = date;
              latestPeriod = period;
            }
          } catch (e) {
            // Omitir formato inválido
          }
        }
      }
    }

    // Si no se encontraron períodos válidos, usar el mes actual
    if (latestPeriod == null) {
      final now = DateTime.now();
      return '${now.year}-${now.month.toString().padLeft(2, '0')}';
    }

    // Parsear el último período e incrementar un mes
    final parts = latestPeriod.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    // Calcular el próximo mes
    DateTime nextDate;
    if (month == 12) {
      nextDate = DateTime(year + 1, 1);
    } else {
      nextDate = DateTime(year, month + 1);
    }

    return '${nextDate.year}-${nextDate.month.toString().padLeft(2, '0')}';
  }

  // Formatear YYYY-MM a formato más legible para mostrar
  String _formatPeriodDisplay(String period) {
    if (period.contains('-') && period.length >= 7) {
      try {
        final parts = period.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);

        final monthNames = [
          'Enero',
          'Febrero',
          'Marzo',
          'Abril',
          'Mayo',
          'Junio',
          'Julio',
          'Agosto',
          'Septiembre',
          'Octubre',
          'Noviembre',
          'Diciembre',
        ];

        if (month >= 1 && month <= 12) {
          return '${monthNames[month - 1]} $year';
        }
      } catch (e) {
        // Si el parsing falla, devolver el período original
      }
    }
    return period;
  }

  Future<void> _submitPayroll() async {
    if (!_formKey.currentState!.validate() || selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor complete todos los campos requeridos'),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'token');

      // Obtener el año actual para el período
      final currentYear = DateTime.now().year;

      // Recalcular valores para asegurar que estén actualizados
      _updateCalculations();

      final payrollData = {
        'id_empleado': selectedEmployee!.id,
        'periodo': _periodoSeleccionado, // Ya no concatenar con el año, pues ya viene con formato YYYY-MM
        'bonificaciones': double.parse(_bonificacionesController.text),
        'horas_extra': double.parse(_horasExtraController.text), // Este valor ya viene calculado automáticamente
        'salario_bruto': salarioBruto,
        'salario_neto': salarioNeto,
        'deduccion_rap': deduccionRap,
        'deduccion_ihss': deduccionIhss,
        'fecha_generacion': DateTime.now().toIso8601String(),
      };

      final response = await http.post(
        Uri.parse('https://timecontrol-backend.onrender.com/nominas'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(payrollData),
      );

      setState(() {
        isLoading = false;
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nómina creada correctamente')),
        );
        Navigator.pop(context, true); // Pasar true para indicar éxito
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear la nómina: ${response.statusCode}'),
          ),
        );
      }
    } catch (error) {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $error')));
    }
  }

  // Modifica el método _calculateOvertimeFromAttendance
  Future<void> _calculateOvertimeFromAttendance() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Extraer el mes y año del formato YYYY-MM
      if (_periodoSeleccionado.isEmpty || !_periodoSeleccionado.contains('-')) {
        throw Exception('Formato de período inválido, debe ser YYYY-MM');
      }
      
      final parts = _periodoSeleccionado.split('-');
      final int year = int.parse(parts[0]);
      final int month = int.parse(parts[1]);

      // Calculate start and end dates for the period
      final DateTime startDate = DateTime(year, month, 1);
      final DateTime endDate = DateTime(
        year,
        month + 1,
        0,
      ); // Last day of month

      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'token');

      // Fetch attendance records for this employee in this period
      final response = await http.get(
        Uri.parse(
          'https://timecontrol-backend.onrender.com/asistencia?id_empleado=${selectedEmployee!.id}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> allAttendanceData = json.decode(response.body);
        
        // Filtrar los registros por el rango de fechas seleccionado
        final List<dynamic> attendanceData = allAttendanceData.where((record) {
          if (record['fecha'] == null) return false;
          final recordDate = DateTime.parse(record['fecha']);
          return recordDate.isAfter(startDate.subtract(const Duration(days: 1))) && 
                 recordDate.isBefore(endDate.add(const Duration(days: 1)));
        }).toList();
        
        print('Registros totales: ${allAttendanceData.length}, Filtrados para el período: ${attendanceData.length}');
        
        // Resto del código existente para calcular las horas
        double totalHours = 0;
        for (var record in attendanceData) {
          // Check if the record has both entry and exit times
          final String entryTime = record['hora_entrada'] ?? '';
          final String exitTime = record['hora_salida'] ?? '';

          if (entryTime.isNotEmpty &&
              exitTime.isNotEmpty &&
              entryTime != '--:--' &&
              exitTime != '--:--') {
            // Parse times and calculate hours worked
            final List<String> entryParts = entryTime.split(':');
            final List<String> exitParts = exitTime.split(':');

            if (entryParts.length >= 2 && exitParts.length >= 2) {
              final int entryHour = int.tryParse(entryParts[0]) ?? 0;
              final int entryMinute = int.tryParse(entryParts[1]) ?? 0;
              final int exitHour = int.tryParse(exitParts[0]) ?? 0;
              final int exitMinute = int.tryParse(exitParts[1]) ?? 0;

              double hoursWorked =
                  (exitHour - entryHour) + (exitMinute - entryMinute) / 60.0;
              if (hoursWorked < 0) hoursWorked += 24; // If crossing midnight

              totalHours += hoursWorked;
            }
          }
        }

        // Calculate overtime (anything over 40 hours per week)
        // For simplicity, we'll assume 160 hours is the standard for a month (40 * 4)
        final double overtimeHours = totalHours > 160 ? totalHours - 160 : 0;

        // Una vez calculadas todas las horas, actualiza las variables
        totalHorasTrabajadas = totalHours;

        // Update the overtime field
        setState(() {
          _horasExtraController.text = overtimeHours.toStringAsFixed(1);
          _updateCalculations();
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Horas trabajadas: ${totalHorasTrabajadas.toStringAsFixed(1)} | ' +
              'Horas extra: ${overtimeHours.toStringAsFixed(1)}',
            ),
          ),
        );
      } else {
        throw Exception(
          'Error al cargar datos de asistencia: ${response.statusCode}',
        );
      }
    } catch (error) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al calcular horas extra: $error')),
      );
    }
  }

  // 2. Agrega este método para obtener las deducciones del empleado
  Future<void> _fetchEmpleadoDeducciones() async {
    if (selectedEmployee == null) return;
    
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/deducciones/empleado/${selectedEmployee!.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          empleadoDeducciones = data.map((json) => EmpleadoDeduccion.fromJson(json)).toList();
          // Recalcular las deducciones después de obtenerlas
          _updateCalculations();
        });
      }
    } catch (error) {
      // Manejar error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar deducciones: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        // Restringir altura máxima y permitir scroll
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        // Añadir SingleChildScrollView alrededor del Column principal
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              Row(
                children: [
                  Icon(
                    Icons.add_chart,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Generar Nueva Nómina',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
              const Divider(height: 24),

              // Contenido del formulario
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (errorMessage != null)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                        onPressed: _fetchEmployees,
                      ),
                    ],
                  ),
                )
              else
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selector de empleado mejorado
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: DropdownButtonFormField<Employee>(
                          decoration: InputDecoration(
                            labelText: 'Seleccionar Empleado',
                            labelStyle: TextStyle(
                              color: theme.colorScheme.primary,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.person,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          isExpanded: true,
                          value: selectedEmployee,
                          onChanged: (Employee? value) {
                            setState(() {
                              selectedEmployee = value;
                              if (value != null) {
                                _fetchEmployeePayrollsAndSetNextPeriod(); // Añadir esta llamada
                                _fetchEmpleadoDeducciones(); // Agrega esta línea
                                // No llames a _updateCalculations aquí, ya se llama después de obtener las deducciones
                              } else {
                                showCalculations = false;
                              }
                            });
                          },
                          items:
                              employees.map<DropdownMenuItem<Employee>>((
                                Employee employee,
                              ) {
                                return DropdownMenuItem<Employee>(
                                  value: employee,
                                  child: Text(
                                    '${employee.nombre} ${employee.apellido} - ${employee.dni}',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                );
                              }).toList(),
                          validator: (value) {
                            if (value == null) {
                              return 'Por favor seleccione un empleado';
                            }
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_month,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Período a pagar',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  _periodoSeleccionado.isEmpty
                                      ? const Text(
                                        'Se calculará al seleccionar empleado',
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey,
                                        ),
                                      )
                                      : Text(
                                        _formatPeriodDisplay(
                                          _periodoSeleccionado,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Campos para bonificaciones y horas extra
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _bonificacionesController,
                              decoration: InputDecoration(
                                labelText: 'Bonificaciones',
                                prefixText: 'L ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: const Icon(Icons.card_giftcard),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _horasExtraController,
                              decoration: InputDecoration(
                                labelText: 'Horas Extra (calculadas)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: const Icon(Icons.timer),
                                suffixIcon: const Tooltip(
                                  message: 'Este valor se calcula automáticamente basado en el registro de asistencia',
                                  child: Icon(Icons.info_outline),
                                ),
                              ),
                              enabled: false, // Hacer el campo de solo lectura
                              style: TextStyle(
                                color: theme.colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Añade un botón descriptivo para calcular automáticamente
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.secondary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: theme.colorScheme.secondary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Horas extras calculadas automáticamente',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: theme.colorScheme.secondary,
                                    ),
                                  ),
                                  Text(
                                    'Basadas en ${totalHorasTrabajadas.toStringAsFixed(1)} horas trabajadas en el período (estándar: $horasBasesMensuales h)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Recalcular',
                              onPressed: _calculateOvertimeFromAttendance,
                              color: theme.colorScheme.secondary,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Cálculos y Resumen
                      if (showCalculations && selectedEmployee != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withOpacity(
                              0.3,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Resumen de Cálculos',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const Divider(height: 24),
                              _buildCalculationItem(
                                'Salario Base:',
                                NumberFormat.currency(
                                  locale: 'es_HN',
                                  symbol: 'L',
                                ).format(salarioBase),
                              ),
                              _buildCalculationItem(
                                'Horas Extra:',
                                NumberFormat.currency(
                                  locale: 'es_HN',
                                  symbol: 'L',
                                ).format(horasExtraTotal),
                              ),
                              _buildCalculationItem(
                                'Bonificaciones:',
                                NumberFormat.currency(
                                  locale: 'es_HN',
                                  symbol: 'L',
                                ).format(
                                  double.tryParse(
                                        _bonificacionesController.text,
                                      ) ??
                                      0,
                                ),
                              ),
                              const Divider(height: 16),
                              _buildCalculationItem(
                                'Salario Bruto:',
                                NumberFormat.currency(
                                  locale: 'es_HN',
                                  symbol: 'L',
                                ).format(salarioBruto),
                                isBold: true,
                              ),
                              const Divider(height: 16),
                              if (empleadoDeducciones.isNotEmpty)
                                ...empleadoDeducciones
                                    .where((ed) => ed.activo)
                                    .map((ed) {
                                      final deduccion = ed.deduccion;
                                      final montoDeduccion = salarioBruto * (deduccion.porcentaje / 100);
                                      return _buildCalculationItem(
                                        '${deduccion.nombre} (${deduccion.porcentaje}%):',
                                        '-${NumberFormat.currency(locale: 'es_HN', symbol: 'L').format(montoDeduccion)}',
                                        isDeduction: true,
                                      );
                                    })
                                    .toList()
                              else
                                Column(
                                  children: [
                                    _buildCalculationItem(
                                      'Deducción RAP (4%):',
                                      '-${NumberFormat.currency(locale: 'es_HN', symbol: 'L').format(deduccionRap)}',
                                      isDeduction: true,
                                    ),
                                    _buildCalculationItem(
                                      'Deducción IHSS (2.5%):',
                                      '-${NumberFormat.currency(locale: 'es_HN', symbol: 'L').format(deduccionIhss)}',
                                      isDeduction: true,
                                    ),
                                  ],
                                ),
                              const Divider(height: 16),
                              _buildCalculationItem(
                                'Salario Neto:',
                                NumberFormat.currency(
                                  locale: 'es_HN',
                                  symbol: 'L',
                                ).format(salarioNeto),
                                isBold: true,
                                isTotal: true,
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Botones de acción
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('CANCELAR'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.save),
                            label: const Text('GUARDAR NÓMINA'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _submitPayroll,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalculationItem(
    String label,
    String value, {
    bool isBold = false,
    bool isDeduction = false,
    bool isTotal = false,
    Color? color,
  }) {
    final textColor =
        isDeduction
            ? Colors.red.shade700
            : isTotal
            ? Colors.green.shade700
            : color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: textColor,
              fontSize: isTotal ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
