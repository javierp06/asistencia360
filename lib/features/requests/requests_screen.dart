import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/widgets/custom_drawer.dart';
import 'widgets/request_form.dart';
import 'widgets/request_list.dart';
import 'models/request.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';  // Add this import

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({Key? key}) : super(key: key);

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;
  String? errorMessage;
  bool isAdmin = false;

  // Lista de solicitudes desde la API
  List<Request> _requests = [];
  final storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkUserRole();
    _fetchRequests();

    // Añadir listener para cargar los datos cuando cambie la pestaña
    _tabController.addListener(() {
      setState(
        () {},
      ); // Actualizar la UI para reflejar el cambio de filtro por tipo
    });
  }

  Future<void> _checkUserRole() async {
    final storage = const FlutterSecureStorage();
    final role = await storage.read(key: 'userRole');

    setState(() {
      isAdmin = role == 'admin';
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchRequests() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      final userId = await storage.read(key: 'userId');
      final empleadoId = await storage.read(key: 'empleadoId'); // Añadir esta línea

      
      if (token == null) {
        setState(() {
          errorMessage = 'No se encontró token de autenticación';
          isLoading = false;
        });
        return;
      }
      
      // Validación explícita de userId
      if (!isAdmin && (userId == null || userId.isEmpty)) {
        setState(() {
          errorMessage = 'No se pudo identificar el empleado actual';
          isLoading = false;
        });
        return;
      }

      // 1. OBTENER PERMISOS Y VACACIONES - CORREGIR LA URL
      final Uri permissionsUrl = isAdmin
          ? Uri.parse('https://timecontrol-backend.onrender.com/permisos')
          : Uri.parse('https://timecontrol-backend.onrender.com/permisos/empleado/$empleadoId');
      
      // Debug para verificar la URL

      final permissionsResponse = await http.get(
        permissionsUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      List<Request> allRequests = [];

      if (permissionsResponse.statusCode == 200) {
        final List<dynamic> permissionsData = json.decode(permissionsResponse.body);
        final permissionRequests = permissionsData.map((data) => _parseRequest(data)).toList();
        allRequests.addAll(permissionRequests);
      } else {
        throw Exception('Error al cargar permisos: ${permissionsResponse.statusCode}');
      }
      
      // 2. OBTENER INCAPACIDADES - CORREGIR LA URL
      final Uri disabilitiesUrl = isAdmin
          ? Uri.parse('https://timecontrol-backend.onrender.com/incapacidades')
          : Uri.parse('https://timecontrol-backend.onrender.com/incapacidades/empleado/$empleadoId');
      
      // Debug para verificar la URL

      final disabilitiesResponse = await http.get(
        disabilitiesUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (disabilitiesResponse.statusCode == 200) {
        final List<dynamic> disabilitiesData = json.decode(disabilitiesResponse.body);
        final disabilityRequests = disabilitiesData.map((data) => _parseDisabilityRequest(data)).toList();
        allRequests.addAll(disabilityRequests);
      } else {
        throw Exception('Error al cargar incapacidades: ${disabilitiesResponse.statusCode}');
      }
      
      // 3. ORDENAR TODAS LAS SOLICITUDES POR FECHA
      allRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _requests = allRequests;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  // Método para convertir los datos de la API a objetos Request
  Request _parseRequest(Map<String, dynamic> data) {
    // Mapear estado a RequestStatus directamente desde el campo estado
    RequestStatus status;
    switch (data['estado']) {
      case 'aprobado':
        status = RequestStatus.approved;
        break;
      case 'rechazado':
        status = RequestStatus.rejected;
        break;
      case 'pendiente':
      default:
        status = RequestStatus.pending;
    }

    // Mapear tipo de permiso a RequestType
    RequestType type;
    switch (data['tipo_permiso']?.toLowerCase()) {
      case 'vacaciones':
        type = RequestType.vacation;
        break;
      case 'incapacidad':
        type = RequestType.disability;
        break;
      default:
        type = RequestType.permission;
    }

    // Extraer información del empleado
    String? employeeName;
    String? employeeId;
    
    if (data['empleado'] != null) {
      employeeId = data['id_empleado']?.toString();
      employeeName = data['empleado']['nombre'] != null 
          ? '${data['empleado']['nombre']} ${data['empleado']['apellido'] ?? ''}' 
          : 'Empleado #${data['id_empleado']}';
    }

    return Request(
      id: data['id_permiso']?.toString() ?? '',
      type: type,
      status: status,
      startDate:
          data['fecha_inicio'] != null
              ? DateTime.parse(data['fecha_inicio'])
              : DateTime.now(),
      endDate:
          data['fecha_fin'] != null
              ? DateTime.parse(data['fecha_fin'])
              : DateTime.now(),
      reason: data['motivo'] ?? 'Sin especificar',
      comments: data['comentario_revision'],
      attachmentUrl: data['archivo_adjunto'],
      createdAt:
          data['fecha_creacion'] != null
              ? DateTime.parse(data['fecha_creacion'])
              : DateTime.now(),
      employeeName: employeeName,
      employeeId: employeeId,
    );
  }

  // Añade este método para parsear las respuestas de incapacidades
  Request _parseDisabilityRequest(Map<String, dynamic> data) {
    final String id = data['id_incapacidad'].toString();
    
    // Determine status from 'estado' field
    RequestStatus status;
    switch (data['estado']?.toLowerCase()) {
      case 'aprobado':
        status = RequestStatus.approved;
        break;
      case 'rechazado':
        status = RequestStatus.rejected;
        break;
      case 'pendiente':
      default:
        status = RequestStatus.pending;
    }

    // Extract employee info if available
    String? employeeName;
    String? employeeId;
    
    if (data['empleado'] != null) {
      employeeId = data['id_empleado']?.toString();
      employeeName = data['empleado']['nombre'] != null 
          ? '${data['empleado']['nombre']} ${data['empleado']['apellido'] ?? ''}' 
          : 'Empleado #${data['id_empleado']}';
    }

    return Request(
      id: id,
      type: RequestType.disability,
      status: status,
      startDate: DateTime.parse(data['fecha_inicio']),
      endDate: DateTime.parse(data['fecha_fin']),
      reason: data['motivo'] ?? '',
      attachmentUrl: data['archivo_adjunto'],
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
      employeeName: employeeName,
      employeeId: employeeId,
    );
  }

  RequestStatus _parseStatus(dynamic estado) {
    if (estado == null) return RequestStatus.pending;
    
    final status = estado.toString().toLowerCase();
    
    switch (status) {
      case 'aprobado':
        return RequestStatus.approved;
      case 'rechazado':
        return RequestStatus.rejected;
      case 'pendiente':
      default:
        return RequestStatus.pending;
    }
  }

  void _createNewRequest(Request request) {
    // La solicitud ya fue creada en la API desde request_form.dart
    // Simplemente recargamos todas las solicitudes
    _fetchRequests();
  }

  Future<void> _updateRequestStatus(Request request, RequestStatus newStatus) async {
    // Mostrar diálogo de confirmación
    final TextEditingController commentController = TextEditingController();
    
    final bool confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(newStatus == RequestStatus.approved ? 'Aprobar Solicitud' : 'Rechazar Solicitud'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Está seguro de que desea ${newStatus == RequestStatus.approved ? 'aprobar' : 'rechazar'} esta solicitud?'),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: 'Comentario (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('CONFIRMAR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == RequestStatus.approved ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirm) return;
    
    setState(() {
      isLoading = true;
    });

    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'token');

      if (token == null) {
        throw Exception('No se encontró token de autenticación');
      }

      // Determinar el endpoint y los datos según el tipo de solicitud
      final Uri endpoint;
      final Map<String, dynamic> requestData;

      if (request.type == RequestType.disability) {
        // Para incapacidades
        endpoint = Uri.parse(
          'https://timecontrol-backend.onrender.com/incapacidades/${request.id}',
        );
        requestData = {
          // Ya no usamos campo 'aprobado'
          'estado': newStatus == RequestStatus.approved ? 'aprobado' : 'rechazado',
          'comentario_revision': commentController.text.isNotEmpty
              ? commentController.text
              : newStatus == RequestStatus.approved
                  ? 'Solicitud aprobada'
                  : 'Solicitud rechazada',
        };
      } else {
        // Para permisos y vacaciones
        endpoint = Uri.parse(
          'https://timecontrol-backend.onrender.com/permisos/${request.id}',
        );
        requestData = {
          // Ya no usamos campo 'aprobado'
          'estado': newStatus == RequestStatus.approved ? 'aprobado' : 'rechazado',
          'comentario_revision': commentController.text.isNotEmpty
              ? commentController.text
              : newStatus == RequestStatus.approved
                  ? 'Solicitud aprobada'
                  : 'Solicitud rechazada',
        };
      }

      final response = await http.put(
        endpoint,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestData),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Solicitud ${newStatus == RequestStatus.approved ? 'aprobada' : 'rechazada'} correctamente',
            ),
            backgroundColor:
                newStatus == RequestStatus.approved ? Colors.green : Colors.red,
          ),
        );

        // Actualizar localmente la solicitud
        setState(() {
          final index = _requests.indexWhere((r) => r.id == request.id && r.type == request.type);
          if (index != -1) {
            _requests[index] = Request(
              id: request.id,
              type: request.type,
              status: newStatus,
              startDate: request.startDate,
              endDate: request.endDate,
              reason: request.reason,
              comments: commentController.text.isNotEmpty
                  ? commentController.text
                  : newStatus == RequestStatus.approved
                      ? 'Solicitud aprobada'
                      : 'Solicitud rechazada',
              attachmentUrl: request.attachmentUrl,
              createdAt: request.createdAt,
              employeeName: request.employeeName,
              employeeId: request.employeeId,
            );
          }
        });
      } else {
        throw Exception('Error al actualizar la solicitud: ${response.statusCode}');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Permisos'),
            Tab(text: 'Vacaciones'),
            Tab(text: 'Incapacidad'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRequests,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      drawer: CustomDrawer(isAdmin: isAdmin),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchRequests,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
              : TabBarView(
                controller: _tabController,
                children: [
                  // Permisos
                  _buildRequestTab(RequestType.permission),
                  // Vacaciones
                  _buildRequestTab(RequestType.vacation),
                  // Incapacidad
                  _buildRequestTab(RequestType.disability),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRequestForm(context),
        child: const Icon(Icons.add),
        tooltip: 'Nueva solicitud',
      ),
    );
  }

  Widget _buildRequestTab(RequestType type) {
    final filteredRequests =
        _requests.where((request) => request.type == type).toList();

    return filteredRequests.isEmpty
        ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'No hay solicitudes de ${_getRequestTypeName(type)} registradas',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        )
        : RequestList(
            requests: filteredRequests,
            onUpdateStatus: isAdmin ? _updateRequestStatus : null,
          );
  }

  void _showRequestForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return RequestForm(
                scrollController: scrollController,
                initialType:
                    _tabController.index == 0
                        ? RequestType.permission
                        : _tabController.index == 1
                        ? RequestType.vacation
                        : _tabController.index == 2
                        ? RequestType.disability
                        : RequestType.permission,
                onSubmit: _createNewRequest,
              );
            },
          ),
    );
  }

  String _getRequestTypeName(RequestType type) {
    switch (type) {
      case RequestType.permission:
        return 'permisos';
      case RequestType.vacation:
        return 'vacaciones';
      case RequestType.disability:
        return 'incapacidad';
    }
  }

  Widget _buildRequestCard(Request request) {
    final Color statusColor =
        request.status == RequestStatus.approved
            ? Colors.green
            : request.status == RequestStatus.rejected
            ? Colors.red
            : Colors.orange;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado con tipo y estado
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getRequestTypeText(request.type),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Chip(
                  label: Text(_getStatusText(request.status)),
                  backgroundColor: statusColor.withOpacity(0.2),
                  labelStyle: TextStyle(color: statusColor),
                ),
              ],
            ),
          ),

          // Contenido
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fecha
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${DateFormat('dd/MM/yyyy').format(request.startDate)} - ${DateFormat('dd/MM/yyyy').format(request.endDate)}',
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Motivo
                Text(
                  'Motivo: ${request.reason}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),

                // Documentos adjuntos (si hay)
                if (request.attachmentUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: InkWell(
                      onTap: () async {
                        final url = Uri.parse(request.attachmentUrl!);
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No se pudo abrir el documento'),
                            ),
                          );
                        }
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.attach_file, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Ver documento adjunto',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Comentarios (si hay)
                if (request.comments != null && request.comments!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Comentario del revisor:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(8),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(request.comments!),
                        ),
                      ],
                    ),
                  ),

                // Botones de acción para admin (solo si está pendiente)
                if (isAdmin && request.status == RequestStatus.pending)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const SizedBox(width: 8),
                        // Botón rechazar
                        ElevatedButton.icon(
                          icon: const Icon(Icons.cancel, color: Colors.white),
                          label: const Text('Rechazar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          onPressed:
                              () => _updateRequestStatus(
                                request,
                                RequestStatus.rejected,
                              ),
                        ),
                        const SizedBox(width: 8),
                        // Botón aprobar
                        ElevatedButton.icon(
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                          ),
                          label: const Text('Aprobar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          onPressed:
                              () => _updateRequestStatus(
                                request,
                                RequestStatus.approved,
                              ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Añadir estos métodos auxiliares a la clase _RequestsScreenState

  String _getRequestTypeText(RequestType type) {
    switch (type) {
      case RequestType.permission:
        return 'Permiso';
      case RequestType.vacation:
        return 'Vacaciones';
      case RequestType.disability:
        return 'Incapacidad';      
    }
  }

  String _getStatusText(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return 'Pendiente';
      case RequestStatus.approved:
        return 'Aprobado';
      case RequestStatus.rejected:
        return 'Rechazado';      
    }
  }
}
