import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../../core/models/employee.dart';

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
  String _periodoSeleccionado = 'Enero';

  // Variables calculadas
  double salarioBase = 0;
  double salarioBruto = 0;
  double deduccionRap = 0;
  double deduccionIhss = 0;
  double salarioNeto = 0;
  double horasExtraTotal = 0;

  // Lista simplificada de meses
  final List<String> periodos = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

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

  void _updateCalculations() {
    if (selectedEmployee == null) return;

    final bonificaciones = double.tryParse(_bonificacionesController.text) ?? 0;
    final horasExtra = double.tryParse(_horasExtraController.text) ?? 0;

    // Calcular salario base y bruto
    salarioBase = selectedEmployee!.salario;

    // Suponiendo que la hora extra vale 1.5 veces la hora normal
    final valorHoraNormal = salarioBase / 160; // 40 horas semanales × 4 semanas
    horasExtraTotal = horasExtra * valorHoraNormal * 1.5;

    salarioBruto = salarioBase + bonificaciones + horasExtraTotal;

    // Calcular deducciones
    deduccionRap = salarioBruto * 0.04; // 4% para RAP
    deduccionIhss = salarioBruto * 0.025; // 2.5% para IHSS

    // Calcular salario neto
    salarioNeto = salarioBruto - deduccionRap - deduccionIhss;

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
        'periodo': '$_periodoSeleccionado $currentYear',  // Añadir el año actual al período
        'bonificaciones': double.parse(_bonificacionesController.text),
        'horas_extra': double.parse(_horasExtraController.text),
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
        Navigator.pop(context, true);  // Pasar true para indicar éxito
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }

  Future<void> _calculateOvertimeFromAttendance() async {
    if (selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor seleccione un empleado primero'),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Obtener el mes y año correspondientes al período seleccionado
      final int month = periodos.indexOf(_periodoSeleccionado) + 1;
      final int year = DateTime.now().year;

      // Calculate start and end dates for the period
      final DateTime startDate = DateTime(year, month, 1);
      final DateTime endDate = DateTime(year, month + 1, 0); // Last day of month

      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'token');

      // Fetch attendance records for this employee in this period
      final response = await http.get(
        Uri.parse(
          'https://timecontrol-backend.onrender.com/asistencia?id_empleado=${selectedEmployee!.id}&fecha_inicio=${DateFormat('yyyy-MM-dd').format(startDate)}&fecha_fin=${DateFormat('yyyy-MM-dd').format(endDate)}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> attendanceData = json.decode(response.body);

        // Calculate total hours worked
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

        // Update the overtime field
        setState(() {
          _horasExtraController.text = overtimeHours.toStringAsFixed(1);
          _updateCalculations();
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Horas extra calculadas: ${overtimeHours.toStringAsFixed(1)}',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Row(
              children: [
                Icon(Icons.add_chart, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Generar Nueva Nómina',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
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
                    Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
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
                              _updateCalculations();
                            } else {
                              showCalculations = false;
                            }
                          });
                        },
                        items: employees.map<DropdownMenuItem<Employee>>((Employee employee) {
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

                    // Selección de período (solo mes)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Mes',
                          labelStyle: TextStyle(
                            color: theme.colorScheme.primary,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.calendar_month,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        isExpanded: true,
                        value: _periodoSeleccionado,
                        onChanged: (String? value) {
                          setState(() {
                            _periodoSeleccionado = value!;
                          });
                        },
                        items: periodos.map<DropdownMenuItem<String>>((String month) {
                          return DropdownMenuItem<String>(
                            value: month,
                            child: Text(month),
                          );
                        }).toList(),
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
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _horasExtraController,
                            decoration: InputDecoration(
                              labelText: 'Horas Extra',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixIcon: const Icon(Icons.timer),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Cálculos y Resumen
                    if (showCalculations && selectedEmployee != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
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
                              NumberFormat.currency(locale: 'es_HN', symbol: 'L').format(salarioBase),
                            ),
                            _buildCalculationItem(
                              'Horas Extra:',
                              NumberFormat.currency(locale: 'es_HN', symbol: 'L').format(horasExtraTotal),
                            ),
                            _buildCalculationItem(
                              'Bonificaciones:',
                              NumberFormat.currency(locale: 'es_HN', symbol: 'L').format(
                                double.tryParse(_bonificacionesController.text) ?? 0,
                              ),
                            ),
                            const Divider(height: 16),
                            _buildCalculationItem(
                              'Salario Bruto:',
                              NumberFormat.currency(locale: 'es_HN', symbol: 'L').format(salarioBruto),
                              isBold: true,
                            ),
                            const Divider(height: 16),
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
                            const Divider(height: 16),
                            _buildCalculationItem(
                              'Salario Neto:',
                              NumberFormat.currency(locale: 'es_HN', symbol: 'L').format(salarioNeto),
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
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
    );
  }

  Widget _buildCalculationItem(String label, String value, {bool isBold = false, bool isDeduction = false, bool isTotal = false}) {
    final textColor = isDeduction 
        ? Colors.red.shade700 
        : isTotal 
            ? Colors.green.shade700 
            : null;
    
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
