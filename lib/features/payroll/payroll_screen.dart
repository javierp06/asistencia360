import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/widgets/custom_drawer.dart';
import '../../core/responsive/responsive.dart';
import '../../core/models/payroll.dart';
import 'widgets/payroll_list.dart';
import 'admin/create_payroll_screen.dart';
import '../../core/config/api_config.dart';
import 'package:intl/intl.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({Key? key}) : super(key: key);

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  bool isAdmin = false;
  bool isLoading = true;
  String? errorMessage;
  String? userId;
  List<Payroll> payrolls = [];
  List<Payroll> filteredPayrolls = [];
  int currentPage = 1;
  int itemsPerPage = 10;
  String searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _fetchUserInfo().then((_) {
      _fetchPayrolls();
    });
  }
  
  Future<void> _fetchUserInfo() async {
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      final userRole = await storage.read(key: 'userRole');
          final empleadoId = await storage.read(key: 'empleadoId'); // Añadir esta línea

      if (userRole != null) {
        setState(() {
          isAdmin = userRole == 'admin';
           userId = empleadoId;
        });
      }
      
      final response = await http.get(
        Uri.parse('https://timecontrol-backend.onrender.com/empleados'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        setState(() {   
          userId = userData['id'].toString();
          if (userData['rol'] != null) {
            isAdmin = userData['rol'] == 'admin';
          }
        });
      }
    } catch (e) {
    }
  }
  
  Future<void> _fetchPayrolls() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      
      // URL para administrador o empleado
      final url = isAdmin 
          ? Uri.parse(ApiConfig.nominasEndpoint)
          : Uri.parse(ApiConfig.nominasEmpleado(userId!));
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> nominasData = responseData['nominas'] ?? [];
        
        final loadedPayrolls = nominasData
            .map((data) => Payroll.fromJson(data))
            .toList();
            
        // Ordenar por fecha, más reciente primero
        loadedPayrolls.sort((a, b) => b.fechaGeneracion.compareTo(a.fechaGeneracion));
        
        setState(() {
          payrolls = loadedPayrolls;
          filteredPayrolls = loadedPayrolls;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Error al cargar nóminas: ${response.statusCode}';
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
  
  void _filterPayrolls(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredPayrolls = List.from(payrolls);
      } else {
        filteredPayrolls = payrolls
            .where((payroll) =>
                payroll.empleadoNombre.toLowerCase().contains(query.toLowerCase()) ||
                payroll.periodo.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
      currentPage = 1; // Resetear a primera página al filtrar
    });
  }
  
  List<Payroll> get _paginatedPayrolls {
    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage > filteredPayrolls.length 
        ? filteredPayrolls.length 
        : startIndex + itemsPerPage;
    
    if (startIndex >= filteredPayrolls.length) {
      return [];
    }
    
    return filteredPayrolls.sublist(startIndex, endIndex);
  }
  
  @override
  Widget build(BuildContext context) {
    final isWideScreen = Responsive.isDesktop(context) || Responsive.isTablet(context);
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Nóminas'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPayrolls,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      drawer: CustomDrawer(isAdmin: isAdmin),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: theme.brightness == Brightness.dark
                ? [Colors.grey.shade900, Colors.grey.shade800]
                : [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            // Panel de resumen de nómina (solo para administradores)
            if (isAdmin)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
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
                    _buildSummaryStat('Total Nóminas', '${payrolls.length}', Icons.description),
                    _buildSummaryStat(
                      'Este Mes', 
                      payrolls.where((p) => _isCurrentMonth(p.fechaGeneracion)).length.toString(), 
                      Icons.date_range
                    ),
                    _buildSummaryStat(
                      'Monto Total', 
                      _calculateTotalAmount(), 
                      Icons.payments
                    ),
                  ],
                ),
              ),
            
            // Buscador mejorado (solo administradores)
            if (isAdmin)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: _filterPayrolls,
                    decoration: InputDecoration(
                      hintText: 'Buscar por empleado o período...',
                      prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _filterPayrolls(''),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
              
            // Lista de nóminas con estilo mejorado
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage != null
                      ? _buildErrorView()
                      : filteredPayrolls.isEmpty
                          ? _buildEmptyView()
                          : Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: PayrollList(
                                payrolls: _paginatedPayrolls,
                                isAdmin: isAdmin,
                              ),
                            ),
            ),
            
            // Paginación con mejor estilo
            if (filteredPayrolls.isNotEmpty && filteredPayrolls.length > itemsPerPage)
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Anterior'),
                      onPressed: currentPage > 1
                          ? () => setState(() => currentPage--)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5)),
                      ),
                      child: Text(
                        'Página $currentPage de ${(filteredPayrolls.length / itemsPerPage).ceil()}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Text('Siguiente'),
                      label: const Icon(Icons.arrow_forward, size: 18),
                      onPressed: currentPage < (filteredPayrolls.length / itemsPerPage).ceil()
                          ? () => setState(() => currentPage++)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _showPayrollGenerationOptions,
              icon: const Icon(Icons.add),
              label: const Text('Generar Nómina'),
              tooltip: 'Crear nueva nómina',
            )
          : null,
    );
  }

  // Agregar métodos auxiliares
  Widget _buildSummaryStat(String title, String value, IconData icon) {
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

  Widget _buildErrorView() {
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
            onPressed: _fetchPayrolls,
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

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 70,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No se encontraron nóminas',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  String _calculateTotalAmount() {
    final formatter = NumberFormat.currency(locale: 'es_HN', symbol: 'L');
    final total = payrolls.fold<double>(
      0, 
      (sum, payroll) => sum + payroll.salarioNeto
    );
    return formatter.format(total);
  }

  bool _isCurrentMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  void _showPayrollGenerationOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generar Nómina'),
        content: const Text('Seleccione el modo de generación de nómina'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showCreatePayrollDialog();
            },
            child: const Text('Un empleado'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showBatchPayrollConfirmation();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('Todos los empleados'),
          ),
        ],
      ),
    );
  }

  // Método original para mostrar el diálogo de creación de nómina individual
  void _showCreatePayrollDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreatePayrollDialog(),
    ).then((success) {
      if (success == true) {
        _fetchPayrolls();
      }
    });
  }

  // Nuevo método para confirmar la generación masiva de nóminas
  void _showBatchPayrollConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Generación Masiva'),
        content: const Text(
          'Está a punto de generar nóminas para todos los empleados activos. '
          'El sistema calculará automáticamente el período correspondiente para cada empleado. '
          '¿Desea continuar?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _generateBatchPayrolls();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('CONTINUAR'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateBatchPayrolls() async {
    // Mostrar diálogo de progreso
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Generando nóminas para todos los empleados...\nEsto puede tomar un momento.'),
          ],
        ),
      ),
    );
    
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      
      if (token == null) {
        throw Exception('No se encontró token de autenticación');
      }
      
      // 1. Primero obtenemos la lista de empleados activos
      final employeesResponse = await http.get(
        Uri.parse('https://timecontrol-backend.onrender.com/empleados'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (employeesResponse.statusCode != 200) {
        throw Exception('Error al obtener empleados: ${employeesResponse.statusCode}');
      }
      
      final List<dynamic> employeesData = json.decode(employeesResponse.body);
      final activeEmployees = employeesData
          .where((emp) => emp['activo'] == true || emp['activo'] == 1)
          .toList();
      
      if (activeEmployees.isEmpty) {
        setState(() {
          isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay empleados activos para generar nóminas')),
        );
        return;
      }
      
      // 2. Hacer la petición al endpoint de generación masiva
      final response = await http.post(
        Uri.parse('https://timecontrol-backend.onrender.com/nominas/batch'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        // No necesitamos enviar los IDs porque el backend puede obtener todos los empleados activos
      );
      
      // Al terminar, cerrar el diálogo de progreso
      Navigator.of(context).pop();
      
      setState(() {
        isLoading = false;
      });
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final int totalGenerated = responseData['generated'] ?? 0;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Se generaron $totalGenerated nóminas correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refrescar la lista de nóminas
        _fetchPayrolls();
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Error desconocido');
      }
    } catch (error) {
      // Cerrar el diálogo de progreso antes de mostrar error
      Navigator.of(context).pop();
      
      setState(() {
        isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}