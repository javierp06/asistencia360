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
    final currencyFormat = NumberFormat.currency(
      locale: 'es_HN',
      symbol: 'L',
      decimalDigits: 2,
    );

    return Dialog(
      // Set a maximum width to prevent overflow on wider screens
      // and use constraints to make it responsive
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500, // Maximum width for the dialog
          maxHeight: MediaQuery.of(context).size.height * 0.9, // 90% of screen height
        ),
        width: MediaQuery.of(context).size.width > 600 
            ? 500 // Fixed width for larger screens
            : MediaQuery.of(context).size.width * 0.95, // 95% of screen width for smaller screens
        child: SingleChildScrollView( // Ensure entire form can scroll if needed
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : errorMessage != null
                    ? _buildErrorContent()
                    : _buildFormContent(currencyFormat),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 16),
        Text(
          errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _fetchEmployees,
          child: const Text('Intentar nuevamente'),
        ),
      ],
    );
  }

  Widget _buildFormContent(NumberFormat currencyFormat) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título del diálogo
            Center(
              child: Text(
                'Crear Nueva Nómina',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            const Divider(height: 24),

            // Selección de empleado
            DropdownButtonFormField<Employee>(
              decoration: const InputDecoration(
                labelText: 'Seleccionar Empleado',
                border: OutlineInputBorder(),
                isDense: true, // Make the input more compact
              ),
              isExpanded: true, // Ensure dropdown takes full width of parent
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
                    overflow: TextOverflow.ellipsis, // Add text overflow handling
                    maxLines: 1, // Limit to single line
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

            const SizedBox(height: 16),

            // Selección de período (solo mes)
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Mes',
                border: OutlineInputBorder(),
                isDense: true, // Make it compact
              ),
              isExpanded: true, // Use full width
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

            const SizedBox(height: 16),

            // Grid para mostrar datos del empleado
            if (selectedEmployee != null)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Información del Empleado',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow('Nombre', '${selectedEmployee!.nombre} ${selectedEmployee!.apellido}'),
                      _buildInfoRow('DNI', selectedEmployee!.dni),
                      _buildInfoRow('Salario Base', currencyFormat.format(selectedEmployee!.salario)),
                      _buildInfoRow(
                        'Fecha Contratación', 
                        DateFormat('dd/MM/yyyy').format(selectedEmployee!.fechaContratacion)
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Bonificaciones
            TextFormField(
              controller: _bonificacionesController,
              decoration: const InputDecoration(
                labelText: 'Bonificaciones',
                prefixText: 'L',
                border: OutlineInputBorder(),
                isDense: true, // Add this property
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d*$'),
                ),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingrese un valor';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Horas Extra
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _horasExtraController,
                    decoration: const InputDecoration(
                      labelText: 'Horas Extra',
                      border: OutlineInputBorder(),
                      isDense: true, // Add this property
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d*$'),
                      ),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingrese un valor';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: ElevatedButton(
                    onPressed: selectedEmployee != null ? _calculateOvertimeFromAttendance : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Calcular'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            const SizedBox(height: 24),

            // Resumen de cálculos
            if (showCalculations && selectedEmployee != null)
              Card(
                elevation: 2,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resumen de Cálculos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const Divider(),
                      _buildCalculationRow(
                        'Salario Base',
                        currencyFormat.format(salarioBase),
                      ),
                      _buildCalculationRow(
                        'Horas Extra',
                        currencyFormat.format(horasExtraTotal),
                      ),
                      _buildCalculationRow(
                        'Bonificaciones',
                        currencyFormat.format(
                          double.tryParse(
                                _bonificacionesController.text,
                              ) ??
                              0,
                        ),
                      ),
                      const Divider(),
                      _buildCalculationRow(
                        'Salario Bruto',
                        currencyFormat.format(salarioBruto),
                        isBold: true,
                      ),
                      const SizedBox(height: 8),
                      _buildCalculationRow(
                        'Deducción RAP (4%)',
                        '- ${currencyFormat.format(deduccionRap)}',
                      ),
                      _buildCalculationRow(
                        'Deducción IHSS (2.5%)',
                        '- ${currencyFormat.format(deduccionIhss)}',
                      ),
                      const Divider(),
                      _buildCalculationRow(
                        'Salario Neto',
                        currencyFormat.format(salarioNeto),
                        isBold: true,
                        color: Colors.green,
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Botones de acción
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8.0,
                runSpacing: 8.0, // Space between rows if buttons wrap
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: isLoading ? null : _submitPayroll,
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.0),
                          )
                        : const Text('Crear Nómina'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculationRow(
    String label,
    String value, {
    bool isBold = false,
    Color color = Colors.black,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(value),
        ],
      ),
    );
  }
}
