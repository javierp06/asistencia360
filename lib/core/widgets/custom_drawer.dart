import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';  // Add this import

class CustomDrawer extends StatelessWidget {
  final bool isAdmin;

  const CustomDrawer({Key? key, required this.isAdmin}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Drawer(
      elevation: 10.0,
      child: Column(
        children: [
          // Drawer Header with gradient background
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDarkMode 
                    ? [Colors.grey.shade900, Colors.grey.shade800] 
                    : [primaryColor, primaryColor.withOpacity(0.7)],
              ),
            ),
            width: double.infinity,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Avatar with shadow
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        size: 36, 
                        color: primaryColor,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Role title with enhanced typography
                  Text(
                    isAdmin ? 'Administrador' : 'Empleado',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // App name with enhanced typography
                  Text(
                    'Tourist Options',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          
          // Menu items with improved styling
          Expanded(
            child: Container(
              color: isDarkMode ? Colors.grey.shade900 : Colors.white,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 8),
                  
                  if (isAdmin) ...[
                    _buildMenuItem(
                      context,
                      icon: Icons.dashboard,
                      title: 'Dashboard',
                      onTap: () => Navigator.pushReplacementNamed(context, '/admin'),
                      isDarkMode: isDarkMode,
                      primaryColor: primaryColor,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.people,
                      title: 'Empleados',
                      onTap: () => Navigator.pushNamed(context, '/employees'),
                      isDarkMode: isDarkMode,
                      primaryColor: primaryColor,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.attach_money,
                      title: 'Nóminas',
                      onTap: () => Navigator.pushNamed(context, '/payroll'),
                      isDarkMode: isDarkMode,
                      primaryColor: primaryColor,
                    ),
                  ] else ...[
                    _buildMenuItem(
                      context,
                      icon: Icons.dashboard,
                      title: 'Mi Portal',
                      onTap: () => Navigator.pushReplacementNamed(context, '/employee'),
                      isDarkMode: isDarkMode,
                      primaryColor: primaryColor,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.calendar_today,
                      title: 'Mi Asistencia',
                      onTap: () => Navigator.pushNamed(
                        context, 
                        '/attendance', 
                        arguments: {'viewType': 'personal'}
                      ),
                      isDarkMode: isDarkMode,
                      primaryColor: primaryColor,
                    ),
                  ],
                  
                  // Common menu items for both types
                  _buildMenuItem(
                    context,
                    icon: Icons.bar_chart,
                    title: 'Reportes',
                    onTap: () => Navigator.pushNamed(context, '/reports'),
                    isDarkMode: isDarkMode,
                    primaryColor: primaryColor,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.request_page,
                    title: 'Solicitudes',
                    onTap: () => Navigator.pushNamed(context, '/requests'),
                    isDarkMode: isDarkMode,
                    primaryColor: primaryColor,
                  ),
                  
                  const Divider(),
                  
                  // Settings and Logout with enhanced styling
                  _buildMenuItem(
                    context,
                    icon: Icons.settings,
                    title: 'Cambiar contraseña',
                    onTap: () => Navigator.pushNamed(context, '/change_password'),
                    isDarkMode: isDarkMode,
                    primaryColor: primaryColor,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.exit_to_app,
                    title: 'Cerrar sesión',
                    onTap: () {
                      // Implement logout functionality
                      const FlutterSecureStorage().deleteAll().then((_) {
                        Navigator.pushReplacementNamed(context, '/login');
                      });
                    },
                    isDarkMode: isDarkMode,
                    primaryColor: primaryColor,
                    isDestructive: true,
                  ),
                  
                  // Theme Toggle with improved styling
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Consumer<ThemeProvider>(
                      builder: (context, themeProvider, _) {
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => themeProvider.toggleTheme(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    themeProvider.isDarkMode ? 'Modo claro' : 'Modo oscuro',
                                    style: TextStyle(
                                      color: isDarkMode ? Colors.white70 : Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper method to build menu items with consistent styling
  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isDarkMode,
    required Color primaryColor,
    bool isDestructive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive 
              ? Colors.redAccent
              : primaryColor,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDestructive
                ? Colors.redAccent
                : isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: onTap,
        hoverColor: primaryColor.withOpacity(0.1),
        tileColor: Colors.transparent,
      ),
    );
  }
}