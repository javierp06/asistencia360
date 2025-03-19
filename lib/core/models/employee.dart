class Employee {
  final String id;
  final String nombre;
  final String apellido;
  final String dni;
  final String email;
  final String telefono;
  final String telefonoEmergencia;
  final String sexo;
  final double salario;
  final DateTime fechaContratacion;
  final String rol;
  final bool activo; // Change from getter to real property

  Employee({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.dni,
    required this.email,
    required this.telefono,
    required this.telefonoEmergencia,
    required this.sexo,
    required this.salario,
    required this.fechaContratacion,
    required this.rol,
    this.activo = true, // Default to true if not provided
  });

  String get name => '$nombre $apellido';

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id_empleado'].toString(),
      nombre: json['nombre'] ?? '',
      apellido: json['apellido'] ?? '',
      dni: json['DNI'] ?? '',
      email: json['email'] ?? '',
      telefono: json['telefono'] ?? '',
      telefonoEmergencia: json['telefono_emergencia'] ?? '',
      sexo: json['sexo'] ?? '',
      salario: double.tryParse(json['salario'].toString()) ?? 0.0,
      fechaContratacion: json['fecha_contratacion'] != null 
          ? DateTime.parse(json['fecha_contratacion']) 
          : DateTime.now(),
      rol: json['rol'] ?? '',
      activo: json['activo'] == 1 || json['activo'] == true, // Convert numeric or boolean values
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_empleado': id,
      'nombre': nombre,
      'apellido': apellido,
      'DNI': dni,
      'email': email,
      'telefono': telefono,
      'telefono_emergencia': telefonoEmergencia,
      'sexo': sexo,
      'rol': rol,
      'fecha_contratacion': fechaContratacion.toIso8601String(),
      'salario': salario,
      'activo': activo,
    };
  }
}