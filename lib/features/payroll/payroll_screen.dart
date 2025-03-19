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
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nóminas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPayrolls,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      drawer: CustomDrawer(isAdmin: isAdmin),
      body: Column(
        children: [
          // Búsqueda (solo para administradores)
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar por nombre o período',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: _filterPayrolls,
              ),
            ),
          
          // Contenido principal
          Expanded(
            child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchPayrolls,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  )
                : filteredPayrolls.isEmpty
                  ? const Center(child: Text('No hay nóminas disponibles'))
                  : PayrollList(
                      payrolls: _paginatedPayrolls,
                      isAdmin: isAdmin,
                    ),
          ),
          
          // Paginación
          if (filteredPayrolls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: currentPage > 1
                        ? () => setState(() => currentPage--)
                        : null,
                  ),
                  Text('Página $currentPage de ${(filteredPayrolls.length / itemsPerPage).ceil()}'),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: currentPage < (filteredPayrolls.length / itemsPerPage).ceil()
                        ? () => setState(() => currentPage++)
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await showDialog(
                  context: context,
                  builder: (context) => const CreatePayrollDialog(),
                );
                
                // Si el resultado es true (nómina creada con éxito), actualizamos la lista
                if (result == true) {
                  _fetchPayrolls();
                }
              },
              label: const Text('Nueva Nómina'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }
}