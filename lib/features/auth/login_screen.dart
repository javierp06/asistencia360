// lib/features/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/theme/theme_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  bool _validateInputs() {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Usuario y contraseña son requeridos'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    if (!_validateInputs()) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final url = Uri.parse(
        'https://timecontrol-backend.onrender.com/usuarios/login',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nombre_usuario': _usernameController.text,
          'contraseña': _passwordController.text,
        }),
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        // Parse the response
        final responseData = json.decode(response.body);

        final isAdmin = responseData['usuario']['rol'] == 'admin';
        final token = responseData['token'];
        final userId = responseData['usuario']['id_usuario'].toString();
        final userRole = responseData['usuario']['rol'];

        final userName =
            responseData['usuario']['nombre'] != null
                ? "${responseData['usuario']['nombre']} ${responseData['usuario']['apellido'] ?? ''}"
                : null;

        final storage = FlutterSecureStorage();
        await storage.write(key: 'token', value: token);
        await storage.write(key: 'userId', value: userId);
        await storage.write(key: 'userRole', value: userRole);
        await storage.write(
          key: 'empleadoId',
          value: responseData['usuario']['id_empleado'].toString(),
        );
        if (userName != null) {
          await storage.write(key: 'userName', value: userName);
        }

        if (isAdmin) {
          Navigator.pushReplacementNamed(context, '/admin');
        } else {
          Navigator.pushReplacementNamed(context, '/employee');
        }
      } else {
        // Handle login failure
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Credenciales inválidas'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode 
                ? [Colors.grey.shade900, Colors.grey.shade800] 
                : [Colors.blue.shade50, Colors.blue.shade100],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 
                          MediaQuery.of(context).padding.top - 
                          MediaQuery.of(context).padding.bottom,
              ),
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Obtiene el ancho disponible
                    double availableWidth = constraints.maxWidth;
                    // Calcula el ancho deseado: 100% en móvil, máximo 450px en web
                    double containerWidth = availableWidth > 600 ? 450 : availableWidth * 0.95;
                    
                    return Container(
                      width: containerWidth,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            
                            // Logo or App Icon
                            Container(
                              height: 100,
                              width: 100,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.3),
                                    blurRadius: 15,
                                    spreadRadius: 5,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.travel_explore,
                                color: Colors.white,
                                size: 50,
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // App Title
                            Text(
                              'Tourist Options',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : primaryColor,
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            Text(
                              'Sistema de Gestión',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                              ),
                            ),
                            
                            const SizedBox(height: 40),
                            
                            // Login Card
                            Card(
                              elevation: 8,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              shadowColor: primaryColor.withOpacity(0.4),
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Iniciar Sesión',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 8),
                                    
                                    Text(
                                      'Ingresa tus credenciales para acceder',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 32),
                                    
                                    // Username field
                                    TextField(
                                      controller: _usernameController,
                                      decoration: InputDecoration(
                                        labelText: 'Usuario',
                                        prefixIcon: const Icon(Icons.person),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide.none,
                                        ),
                                        filled: true,
                                        fillColor: isDarkMode 
                                            ? Colors.grey.shade800 
                                            : Colors.grey.shade100,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                      cursorColor: primaryColor,
                                    ),
                                    
                                    const SizedBox(height: 16),
                                    
                                    // Password field
                                    TextField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      decoration: InputDecoration(
                                        labelText: 'Contraseña',
                                        prefixIcon: const Icon(Icons.lock),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword = !_obscurePassword;
                                            });
                                          },
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide.none,
                                        ),
                                        filled: true,
                                        fillColor: isDarkMode 
                                            ? Colors.grey.shade800 
                                            : Colors.grey.shade100,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                      cursorColor: primaryColor,
                                    ),
                                    
                                    const SizedBox(height: 24),
                                    
                                    // Login button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _login,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          elevation: 2,
                                        ),
                                        child: _isLoading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text(
                                              'INICIAR SESIÓN',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Theme toggle
                            Consumer<ThemeProvider>(
                              builder: (context, themeProvider, _) {
                                return TextButton.icon(
                                  icon: Icon(
                                    themeProvider.isDarkMode 
                                        ? Icons.light_mode 
                                        : Icons.dark_mode,
                                    color: isDarkMode ? Colors.white70 : Colors.black54,
                                  ),
                                  label: Text(
                                    themeProvider.isDarkMode
                                        ? 'Cambiar a modo claro'
                                        : 'Cambiar a modo oscuro',
                                    style: TextStyle(
                                      color: isDarkMode ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                  onPressed: () {
                                    themeProvider.toggleTheme();
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
