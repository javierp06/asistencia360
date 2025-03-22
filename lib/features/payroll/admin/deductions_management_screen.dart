import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/models/deduccion.dart';
import '../../../core/config/api_config.dart';

class DeductionsManagementScreen extends StatefulWidget {
  const DeductionsManagementScreen({super.key});

  @override
  _DeductionsManagementScreenState createState() => _DeductionsManagementScreenState();
}

class _DeductionsManagementScreenState extends State<DeductionsManagementScreen> {
  List<Deduccion> deducciones = [];
  bool isLoading = true;
  String? errorMessage;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _porcentajeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDeducciones();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _porcentajeController.dispose();
    super.dispose();
  }

  Future<void> _fetchDeducciones() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

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

      if (mounted) {
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          setState(() {
            deducciones = data.map((json) => Deduccion.fromJson(json)).toList();
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = 'Error al cargar deducciones: ${response.statusCode}';
            isLoading = false;
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          errorMessage = 'Error de conexión: $error';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _createDeduccion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

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
          'nombre': _nombreController.text,
          'descripcion': _descripcionController.text,
          'porcentaje': double.tryParse(_porcentajeController.text) ?? 0,
        }),
      );

      if (mounted) {
        if (response.statusCode == 201) {
          _nombreController.clear();
          _descripcionController.clear();
          _porcentajeController.clear();
          Navigator.pop(context);
          _fetchDeducciones();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deducción creada exitosamente')),
          );
        } else {
          setState(() {
            isLoading = false;
            errorMessage = 'Error al crear deducción: ${response.statusCode}';
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Error de conexión: $error';
        });
      }
    }
  }

  void _showCreateDeduccionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear Nueva Deducción'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej: RAP, IHSS, etc.',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese un nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  hintText: 'Descripción de la deducción',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _porcentajeController,
                decoration: const InputDecoration(
                  labelText: 'Porcentaje',
                  hintText: 'Ej: 4.0',
                  suffixText: '%',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese un porcentaje';
                  }
                  try {
                    final percent = double.parse(value);
                    if (percent < 0 || percent > 100) {
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
            onPressed: _createDeduccion,
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Deducciones'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
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
                        onPressed: _fetchDeducciones,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : deducciones.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.category,
                            size: 70,
                            color: theme.colorScheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No hay deducciones configuradas',
                            style: TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _showCreateDeduccionDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Crear Nueva Deducción'),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                const Flexible(
                                  child: Text(
                                    'Las deducciones configuradas aquí se pueden asignar a los empleados en su perfil.',
                                    style: TextStyle(
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Deducciones Disponibles',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.builder(
                              itemCount: deducciones.length,
                              itemBuilder: (context, index) {
                                final deduccion = deducciones[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                                      child: Text(
                                        '${deduccion.porcentaje.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    title: Text(deduccion.nombre),
                                    subtitle: deduccion.descripcion != null
                                        ? Text(deduccion.descripcion!)
                                        : null,
                                    trailing: IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () {
                                        // Implementar edición de deducción
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDeduccionDialog,
        child: const Icon(Icons.add),
        tooltip: 'Crear Nueva Deducción',
      ),
    );
  }
}