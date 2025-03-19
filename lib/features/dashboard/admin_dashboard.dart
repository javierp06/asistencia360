import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/custom_drawer.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/theme_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String userName = "Administrador";

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final storage = const FlutterSecureStorage();
    final name = await storage.read(key: 'userName');
    if (name != null && mounted) {
      setState(() {
        userName = name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ajustar para mejor visualización web
    final isWeb =
        Theme.of(context).platform == TargetPlatform.macOS ||
        Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.linux;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        elevation: 0,
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return IconButton(
                icon: Icon(
                  themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                ),
                onPressed: () {
                  themeProvider.toggleTheme();
                },
                tooltip:
                    themeProvider.isDarkMode
                        ? 'Cambiar a modo claro'
                        : 'Cambiar a modo oscuro',
              );
            },
          ),
        ],
      ),
      drawer: const CustomDrawer(isAdmin: true),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors:
                isDarkMode
                    ? [Colors.grey.shade900, Colors.grey.shade800]
                    : [Colors.blue.shade50, Colors.blue.shade100],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWeb ? 1200 : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  Text(
                    'Módulos del Sistema',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Panel de módulos
                  Expanded(
                    child: GridView.count(
                      crossAxisCount:
                          Responsive.isDesktop(context)
                              ? 4
                              : (Responsive.isTablet(context) ? 3 : 2),
                      crossAxisSpacing: 16.0,
                      mainAxisSpacing: 16.0,
                      childAspectRatio: isWeb ? 1.3 : 1.0,
                      children: [
                        DashboardCard(
                          icon: Icons.people_alt,
                          title: 'Empleados',                          
                          color: Colors.blueAccent,
                          onTap:
                              () => Navigator.pushNamed(context, '/employees'),
                        ),
                        DashboardCard(
                          icon: Icons.attach_money,
                          title: 'Nóminas',                       
                          color: Colors.green,
                          onTap: () => Navigator.pushNamed(context, '/payroll'),
                        ),
                        DashboardCard(
                          icon: Icons.access_time,
                          title: 'Asistencias',                         
                          color: Colors.orange,
                          onTap:
                              () => Navigator.pushNamed(context, '/attendance'),
                        ),
                        DashboardCard(
                          icon: Icons.bar_chart,
                          title: 'Reportes',
                          color: Colors.purple,
                          onTap: () => Navigator.pushNamed(context, '/reports'),
                        ),
                        DashboardCard(
                          icon: Icons.request_page,
                          title: 'Solicitudes',                          
                          color: Colors.amber,
                          onTap:
                              () => Navigator.pushNamed(context, '/requests'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
