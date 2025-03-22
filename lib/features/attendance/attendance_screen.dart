import 'package:flutter/material.dart';
import 'package:asistencia360/features/attendance/admin_attendance_register.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'widgets/personal_attendance_history.dart';
import '../../core/widgets/custom_drawer.dart';
import '../../core/models/employee.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({Key? key}) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool isAdmin = true; // Will be updated in initState
  Employee? selectedEmployee;
  List<Employee> employees = [];
  List<Employee> filteredEmployees = [];
  bool isLoading = true;
  String? errorMessage;
  TextEditingController searchController = TextEditingController();
  String? userId; // To store current user's ID

  @override
  void initState() {
    super.initState();
    
    // First fetch user info to determine the role and get userId
    _fetchUserInfo().then((_) {
      // Then check if we're viewing in personal mode
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        if (args != null && args['viewType'] == 'personal') {
          setState(() {
            isAdmin = false;
          });
        }
        
        // Only fetch employees if admin
        if (isAdmin) {
          _fetchEmployees();
        }
      });
    });
    
    // Add listener for search
    searchController.addListener(() {
      _filterEmployees(searchController.text);
    });
  }
  
  // Add method to fetch current user info
  Future<void> _fetchUserInfo() async {
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      final userRole = await storage.read(key: 'userRole');
          final id = await storage.read(key: 'empleadoId'); // Cambiar userId por empleadoId

      // Set isAdmin based on stored role
      if (userRole != null) {
        setState(() {
          isAdmin = userRole == 'admin';
          userId = id;
        });
      }
      
     
    } catch (e) {

    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _filterEmployees(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredEmployees = List.from(employees);
      } else {
        filteredEmployees = employees
            .where((employee) =>
                '${employee.nombre} ${employee.apellido}'
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                employee.dni.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _fetchEmployees() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
      
      final storage = FlutterSecureStorage();
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
          filteredEmployees = loadedEmployees;
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

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 600;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin
            ? selectedEmployee != null
                ? 'Asistencia: ${selectedEmployee!.nombre}'
                : 'Gestión de Asistencia'
            : 'Mi Registro de Asistencia'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (selectedEmployee == null) {
                _fetchEmployees();
              }
            },
            tooltip: 'Actualizar',
          ),
        ],
      ),
      drawer: CustomDrawer(isAdmin: isAdmin),
      body: isAdmin
          ? _buildAdminView(isWideScreen)
          : _buildEmployeeView(isWideScreen),
      floatingActionButton: isAdmin
        ? FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminAttendanceRegister()),
              );
            },
            label: const Text('Registrar Asistencia'),
            icon: const Icon(Icons.add),
            elevation: 4,
            backgroundColor: Theme.of(context).colorScheme.primary,
          )
        : null,
    );
  }

  Widget _buildAdminView(bool isWideScreen) {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Cargando datos...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 70,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage!, 
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchEmployees,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (selectedEmployee == null) {
      // Mostrar lista de empleados para seleccionar
      return _buildEmployeeSelector();
    } else {
      // Mostrar detalles del empleado seleccionado
      return Column(
        children: [
          // Barra superior mejorada con información del empleado
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      selectedEmployee = null;
                    });
                  },
                  tooltip: 'Volver a la lista',
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  child: Text(
                    selectedEmployee!.nombre.isNotEmpty ? selectedEmployee!.nombre[0] : '?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${selectedEmployee!.nombre} ${selectedEmployee!.apellido}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'DNI: ${selectedEmployee!.dni} • ${selectedEmployee!.rol}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Mostrar el historial de asistencia del empleado
          Expanded(
            child: PersonalAttendanceHistory(
              employeeName: '${selectedEmployee!.nombre} ${selectedEmployee!.apellido}',
              employeeId: selectedEmployee!.id.toString(),
              isAdmin: true,
            ),
          ),
        ],
      );
    }
  }

  Widget _buildEmployeeSelector() {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título de sección con estilo mejorado
          Container(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                Icon(
                  Icons.people_alt,
                  color: theme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  'Seleccione un Empleado',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          
          // Estadísticas rápidas
          Container(
            margin: const EdgeInsets.only(bottom: 20.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.7),
                  theme.colorScheme.primary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickStat('Total Empleados', '${employees.length}', Icons.people),
                _buildQuickStat('Presentes Hoy', '${employees.length - 2}', Icons.check_circle),
                _buildQuickStat('Ausentes Hoy', '2', Icons.cancel),
              ],
            ),
          ),
          
          // Buscador mejorado
          Container(
            margin: const EdgeInsets.only(bottom: 20.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                hintText: 'Buscar por nombre o DNI...',
                prefixIcon: Icon(
                  Icons.search,
                  color: theme.colorScheme.primary,
                ),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          _filterEmployees('');
                        },
                      )
                    : null,
                border: InputBorder.none,
              ),
            ),
          ),
          
          // Lista de empleados con diseño mejorado
          Expanded(
            child: filteredEmployees.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No se encontraron empleados',
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredEmployees.length,
                    itemBuilder: (context, index) {
                      final employee = filteredEmployees[index];
                      return _buildEmployeeCard(employee);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeView(bool isWideScreen) {
    // Add loading state for employee view
    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: PersonalAttendanceHistory(
        employeeId: userId,
        isAdmin: false, // Asegurar que empleados no pueden editar
      ),
    );
  }
  
  Widget _buildEmployeeCard(Employee employee) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.primary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            selectedEmployee = employee;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Avatar circular del empleado
              CircleAvatar(
                radius: 26,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                child: Text(
                  employee.nombre.isNotEmpty ? employee.nombre[0] : '?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Información del empleado
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${employee.nombre} ${employee.apellido}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'DNI: ${employee.dni}',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cargo: ${employee.rol}',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              // Ícono para indicar que es seleccionable
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.primary.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Añadir esta función auxiliar para las estadísticas
  Widget _buildQuickStat(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      ],
    );
  }
}