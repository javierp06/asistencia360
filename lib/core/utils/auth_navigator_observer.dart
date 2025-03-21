import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _checkRouteAuthorization(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      _checkRouteAuthorization(newRoute);
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  Future<void> _checkRouteAuthorization(Route route) async {
    // Skip for login route
    if (route.settings.name == '/login') return;
    
    final storage = FlutterSecureStorage();
    final token = await storage.read(key: 'token');
    
    if (token == null && route.settings.name != '/login') {
      // Navigate to login if not authenticated
      navigator?.pushReplacementNamed('/login');
    }
  }
}