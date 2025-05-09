import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/models/employee.dart';
import '../../core/widgets/custom_data_table.dart';
import '../../core/widgets/search_bar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/widgets/custom_drawer.dart';
import 'package:flutter/services.dart';
import 'package:asistencia360/core/config/api_config.dart';
import 'package:asistencia360/core/models/deduccion.dart';

// Modifica la definición de clase para incluir el empleadoId
class EmployeeList extends StatefulWidget {
  final String? empleadoId; // Añadir este parámetro

  const EmployeeList({super.key, this.empleadoId});

  @override
  State<EmployeeList> createState() => _EmployeeListState();
}

class _EmployeeListState extends State<EmployeeList> {
  final List<String> _rolesDisponibles = [
    'conductor',
    'guia',
    'ayudante',
    'supervisor',
    'admin',
  ];
  List<Employee> employees = [];
  List<Employee> filteredEmployees = [];
  List<EmpleadoDeduccion> empleadoDeducciones = [];
  List<Deduccion> todasLasDeducciones = [];
  bool _isLoading = true;
  String? _token;
  String? selectedEmployeeId;

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidoController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _dniController = TextEditingController();
  final TextEditingController _telefonoEmergenciaController =
      TextEditingController();
  final TextEditingController _salarioController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _rolController = TextEditingController();
  DateTime _fechaContratacion = DateTime.now();
  String _sexoSeleccionado = 'Masculino';
  String _rolSeleccionado = 'ayudante';
  @override
  void initState() {
    super.initState();
    _getTokenAndFetchEmployees();
  }

