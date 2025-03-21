import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RouteGuard extends StatefulWidget {
  final Widget child;
  final bool requiresAdmin;
  final bool requiresAuth;

  const RouteGuard({
    Key? key,
    required this.child,
    this.requiresAdmin = false,
    this.requiresAuth = true,
  }) : super(key: key);

  @override
  State<RouteGuard> createState() => _RouteGuardState();
}

class _RouteGuardState extends State<RouteGuard> {
  bool _isLoading = true;
  bool _isAuthorized = false;

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
  }

  Future<void> _checkAuthorization() async {
    final storage = const FlutterSecureStorage();
    
    // Check if user is authenticated
    final token = await storage.read(key: 'token');
    final userRole = await storage.read(key: 'userRole');
    
    bool isAuthorized = false;
    
    if (widget.requiresAuth && token != null) {
      if (widget.requiresAdmin) {
        // Check if user is admin
        isAuthorized = userRole == 'admin';
      } else {
        // Just needs to be authenticated
        isAuthorized = true;
      }
    } else if (!widget.requiresAuth) {
      // Public route that doesn't require auth
      isAuthorized = true;
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isAuthorized = isAuthorized;
      });
    }
    
    // Redirect if not authorized
    if (!isAuthorized && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_isAuthorized) {
      return widget.child;
    }
    
    // Show a fallback until redirect happens
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              'Acceso no autorizado',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Redirigiendo a la página de inicio de sesión...'),
          ],
        ),
      ),
    );
  }
}