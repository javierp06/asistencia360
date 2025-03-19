class ApiConfig {
  static const String baseUrl = 'https://timecontrol-backend.onrender.com';
  
  // Endpoints
  static String get empleadosEndpoint => '$baseUrl/empleados';
  static String get nominasEndpoint => '$baseUrl/nominas';
  static String get asistenciaEndpoint => '$baseUrl/asistencia';
  
  // Specific endpoints
  static String nominasEmpleado(String id) => '$baseUrl/nominas/empleado/$id';
  static String asistenciaEmpleado(String id) => '$baseUrl/asistencia/$id';
}