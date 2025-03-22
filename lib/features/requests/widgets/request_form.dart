import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/request.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:http_parser/http_parser.dart';

class RequestForm extends StatefulWidget {
  final ScrollController scrollController;
  final RequestType initialType;
  final Function(Request) onSubmit;

  const RequestForm({
    Key? key,
    required this.scrollController,
    required this.initialType,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<RequestForm> {
  late RequestType _selectedType;
  final TextEditingController _reasonController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  String? _attachmentName;
  String? _attachmentUrl;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SingleChildScrollView(
      controller: widget.scrollController,
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera estilizada
            Container(
              padding: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: theme.dividerColor, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.note_add, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Nueva Solicitud',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Tipo de solicitud
            DropdownButtonFormField<RequestType>(
              decoration: const InputDecoration(
                labelText: 'Tipo de Solicitud',
                border: OutlineInputBorder(),
              ),
              value: _selectedType,
              onChanged: (RequestType? value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
              },
              items: [
                DropdownMenuItem(
                  value: RequestType.permission,
                  child: const Text('Permiso'),
                ),
               
                DropdownMenuItem(
                  value: RequestType.vacation,
                  child: const Text('Vacaciones'),
                ),
                DropdownMenuItem(
                  value: RequestType.disability,
                  child: const Text('Incapacidad'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Fecha de inicio
            ListTile(
              title: const Text('Fecha de inicio'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_startDate)),
              leading: const Icon(Icons.calendar_today),
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null && picked != _startDate) {
                  setState(() {
                    _startDate = picked;
                    if (_endDate.isBefore(_startDate)) {
                      _endDate = _startDate.add(const Duration(days: 1));
                    }
                  });
                }
              },
            ),
            
            // Fecha de fin
            ListTile(
              title: const Text('Fecha de fin'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_endDate)),
              leading: const Icon(Icons.calendar_today),
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _endDate.isAfter(_startDate)
                      ? _endDate
                      : _startDate.add(const Duration(days: 1)),
                  firstDate: _startDate,
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null && picked != _endDate) {
                  setState(() {
                    _endDate = picked;
                  });
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            // Motivo
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Motivo de la solicitud',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            
            const SizedBox(height: 16),
            
            // Documentos adjuntos (solo para incapacidad)
            if (_selectedType == RequestType.disability)
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    setState(() {
                      _isSubmitting = true;
                    });
                    
                    // Intenta usar el file picker
                    FilePickerResult? result;
                    try {
                      result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                        withData: true, // Add this to ensure data is available
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al iniciar el selector de archivos: $e')),
                      );
                      setState(() {
                        _isSubmitting = false;
                      });
                      return;
                    }
                    
                    // Improved null safety check
                    if (result != null && result.files.isNotEmpty) {
                      final file = result.files.first;
                      final filePath = file.path;
                      
                      if (filePath == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No se pudo acceder a la ruta del archivo')),
                        );
                        setState(() {
                          _isSubmitting = false;
                        });
                        return;
                      }
                      
                      try {
                        final storage = const FlutterSecureStorage();
                        final token = await storage.read(key: 'token');
                        
                        if (token == null) {
                          throw Exception('No se encontró token de autenticación');
                        }
                        
                        // Preparar el archivo para subir
                        final file = File(result.files.single.path!);
                        final fileName = result.files.single.name;
                        
                        // Crear una petición multipart
                        final request = http.MultipartRequest(
                          'POST',
                          Uri.parse('https://timecontrol-backend.onrender.com/incapacidades'),
                        );
                        
                        // Añadir el archivo
                        final fileStream = http.ByteStream(file.openRead());
                        final length = await file.length();
                        
                        final multipartFile = http.MultipartFile(
                          'file',
                          fileStream,
                          length,
                          filename: fileName,
                          contentType: MediaType('application', 'octet-stream'),
                        );
                        
                        // Añadir headers de autenticación
                        request.headers['Authorization'] = 'Bearer $token';
                        request.files.add(multipartFile);
                        
                        // Mostrar indicador de progreso
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Subiendo archivo...')),
                        );
                        
                        // Enviar la petición
                        final response = await request.send();
                        final responseData = await response.stream.bytesToString();
                        final jsonResponse = json.decode(responseData);
                        
                        if (response.statusCode == 200 || response.statusCode == 201) {
                          setState(() {
                            _attachmentName = fileName;
                            _attachmentUrl = jsonResponse['url']; // Guardar la URL del servidor
                          });
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Archivo subido: $_attachmentName')),
                          );
                        } else {
                          throw Exception('Error al subir archivo: ${response.statusCode}');
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  } finally {
                    setState(() {
                      _isSubmitting = false;
                    });
                  }
                },
                icon: const Icon(Icons.upload_file),
                label: Text(_isSubmitting ? 'Subiendo...' : 'Subir Comprobante'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black87,
                ),
              ),
            
            if (_attachmentName != null && _selectedType == RequestType.disability)
              ListTile(
                leading: const Icon(Icons.file_present),
                title: Text(_attachmentName!),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    setState(() {
                      _attachmentName = null;
                      _attachmentUrl = null;
                    });
                  },
                ),
                onTap: () async {
                  final url = Uri.parse(_attachmentUrl!);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('No se pudo abrir el documento')),
                    );
                  }
                },
              ),
            
            const SizedBox(height: 32),
            
            // Botón de envío estilizado
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitForm,
                  icon: const Icon(Icons.send),
                  label: _isSubmitting
                      ? const SizedBox(
                          width: 20, 
                          height: 20, 
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                        )
                      : const Text('ENVIAR SOLICITUD'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitForm() async {
  if (_reasonController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Por favor ingrese el motivo de la solicitud')),
    );
    return;
  }

  setState(() {
    _isSubmitting = true;
  });

  try {
    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: 'token');
    final userId = await storage.read(key: 'userId');
    final empleadoId = await storage.read(key: 'empleadoId'); // Añadir esta línea

    if (token == null || userId == null) {
      throw Exception('No se encontró información de autenticación');
    }

    // Determinar el endpoint y los datos a enviar según el tipo de solicitud
    final Uri endpoint;
    final Map<String, dynamic> requestData;

    // Verificar si es incapacidad o permiso/vacaciones
    if (_selectedType == RequestType.disability) {
      // Para incapacidad
      endpoint = Uri.parse('https://timecontrol-backend.onrender.com/incapacidades');
      requestData = {
        'id_empleado': empleadoId, // Usar el ID del empleado
        'tipo_incapacidad': 'medica', // O el tipo que corresponda
        'fecha_inicio': DateFormat('yyyy-MM-dd').format(_startDate),
        'fecha_fin': DateFormat('yyyy-MM-dd').format(_endDate),
        'motivo': _reasonController.text,
        'archivo_adjunto': _attachmentUrl, // URL del archivo ya subido
      };
    } else {
      // Para permisos o vacaciones
      endpoint = Uri.parse('https://timecontrol-backend.onrender.com/permisos');
      
      // Convertir el tipo de solicitud a un string para el backend
      String requestType = _selectedType == RequestType.vacation ? 'vacaciones' : 'permiso';
      
      // En la función donde creas el permiso, asegúrate de usar el nuevo campo
      requestData = {
        'tipo_permiso': requestType,
        'id_empleado': empleadoId,
        'fecha_inicio': DateFormat('yyyy-MM-dd').format(_startDate),
        'fecha_fin': DateFormat('yyyy-MM-dd').format(_endDate),
        'motivo': _reasonController.text,
        'estado': 'pendiente',  // Añadir el campo estado con valor 'pendiente'
        'archivo_adjunto': _attachmentUrl, // URL del archivo ya subido
      };
    }

    final response = await http.post(
      endpoint,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(requestData),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final responseData = json.decode(response.body);
      
      // Determinar el ID según el tipo de respuesta
      final String id = _selectedType == RequestType.disability 
          ? responseData['id_incapacidad']?.toString() ?? 'temp'
          : responseData['id_permiso']?.toString() ?? 'temp';
      
      final request = Request(
        id: id,
        type: _selectedType,
        status: RequestStatus.pending,
        startDate: _startDate,
        endDate: _endDate,
        reason: _reasonController.text,
        attachmentUrl: _attachmentUrl,
        createdAt: DateTime.now(),
      );

      widget.onSubmit(request);
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada exitosamente')),
      );
    } else {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }
  } catch (e) {
    setState(() {
      _isSubmitting = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al enviar la solicitud: $e')),
    );
  }
}
}