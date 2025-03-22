import 'package:asistencia360/features/payroll/admin/deductions_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:asistencia360/features/requests/requests_screen.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart'; // Añadir esta importación
import 'features/auth/login_screen.dart';
import 'features/dashboard/admin_dashboard.dart';
import 'features/dashboard/employee_dashboard.dart';
import 'features/employees/employee_list.dart';
import 'features/payroll/payroll_screen.dart';
import 'features/attendance/attendance_screen.dart';
import 'features/reports/reports_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/change_password_screen.dart';
import 'core/utils/auth_navigator_observer.dart';
import 'core/utils/route_guard.dart';
import 'features/reports/admin_reports_screen.dart';
import 'features/reports/employee_reports_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('es');
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const TouristOptionsApp(),
    ),
  );
}

class TouristOptionsApp extends StatelessWidget {
  const TouristOptionsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Tourist Options - Employee Monitoring',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          initialRoute: '/login',
          navigatorObservers: [AuthNavigatorObserver()],
          routes: {
            '/login': (context) => const LoginScreen(),
            '/deductions': (context) => const DeductionsManagementScreen(),
            '/admin':
                (context) =>
                    RouteGuard(requiresAdmin: true, child: AdminDashboard()),
            '/employee':
                (context) => RouteGuard(
                  requiresAuth: true,
                  requiresAdmin: false,
                  child: const EmployeeDashboard(),
                ),
            '/employees':
                (context) =>
                    RouteGuard(requiresAdmin: true, child: EmployeeList()),
            '/payroll':
                (context) => RouteGuard(
                  requiresAuth: true,
                  child: const PayrollScreen(),
                ),
            '/attendance':
                (context) => RouteGuard(
                  requiresAuth: true,
                  child: const AttendanceScreen(),
                ),
            '/reports':
                (context) => RouteGuard(
                  requiresAuth: true,
                  child: const ReportsScreen(),
                ),
            '/requests':
                (context) => RouteGuard(
                  requiresAuth: true,
                  child: const RequestsScreen(),
                ),
            '/change_password':
                (context) => RouteGuard(
                  requiresAuth: true,
                  child: const ChangePasswordScreen(),
                ),
            '/admin-reports':
                (context) => RouteGuard(
                  requiresAuth: true,
                  requiresAdmin: true,
                  child: const AdminReportsScreen(),
                ),
            '/employee-reports':
                (context) => RouteGuard(
                  requiresAuth: true,
                  child: const EmployeeReportsScreen(),
                ),
          },
        );
      },
    );
  }
}
