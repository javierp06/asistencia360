import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/custom_drawer.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/theme_provider.dart';

class EmployeeDashboard extends StatelessWidget {
  const EmployeeDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Ajustar para mejor visualización web
    final isWeb =
        Theme.of(context).platform == TargetPlatform.macOS ||
        Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.linux;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Empleado'),
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
      drawer: const CustomDrawer(isAdmin: false),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isWeb ? 1200 : double.infinity,
            ),
            // Wrap the entire column in a SingleChildScrollView
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [                  
                  const SizedBox(height: 24),
                  Text(
                    'Opciones rápidas',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Grid de cards para accesos rápidos
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount:
                        Responsive.isDesktop(context)
                            ? 4
                            : (Responsive.isTablet(context) ? 3 : 2),
                    crossAxisSpacing: 16.0,
                    mainAxisSpacing: 16.0,
                    childAspectRatio: isWeb ? 1.3 : 1.0,
                    children: [
                      DashboardCard(
                        icon: Icons.calendar_today,
                        title: 'Mi Asistencia',
                        color: Colors.blueAccent,
                        onTap:
                            () => Navigator.pushNamed(context, '/attendance'),
                      ),
                      DashboardCard(
                        icon: Icons.receipt_long,
                        title: 'Mis Nóminas',
                        color: Colors.purpleAccent,
                        onTap: () => Navigator.pushNamed(context, '/payroll'),
                      ),
                      DashboardCard(
                        icon: Icons.bar_chart,
                        title: 'Reportes',
                        color: Colors.orangeAccent,
                        onTap: () => Navigator.pushNamed(context, '/employee-reports'),
                      ),
                      DashboardCard(
                        icon: Icons.request_page,
                        title: 'Mis Solicitudes',
                        color: Colors.teal,
                        onTap: () => Navigator.pushNamed(context, '/requests'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Resumen del mes actual
                  Text(
                    'Resumen del mes',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Replace the Row with a SingleChildScrollView + Row combination
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatItem(
                                  context,
                                  '21/22',
                                  'Días trabajados',
                                  Colors.blue,
                                ),
                                const SizedBox(
                                  width: 12,
                                ), // Add spacing between items
                                _buildStatItem(
                                  context,
                                  '156.5',
                                  'Horas trabajadas',
                                  Colors.green,
                                ),
                                const SizedBox(width: 12),
                                _buildStatItem(
                                  context,
                                  '2',
                                  'Llegadas tarde',
                                  Colors.orange,
                                ),
                                const SizedBox(width: 12),
                                _buildStatItem(
                                  context,
                                  '1',
                                  'Ausencias',
                                  Colors.red,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  // Update the _buildStatItem method to be more responsive
  Widget _buildStatItem(
    BuildContext context,
    String value,
    String label,
    Color color,
  ) {
    // Get screen width to make elements responsive
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isSmallScreen ? 10 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