  Future<void> _getTokenAndFetchEmployees() async {
    final storage = const FlutterSecureStorage();
    _token = await storage.read(key: 'token');
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final storage = const FlutterSecureStorage();
      _token = await storage.read(key: 'token');

      if (_token == null) {
        // Token missing, navigate to login
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sesión expirada, por favor inicie sesión nuevamente',
            ),
          ),
        );
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
      final response = await http.get(
        Uri.parse('https://timecontrol-backend.onrender.com/empleados'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token', // Make sure to include the token
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isEmpty) {
          setState(() {
            _isLoading = false;
            filteredEmployees = [];
          });
          return;
        }
        setState(() {
          employees = data.map((json) => Employee.fromJson(json)).toList();
          filteredEmployees = employees;
          _isLoading = false;
        });
      } else {
        // Handle error response
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.statusCode}')),
        );
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de conexión: $error')));
    }
  }

  void _filterEmployees(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredEmployees = [...employees];
      } else {
        filteredEmployees =
            employees
                .where(
                  (employee) =>
                      employee.name.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      employee.rol.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
      }
    });
  }

  void _showAddEmployeeDialog() {
    // Reset form fields
    _nombreController.clear();
    _apellidoController.clear();
    _telefonoController.clear();
    _dniController.clear();
    _telefonoEmergenciaController.clear();
    _emailController.clear();
    _rolController.clear();
    _salarioController.clear();
    _fechaContratacion = DateTime.now();
    _sexoSeleccionado = 'Masculino';
    _rolSeleccionado = 'ayudante';

    // Create a form key for validation
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
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
                  color:
                      Theme.of(context).dialogTheme.backgroundColor ??
                      Theme.of(context).colorScheme.surface,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.black54
                              : Colors.black26,
                      blurRadius: 10.0,
                      offset: const Offset(0.0, 10.0),
                    ),
                  ],
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withAlpha(26),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.person_add,
                                color: Theme.of(context).primaryColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Añadir Empleado',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Sección de información personal
                        _buildSectionTitle(
                          'Información Personal',
                          Icons.person,
                        ),
                        const SizedBox(height: 8),

                        // Name field with validation and input formatter (only letters)
                        _buildValidatedTextField(
                          _nombreController,
                          'Nombre',
                          Icons.badge,
                          TextInputType.name,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚüÜñÑ\s]'),
                            ),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El nombre es obligatorio';
                            }
                            if (!RegExp(
                              r'^[a-zA-ZáéíóúÁÉÍÓÚüÜñÑ\s]+$',
                            ).hasMatch(value)) {
                              return 'Ingrese solo letras, sin números ni caracteres especiales';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Surname field with validation and input formatter (only letters)
                        _buildValidatedTextField(
                          _apellidoController,
                          'Apellido',
                          Icons.badge_outlined,
                          TextInputType.name,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚüÜñÑ\s]'),
                            ),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El apellido es obligatorio';
                            }
                            if (!RegExp(
                              r'^[a-zA-ZáéíóúÁÉÍÓÚüÜñÑ\s]+$',
                            ).hasMatch(value)) {
                              return 'Ingrese solo letras, sin números ni caracteres especiales';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // DNI field with validation (13 digits) and format guide
                        _buildValidatedTextField(
                          _dniController,
                          'DNI',
                          Icons.credit_card,
                          TextInputType.number,
                          hintText: 'xxxx-xxxx-xxxxx',
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(13),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El DNI es obligatorio';
                            }
                            if (value.length != 13) {
                              return 'El DNI debe tener 13 dígitos';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Dropdown para sexo con mejor estilo
                        StatefulBuilder(
                          builder: (context, setStateDropdown) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.grey.shade700
                                          : Colors.grey.shade300,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _sexoSeleccionado,
                                  icon: const Icon(Icons.arrow_drop_down),
                                  iconSize: 24,
                                  elevation: 16,
                                  hint: const Row(
                                    children: [
                                      Icon(Icons.wc, size: 20),
                                      SizedBox(width: 8),
                                      Text('Sexo'),
                                    ],
                                  ),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setStateDropdown(() {
                                        _sexoSeleccionado = newValue;
                                      });
                                      setState(() {
                                        _sexoSeleccionado = newValue;
                                      });
                                    }
                                  },
                                  items:
                                      <String>[
                                        'Masculino',
                                        'Femenino',
                                        'Otro',
                                      ].map<DropdownMenuItem<String>>((
                                        String value,
                                      ) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Row(
                                            children: [
                                              Icon(
                                                value == 'Masculino'
                                                    ? Icons.male
                                                    : value == 'Femenino'
                                                    ? Icons.female
                                                    : Icons.person,
                                                size: 20,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).primaryColor,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(value),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 20),

                        // Sección de contacto
                        _buildSectionTitle(
                          'Información de Contacto',
                          Icons.contact_phone,
                        ),
                        const SizedBox(height: 8),

                        // Phone field with validation (8 digits)
                        _buildValidatedTextField(
                          _telefonoController,
                          'Teléfono',
                          Icons.phone,
                          TextInputType.phone,
                          hintText: 'xxxx-xxxx',
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(8),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El teléfono es obligatorio';
                            }
                            if (value.length != 8) {
                              return 'El teléfono debe tener 8 dígitos';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Emergency phone field with validation (8 digits)
                        _buildValidatedTextField(
                          _telefonoEmergenciaController,
                          'Teléfono de Emergencia',
                          Icons.emergency,
                          TextInputType.phone,
                          hintText: 'xxxx-xxxx',
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(8),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El teléfono de emergencia es obligatorio';
                            }
                            if (value.length != 8) {
                              return 'El teléfono debe tener 8 dígitos';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Email field with validation
                        _buildValidatedTextField(
                          _emailController,
                          'Correo Electrónico',
                          Icons.email,
                          TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El correo electrónico es obligatorio';
                            }
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(value)) {
                              return 'Ingrese un correo electrónico válido';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Sección laboral - Keep your existing role dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade300,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _rolSeleccionado,
                              decoration: const InputDecoration(
                                labelText: 'Rol',
                                icon: Icon(Icons.assignment_ind),
                                border: InputBorder.none,
                              ),
                              items:
                                  _rolesDisponibles.map((String rol) {
                                    return DropdownMenuItem<String>(
                                      value: rol,
                                      child: Text(
                                        rol.capitalize(),
                                      ), // Convierte primera letra a mayúscula
                                    );
                                  }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _rolSeleccionado = newValue!;
                                });
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Salary field with validation and Lempiras symbol
                        _buildValidatedTextField(
                          _salarioController,
                          'Salario Base',
                          Icons.attach_money,
                          TextInputType.numberWithOptions(decimal: true),
                          prefixText: 'Lps. ',
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El salario es obligatorio';
                            }
                            final salary = double.tryParse(value);
                            if (salary == null) {
                              return 'Ingrese un valor válido';
                            }
                            if (salary <= 1) {
                              return 'El salario debe ser mayor a 1 lempira';
                            }
                            return null;
                          },
                        ),

                        // Keep your existing date picker
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _fechaContratacion,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: Theme.of(context).primaryColor,
                                      onPrimary: Colors.white,
                                      onSurface:
                                          Theme.of(
                                            context,
                                          ).textTheme.bodyLarge!.color!,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null &&
                                picked != _fechaContratacion) {
                              setState(() {
                                _fechaContratacion = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  // Añadir Expanded aquí para controlar el overflow
                                  child: Text(
                                    'Fecha de contratación: ${DateFormat('dd/MM/yyyy').format(_fechaContratacion)}',
                                    style: const TextStyle(fontSize: 16),
                                    overflow:
                                        TextOverflow.ellipsis, // Añadir overflow
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Botones con mejor estilo
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('CANCELAR'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                // Validate the form first
                                if (formKey.currentState!.validate()) {
                                  _saveEmployee();
                                  Navigator.of(context).pop();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Theme.of(context).primaryColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.save, size: 20),
                                  SizedBox(width: 8),
                                  Text('GUARDAR'),
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
          ),
    );
  }

  // Widget para construir los títulos de sección
  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Expanded(
            // Add this to constrain the text width
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
              overflow: TextOverflow.ellipsis, // Handle overflow with ellipsis
            ),
          ),
        ],
      ),
    );
  }

  // Widget para construir campos de texto consistentes
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    TextInputType inputType,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TextField(
      controller: controller,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: theme.primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            // Usar un color que se adapte al tema
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
      ),
    );
  }

  Widget _buildValidatedTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    TextInputType keyboardType, {
    String? Function(String?)? validator,
    bool obscureText = false,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    String? prefixText,
    String? hintText,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: theme.primaryColor),
        prefixText: prefixText,
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.primaryColor.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
      ),
      keyboardType: keyboardType,
      validator: validator,
      obscureText: obscureText,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
    );
  }

  Future<void> _saveEmployee() async {
    try {
      final url = Uri.parse(
        'https://timecontrol-backend.onrender.com/empleados',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode({
          'nombre': _nombreController.text,
          'apellido': _apellidoController.text,
          'telefono': _telefonoController.text,
          'dni': _dniController.text,
          'telefono_emergencia': _telefonoEmergenciaController.text,
          'sexo': _sexoSeleccionado,
          'email': _emailController.text,
          'rol': _rolSeleccionado,
          'id_horario': 1,
          'fecha_contratacion': DateFormat(
            'yyyy-MM-dd',
          ).format(_fechaContratacion),
          'salario': double.tryParse(_salarioController.text) ?? 0.0,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success
        final responseData = json.decode(response.body);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Empleado añadido correctamente')),
        );

        // Refresh employee list
        _fetchEmployees();
      } else {
        // Handle error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.statusCode}')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de conexión: $error')));
    }
  }

  Future<void> _updateEmployee(String employeeId) async {
    try {
      final url = Uri.parse(
        'https://timecontrol-backend.onrender.com/empleados/$employeeId',
      );

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode({
          'nombre': _nombreController.text,
          'apellido': _apellidoController.text,
          'telefono': _telefonoController.text,
          'dni': _dniController.text,
          'telefono_emergencia': _telefonoEmergenciaController.text,
          'sexo': _sexoSeleccionado,
          'email': _emailController.text,
          'id_horario': 1,
          'fecha_contratacion': DateFormat(
            'yyyy-MM-dd',
          ).format(_fechaContratacion),
          'salario': double.tryParse(_salarioController.text) ?? 0.0,
        }),
      );

      if (response.statusCode == 200) {
        // Success
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Empleado actualizado correctamente')),
        );

        // Refresh employee list
        _fetchEmployees();
      } else {
        // Handle error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.statusCode}')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de conexión: $error')));
    }
  }

  void _showEditEmployeeDialog(Employee employee) {
    // Pre-fill form fields with employee data
    _nombreController.text = employee.nombre;
    _apellidoController.text = employee.apellido;
    _telefonoController.text = employee.telefono;
    _dniController.text = employee.dni;
    _telefonoEmergenciaController.text = employee.telefonoEmergencia;
    _emailController.text = employee.email;
    _salarioController.text = employee.salario.toString();
    _fechaContratacion = employee.fechaContratacion;
    _sexoSeleccionado = employee.sexo;

    // Create a form key for validation
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
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
                  color:
                      Theme.of(context).dialogTheme.backgroundColor ??
                      Theme.of(context).colorScheme.surface,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.black54
                              : Colors.black26,
                      blurRadius: 10.0,
                      offset: const Offset(0.0, 10.0),
                    ),
                  ],
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withAlpha(26),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.edit_note,
                                color: Theme.of(context).primaryColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Editar Empleado',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Sección de información personal
                        _buildSectionTitle(
                          'Información Personal',
                          Icons.person,
                        ),
                        const SizedBox(height: 8),

                        // Name field with validation and input formatter (only letters)
                        _buildValidatedTextField(
                          _nombreController,
                          'Nombre',
                          Icons.badge,
                          TextInputType.name,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚüÜñÑ\s]'),
                            ),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El nombre es obligatorio';
                            }
                            if (!RegExp(
                              r'^[a-zA-ZáéíóúÁÉÍÓÚüÜñÑ\s]+$',
                            ).hasMatch(value)) {
                              return 'Ingrese solo letras, sin números ni caracteres especiales';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Surname field with validation and input formatter (only letters)
                        _buildValidatedTextField(
                          _apellidoController,
                          'Apellido',
                          Icons.badge_outlined,
                          TextInputType.name,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚüÜñÑ\s]'),
                            ),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El apellido es obligatorio';
                            }
                            if (!RegExp(
                              r'^[a-zA-ZáéíóúÁÉÍÓÚüÜñÑ\s]+$',
                            ).hasMatch(value)) {
                              return 'Ingrese solo letras, sin números ni caracteres especiales';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // DNI field with validation (13 digits) and format guide
                        _buildValidatedTextField(
                          _dniController,
                          'DNI',
                          Icons.credit_card,
                          TextInputType.number,
                          hintText: 'xxxx-xxxx-xxxxx',
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(13),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El DNI es obligatorio';
                            }
                            if (value.length != 13) {
                              return 'El DNI debe tener 13 dígitos';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Dropdown para sexo con mejor estilo
                        StatefulBuilder(
                          builder: (context, setStateDropdown) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.grey.shade700
                                          : Colors.grey.shade300,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _sexoSeleccionado,
                                  icon: const Icon(Icons.arrow_drop_down),
                                  iconSize: 24,
                                  elevation: 16,
                                  hint: const Row(
                                    children: [
                                      Icon(Icons.wc, size: 20),
                                      SizedBox(width: 8),
                                      Text('Sexo'),
                                    ],
                                  ),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setStateDropdown(() {
                                        _sexoSeleccionado = newValue;
                                      });
                                      setState(() {
                                        _sexoSeleccionado = newValue;
                                      });
                                    }
                                  },
                                  items:
                                      <String>[
                                        'Masculino',
                                        'Femenino',
                                        'Otro',
                                      ].map<DropdownMenuItem<String>>((
                                        String value,
                                      ) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Row(
                                            children: [
                                              Icon(
                                                value == 'Masculino'
                                                    ? Icons.male
                                                    : value == 'Femenino'
                                                    ? Icons.female
                                                    : Icons.person,
                                                size: 20,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).primaryColor,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(value),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 20),

                        // Sección de contacto
                        _buildSectionTitle(
                          'Información de Contacto',
                          Icons.contact_phone,
                        ),
                        const SizedBox(height: 8),

                        // Phone field with validation (8 digits)
                        _buildValidatedTextField(
                          _telefonoController,
                          'Teléfono',
                          Icons.phone,
                          TextInputType.phone,
                          hintText: 'xxxx-xxxx',
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(8),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El teléfono es obligatorio';
                            }
                            if (value.length != 8) {
                              return 'El teléfono debe tener 8 dígitos';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Emergency phone field with validation (8 digits)
                        _buildValidatedTextField(
                          _telefonoEmergenciaController,
                          'Teléfono de Emergencia',
                          Icons.emergency,
                          TextInputType.phone,
                          hintText: 'xxxx-xxxx',
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(8),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El teléfono de emergencia es obligatorio';
                            }
                            if (value.length != 8) {
                              return 'El teléfono debe tener 8 dígitos';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Email field with validation
                        _buildValidatedTextField(
                          _emailController,
                          'Correo Electrónico',
                          Icons.email,
                          TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El correo electrónico es obligatorio';
                            }
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(value)) {
                              return 'Ingrese un correo electrónico válido';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Sección laboral - Keep your existing role dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade300,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _rolSeleccionado,
                              decoration: const InputDecoration(
                                labelText: 'Rol',
                                icon: Icon(Icons.assignment_ind),
                                border: InputBorder.none,
                              ),
                              items:
                                  _rolesDisponibles.map((String rol) {
                                    return DropdownMenuItem<String>(
                                      value: rol,
                                      child: Text(
                                        rol.capitalize(),
                                      ), // Convierte primera letra a mayúscula
                                    );
                                  }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _rolSeleccionado = newValue!;
                                });
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Salary field with validation and Lempiras symbol
                        _buildValidatedTextField(
                          _salarioController,
                          'Salario Base',
                          Icons.attach_money,
                          TextInputType.numberWithOptions(decimal: true),
                          prefixText: 'Lps. ',
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El salario es obligatorio';
                            }
                            final salary = double.tryParse(value);
                            if (salary == null) {
                              return 'Ingrese un valor válido';
                            }
                            if (salary <= 1) {
                              return 'El salario debe ser mayor a 1 lempira';
                            }
                            return null;
                          },
                        ),

                        // Keep your existing date picker
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _fechaContratacion,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: Theme.of(context).primaryColor,
                                      onPrimary: Colors.white,
                                      onSurface:
                                          Theme.of(
                                            context,
                                          ).textTheme.bodyLarge!.color!,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null &&
                                picked != _fechaContratacion) {
                              setState(() {
                                _fechaContratacion = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  // Añadir Expanded aquí para controlar el overflow
                                  child: Text(
                                    'Fecha de contratación: ${DateFormat('dd/MM/yyyy').format(_fechaContratacion)}',
                                    style: const TextStyle(fontSize: 16),
                                    overflow:
                                        TextOverflow.ellipsis, // Añadir overflow
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Botones con mejor estilo
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('CANCELAR'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                // Validate the form first
                                if (formKey.currentState!.validate()) {
                                  _updateEmployee(employee.id);
                                  Navigator.of(context).pop();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Theme.of(context).primaryColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.save, size: 20),
                                  SizedBox(width: 8),
                                  Text('GUARDAR'),
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
          ),
    );
  }

  void _showDeleteConfirmation(Employee employee) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar Desactivación'),
            content: Text(
              '¿Está seguro que desea desactivar a ${employee.name}?\nEsto inhabilitará su acceso al sistema pero mantendrá sus datos históricos.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CANCELAR'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () {
                  _deleteEmployee(employee.id);
                  Navigator.of(context).pop();
                },
                child: const Text('DESACTIVAR'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteEmployee(String id_empleado) async {
    try {
      final url = Uri.parse(
        'https://timecontrol-backend.onrender.com/empleados/$id_empleado',
      );

      // Instead of deleting, update the 'activo' field to false
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'activo': false}),
      );

      if (response.statusCode == 200) {
        // Success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Empleado desactivado correctamente')),
        );

        // Refresh employee list
        _fetchEmployees();
      } else {
        // Handle error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.statusCode}')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de conexión: $error')));
    }
  }

  Future<void> _toggleEmployeeStatus(Employee employee) async {
    try {
      final url = Uri.parse(
        'https://timecontrol-backend.onrender.com/empleados/${employee.id}',
      );

      // Toggle the active status
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'activo': !employee.activo}),
      );

      if (response.statusCode == 200) {
        // Success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              employee.activo
                  ? 'Empleado desactivado correctamente'
                  : 'Empleado activado correctamente',
            ),
          ),
        );

        // Refresh employee list
        _fetchEmployees();
      } else {
        // Handle error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.statusCode}')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de conexión: $error')));
    }
  }

  void _showStatusChangeConfirmation(Employee employee) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              employee.activo
                  ? 'Confirmar Desactivación'
                  : 'Confirmar Activación',
            ),
            content: Text(
              employee.activo
                  ? '¿Está seguro que desea desactivar a ${employee.name}?\nEsto inhabilitará su acceso al sistema.'
                  : '¿Está seguro que desea activar a ${employee.name}?\nEsto permitirá nuevamente su acceso al sistema.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CANCELAR'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      employee.activo ? Colors.orange : Colors.green,
                ),
                onPressed: () {
                  _toggleEmployeeStatus(employee);
                  Navigator.of(context).pop();
                },
                child: Text(employee.activo ? 'DESACTIVAR' : 'ACTIVAR'),
              ),
            ],
          ),
    );
  }

  Future<void> _fetchDeduccionesEmpleado() async {
    if (selectedEmployeeId == null) return;
    
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/deducciones/empleado/$selectedEmployeeId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          empleadoDeducciones = data.map((json) => EmpleadoDeduccion.fromJson(json)).toList();
        });
      }
    } catch (error) {
      // Manejo del error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar deducciones: $error')),
        );
      }
    }
  }

  Future<void> _fetchDeducciones() async {
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/deducciones'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          todasLasDeducciones = data.map((json) => Deduccion.fromJson(json)).toList();
        });
      }
    } catch (error) {
      // Manejo del error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar deducciones: $error')),
        );
      }
    }
  }

  void _mostrarDialogoAsignarDeduccion() {
    if (selectedEmployeeId == null) return;
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Obtener deducciones que no están asignadas
    final deduccionesDisponibles = todasLasDeducciones.where((d) {
      return !empleadoDeducciones.any((ed) => 
        ed.deduccionId == d.id && ed.activo);
    }).toList();
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.secondary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Asignar Deducción',
                      style: TextStyle(
                        color: colorScheme.onSecondary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Seleccione una deducción para asignar al empleado',
                      style: TextStyle(
                        color: colorScheme.onSecondary.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Contenido principal
              Expanded(
                child: deduccionesDisponibles.isEmpty 
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_late_outlined,
                              size: 64,
                              color: colorScheme.secondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No hay más deducciones disponibles para asignar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Puede crear una nueva deducción usando el botón de abajo',
                              style: TextStyle(
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: deduccionesDisponibles.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final deduccion = deduccionesDisponibles[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: InkWell(
                            onTap: () => _asignarDeduccion(deduccion.id),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: colorScheme.secondary.withOpacity(0.1),
                                    child: Text(
                                      '${deduccion.porcentaje.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.secondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          deduccion.nombre,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (deduccion.descripcion != null && deduccion.descripcion!.isNotEmpty)
                                          Text(
                                            deduccion.descripcion!,
                                            style: TextStyle(
                                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.add_circle_outline,
                                    color: colorScheme.secondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              ),
              
              // Barra de acciones
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  border: Border(
                    top: BorderSide(color: theme.dividerColor),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('VOLVER'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_circle),
                      label: const Text('CREAR NUEVA'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.secondary,
                        foregroundColor: colorScheme.onSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _mostrarDialogoCrearDeduccion();
                      },
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

  void _mostrarDialogoDeduccionesEmpleado(Employee employee) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    setState(() {
      selectedEmployeeId = employee.id;
    });
    
    // Fetch deductions when dialog opens
    _fetchDeduccionesEmpleado();
    _fetchDeducciones();
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with employee information
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.percent_rounded, color: colorScheme.onPrimary),
                        const SizedBox(width: 8),
                        Text(
                          'Deducciones de Nómina',
                          style: TextStyle(
                            color: colorScheme.onPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      employee.name,
                      style: TextStyle(
                        color: colorScheme.onPrimary.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Salario: ${NumberFormat.currency(symbol: 'L ', decimalDigits: 2).format(employee.salario)}',
                      style: TextStyle(
                        color: colorScheme.onPrimary.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Main content
              Expanded(
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Current deductions section
                          Row(
                            children: [
                              Icon(Icons.list_alt, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Deducciones Asignadas',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 8),
                          const Divider(),
                          
                          Expanded(
                            child: empleadoDeducciones.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          size: 48,
                                          color: colorScheme.primary.withOpacity(0.5),
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'No hay deducciones asignadas',
                                          style: TextStyle(
                                            fontSize: 16,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton.icon(
                                          onPressed: _mostrarDialogoAsignarDeduccion,
                                          icon: const Icon(Icons.add_circle_outline),
                                          label: const Text('Asignar Deducción'),
                                          style: ElevatedButton.styleFrom(
                                            foregroundColor: colorScheme.onPrimary,
                                            backgroundColor: colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: empleadoDeducciones.length,
                                    separatorBuilder: (context, index) => const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final empDeduccion = empleadoDeducciones[index];
                                      if (!empDeduccion.activo) return const SizedBox.shrink();
                                      
                                      final deduccion = empDeduccion.deduccion;
                                      final montoMensual = employee.salario * (deduccion.porcentaje / 100);
                                      
                                      return Card(
                                        elevation: 1,
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          leading: Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary.withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${deduccion.porcentaje.toStringAsFixed(1)}%',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            deduccion.nombre,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (deduccion.descripcion != null && deduccion.descripcion!.isNotEmpty)
                                                Text(deduccion.descripcion!),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Monto: ${NumberFormat.currency(symbol: 'L ', decimalDigits: 2).format(montoMensual)}/mes',
                                                style: TextStyle(
                                                  color: colorScheme.error,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                                            onPressed: () => _confirmarDesactivarDeduccion(empDeduccion),
                                            tooltip: 'Eliminar deducción',
                                          ),
                                          isThreeLine: deduccion.descripcion != null && deduccion.descripcion!.isNotEmpty,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Loading indicator
                    if (_isLoading)
                      Container(
                        color: Colors.black26,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Action bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  border: Border(
                    top: BorderSide(color: theme.dividerColor),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('CERRAR'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('ASIGNAR NUEVA'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: _mostrarDialogoAsignarDeduccion,
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

  Future<void> _asignarDeduccion(String deduccionId) async {
    if (selectedEmployeeId == null) return;
    
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/deducciones/asignar'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'id_empleado': selectedEmployeeId,
          'id_deduccion': deduccionId,
        }),
      );
      
      if (mounted) {
        if (response.statusCode == 201 || response.statusCode == 200) {
          Navigator.pop(context); // Cerrar diálogo
          _fetchDeduccionesEmpleado(); // Actualizar lista
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deducción asignada exitosamente')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response.body}')),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    }
  }

  Future<void> _desactivarDeduccion(String id) async {
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/deducciones/desactivar/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (mounted) {
        if (response.statusCode == 200) {
          Navigator.pop(context); // Cerrar diálogo actual
          _fetchDeduccionesEmpleado(); // Actualizar lista
          _mostrarDialogoDeduccionesEmpleado(
            employees.firstWhere((e) => e.id == selectedEmployeeId)
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deducción desactivada exitosamente')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response.body}')),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    }
  }

  void _mostrarDialogoCrearDeduccion() {
    final TextEditingController nombreController = TextEditingController();
    final TextEditingController descripcionController = TextEditingController();
    final TextEditingController porcentajeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear Nueva Deducción'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej: Seguro Médico, Préstamo, etc.',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El nombre es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: porcentajeController,
                decoration: const InputDecoration(
                  labelText: 'Porcentaje',
                  suffixText: '%',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El porcentaje es obligatorio';
                  }
                  try {
                    final porcentaje = double.parse(value);
                    if (porcentaje <= 0 || porcentaje > 100) {
                      return 'El porcentaje debe estar entre 0 y 100';
                    }
                  } catch (e) {
                    return 'Ingrese un número válido';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                _crearDeduccion(
                  nombreController.text,
                  descripcionController.text,
                  double.tryParse(porcentajeController.text) ?? 0.0,
                );
              }
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  Future<void> _crearDeduccion(String nombre, String descripcion, double porcentaje) async {
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/deducciones'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'nombre': nombre,
          'descripcion': descripcion,
          'porcentaje': porcentaje,
        }),
      );
      
      if (mounted) {
        if (response.statusCode == 201) {
          Navigator.pop(context); // Cerrar diálogo
          
          // Actualizar la lista de deducciones
          await _fetchDeducciones();
          
          // Mostrar el diálogo para asignar la deducción recién creada
          _mostrarDialogoAsignarDeduccion();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deducción creada exitosamente')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response.statusCode}')),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    }
  }

  void _confirmarDesactivarDeduccion(EmpleadoDeduccion empDeduccion) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Está seguro que desea eliminar la siguiente deducción?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    empDeduccion.deduccion.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text('Porcentaje: ${empDeduccion.deduccion.porcentaje}%'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete),
            label: const Text('ELIMINAR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _desactivarDeduccion(empDeduccion.id);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Empleados'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchEmployees,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      drawer: const CustomDrawer(isAdmin: true),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors:
                isDarkMode
                    ? [Colors.grey.shade900, Colors.grey.shade800]
                    : [Colors.blue.shade50, Colors.blue.shade100],
          ),
        ),
        child: Column(
          children: [
            // Search Bar with enhanced styling
            Container(
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 1,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: SearchWidget(onSearch: _filterEmployees),
            ),

            // Employees Table
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredEmployees.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_off,
                              size: 64,
                              color:
                                  isDarkMode
                                      ? Colors.grey
                                      : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay empleados disponibles',
                              style: TextStyle(
                                fontSize: 18,
                                color:
                                    isDarkMode
                                        ? Colors.grey
                                        : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                      : Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: CustomDataTable(
                            columns: [
                              DataColumn(
                                label: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Estado',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Nombre',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'DNI',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Email',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Teléfono',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'T. Emergencia',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Sexo',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Salario',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'F. Contratación',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Acciones',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            rows:
                                filteredEmployees
                                    .map(
                                      (employee) => DataRow(
                                        cells: [
                                          // Status Cell with visual indicator
                                          DataCell(
                                            Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  // Custom styled switch
                                                  Transform.scale(
                                                    scale: 0.8,
                                                    child: Switch.adaptive(
                                                      value: employee.activo,
                                                      activeColor: Colors.green,
                                                      activeTrackColor: Colors
                                                          .green
                                                          .withOpacity(0.4),
                                                      inactiveThumbColor:
                                                          Colors.grey,
                                                      inactiveTrackColor: Colors
                                                          .grey
                                                          .withOpacity(0.3),
                                                      onChanged: (bool value) {
                                                        if (value !=
                                                            employee.activo) {
                                                          _showStatusChangeConfirmation(
                                                            employee,
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                  // Status label below the switch
                                                  Text(
                                                    employee.activo
                                                        ? 'Activo'
                                                        : 'Inactivo',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color:
                                                          employee.activo
                                                              ? Colors.green
                                                              : Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          // Employee name cell with styling for inactive employees
                                          DataCell(
                                            Text(
                                              employee.name,
                                              style:
                                                  employee.activo
                                                      ? null
                                                      : const TextStyle(
                                                        color: Colors.grey,
                                                        decoration:
                                                            TextDecoration
                                                                .lineThrough,
                                                      ),
                                            ),
                                          ),
                                          DataCell(Text(employee.dni)),
                                          DataCell(Text(employee.email)),
                                          DataCell(Text(employee.telefono)),
                                          DataCell(
                                            Text(employee.telefonoEmergencia),
                                          ),
                                          DataCell(Text(employee.sexo)),
                                          DataCell(
                                            Text(
                                              'L${employee.salario.toStringAsFixed(2)}', // Change $ to L for Lempiras
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              DateFormat('dd/MM/yyyy').format(
                                                employee.fechaContratacion,
                                              ),
                                            ),
                                          ),
                                          // Actions cell
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Edit button with modern styling
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.edit,
                                                    color: primaryColor,
                                                  ),
                                                  onPressed:
                                                      () =>
                                                          _showEditEmployeeDialog(
                                                            employee,
                                                          ),
                                                  tooltip: 'Editar',
                                                ),                                                
                                                IconButton(
                                                  icon: const Icon(Icons.calculate),
                                                  tooltip: 'Gestionar deducciones',
                                                  onPressed: () async {
                                                    setState(() {
                                                      selectedEmployeeId = employee.id;
                                                    });
                                                    await _fetchDeducciones();
                                                    await _fetchDeduccionesEmpleado();
                                                    if (mounted) {
                                                      _mostrarDialogoDeduccionesEmpleado(employee);
                                                    }
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEmployeeDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Añadir Empleado'),
        tooltip: 'Añadir empleado',
        elevation: 4,
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
