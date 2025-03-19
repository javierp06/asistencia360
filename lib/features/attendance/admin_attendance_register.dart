import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../../core/models/employee.dart';

class AdminAttendanceRegister extends StatefulWidget {
  const AdminAttendanceRegister({Key? key}) : super(key: key);

  @override
  State<AdminAttendanceRegister> createState() => _AdminAttendanceRegisterState();
}

class _AdminAttendanceRegisterState extends State<AdminAttendanceRegister> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  List<Employee> employees = [];
  Employee? selectedEmployee;
  String? errorMessage;
  String? statusMessage;
  bool isEntryRegistration = true; // true para entrada, false para salida
  
  // Controlador para el campo de DNI
  final TextEditingController _dniController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }
  
  @override
  void dispose() {
    _dniController.dispose();
    super.dispose();
  }

  Future<void> _fetchEmployees() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      
      final response = await http.get(
        Uri.parse('https://timecontrol-backend.onrender.com/empleados'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        final loadedEmployees = responseData
            .map((data) => Employee.fromJson(data))
            .toList();
        
        setState(() {
          employees = loadedEmployees;
          isLoading = false;
        });
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

  String _getCurrentTimeFormatted() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  // Método para buscar empleado por DNI
  void _findEmployeeByDNI() {
    final dni = _dniController.text.trim();
    if (dni.isEmpty) {
      setState(() {
        errorMessage = 'Por favor ingrese un DNI';
        selectedEmployee = null;
      });
      return;
    }

    try {
      final foundEmployee = employees.firstWhere(
        (emp) => emp.dni == dni,
        // No lanzar excepción, simplemente retornar null
        orElse: () => null!,
      );
      
      setState(() {
        selectedEmployee = foundEmployee;
        errorMessage = null;
        statusMessage = null;
      });
    } catch (e) {
      setState(() {
        selectedEmployee = null;
        errorMessage = 'No se encontró empleado con el DNI: $dni';
        statusMessage = null;
      });
      
      // Mostrar mensaje de error con SnackBar para mayor visibilidad
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.person_off, color: Colors.white),
              const SizedBox(width: 8),
              Text('Empleado con DNI: $dni no encontrado'),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _registerAttendance() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    
    // Buscar empleado por DNI antes de registrar solo si no hay empleado seleccionado
    if (selectedEmployee == null) {
      _findEmployeeByDNI();
      
      // Añadir un pequeño retraso para dar tiempo a _findEmployeeByDNI() para actualizar selectedEmployee
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Verificar nuevamente si hay empleado seleccionado
      if (selectedEmployee == null) {
        return;
      }
    }

    setState(() {
      isLoading = true;
      statusMessage = null;
      errorMessage = null;
    });

    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      final now = DateTime.now();
      final currentTime = _getCurrentTimeFormatted();
      final currentDate = DateFormat('yyyy-MM-dd').format(now);

      // Elegir el endpoint según sea entrada o salida
      final endpoint = isEntryRegistration 
          ? 'https://timecontrol-backend.onrender.com/asistencia/entrada'
          : 'https://timecontrol-backend.onrender.com/asistencia/salida';
      
      // Crear el objeto de datos con formato correcto
      final Map<String, dynamic> attendanceData = {
        'dni': selectedEmployee!.dni,
        'fecha': currentDate,
      };

      // Asignar la hora actual a entrada o salida según corresponda
      if (isEntryRegistration) {
        attendanceData['hora'] = currentTime;
      } else {
        attendanceData['hora'] = currentTime;
      }

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(attendanceData),
      );

      setState(() {
        isLoading = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          statusMessage = isEntryRegistration 
              ? 'Entrada registrada correctamente a las $currentTime'
              : 'Salida registrada correctamente a las $currentTime';
          _dniController.clear();
          selectedEmployee = null;
        });
      } else {
        final responseData = json.decode(response.body);
        setState(() {
          errorMessage = responseData['message'] ?? 'Error al registrar asistencia';
        });
      }
    } catch (error) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error de conexión: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentDate = DateFormat('dd/MM/yyyy').format(now);
    final currentTime = DateFormat('HH:mm').format(now);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Asistencia'),
      ),
      body: isLoading && employees.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Fecha y hora centradas y más grandes
                        Container(
                          alignment: Alignment.center,
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            children: [
                              Text(
                                currentDate,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                currentTime,
                                style: const TextStyle(
                                  fontSize: 36, 
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Campo para ingresar DNI
                        TextFormField(
                          controller: _dniController,
                          decoration: InputDecoration(
                            labelText: 'Ingrese su DNI *',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.badge),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: _findEmployeeByDNI,
                              tooltip: 'Buscar empleado',
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingrese su DNI';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _findEmployeeByDNI(),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Mostrar el empleado encontrado
                        if (selectedEmployee != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${selectedEmployee!.nombre} ${selectedEmployee!.apellido}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        const SizedBox(height: 24),
                        
                        // Selección de tipo de registro (Entrada/Salida)
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tipo de Registro',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: RadioListTile<bool>(
                                        title: const Text('Entrada'),
                                        value: true,
                                        groupValue: isEntryRegistration,
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              isEntryRegistration = value;
                                            });
                                          }
                                        },
                                        activeColor: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                    Expanded(
                                      child: RadioListTile<bool>(
                                        title: const Text('Salida'),
                                        value: false,
                                        groupValue: isEntryRegistration,
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              isEntryRegistration = value;
                                            });
                                          }
                                        },
                                        activeColor: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        if (statusMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            color: Colors.green.shade50,
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green),
                                const SizedBox(width: 8),
                                Expanded(child: Text(statusMessage!, style: const TextStyle(color: Colors.green))),
                              ],
                            ),
                          ),
                          
                        if (errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            color: Colors.red.shade50,
                            child: Row(
                              children: [
                                const Icon(Icons.error, color: Colors.red),
                                const SizedBox(width: 8),
                                Expanded(child: Text(errorMessage!, style: const TextStyle(color: Colors.red))),
                              ],
                            ),
                          ),
                        
                        const SizedBox(height: 24),
                        
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _registerAttendance,
                            child: isLoading
                                ? const CircularProgressIndicator()
                                : Text(
                                    isEntryRegistration ? 'REGISTRAR ENTRADA' : 'REGISTRAR SALIDA',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}