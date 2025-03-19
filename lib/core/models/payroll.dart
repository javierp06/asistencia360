class Payroll {
  final String id;
  final String empleadoId;
  final String empleadoNombre; // Para mostrar el nombre sin necesidad de otra consulta
  final String periodo; // Mes/año
  final double bonificaciones;
  final double horasExtra;
  final double salarioBruto;
  final double salarioNeto;
  final double deduccionRap;
  final double deduccionIhss;
  final DateTime fechaGeneracion;

  Payroll({
    required this.id,
    required this.empleadoId,
    required this.empleadoNombre,
    required this.periodo,
    required this.bonificaciones,
    required this.horasExtra,
    required this.salarioBruto,
    required this.salarioNeto,
    required this.deduccionRap,
    required this.deduccionIhss,
    required this.fechaGeneracion,
  });

  factory Payroll.fromJson(Map<String, dynamic> json) {
    // Extract employee name from the nested empleado object
    String employeeName = 'Empleado';
    if (json['empleado'] != null) {
      // If empleado object exists, get the nombre and apellido
      employeeName = '${json['empleado']['nombre'] ?? ''} ${json['empleado']['apellido'] ?? ''}'.trim();
      if (employeeName.isEmpty) {
        employeeName = 'Empleado #${json['id_empleado']}';
      }
    }

    return Payroll(
      id: json['id_nomina'].toString(),
      empleadoId: json['id_empleado'].toString(),
      empleadoNombre: employeeName, // Use the extracted employee name
      periodo: json['periodo'] ?? '',
      bonificaciones: double.tryParse(json['bonificaciones']?.toString() ?? '0') ?? 0.0,
      horasExtra: double.tryParse(json['horas_extra']?.toString() ?? '0') ?? 0.0,
      salarioBruto: double.tryParse(json['salario_bruto']?.toString() ?? '0') ?? 0.0,
      salarioNeto: double.tryParse(json['salario_neto']?.toString() ?? '0') ?? 0.0,
      deduccionRap: double.tryParse(json['deduccion_rap']?.toString() ?? '0') ?? 0.0,
      deduccionIhss: double.tryParse(json['deduccion_ihss']?.toString() ?? '0') ?? 0.0,
      fechaGeneracion: json['fecha_generacion'] != null 
          ? DateTime.parse(json['fecha_generacion']) 
          : DateTime.now(),      
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_empleado': empleadoId,
      'periodo': periodo,
      'bonificaciones': bonificaciones,
      'horas_extra': horasExtra,
      'salario_bruto': salarioBruto,
      'salario_neto': salarioNeto,
      'deduccion_rap': deduccionRap,
      'deduccion_ihss': deduccionIhss,
    };
  }
}