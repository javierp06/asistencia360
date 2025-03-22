import 'dart:convert';

class Deduccion {
  final String id;
  final String nombre;
  final String? descripcion;
  final double porcentaje;

  Deduccion({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.porcentaje,
  });

  factory Deduccion.fromJson(Map<String, dynamic> json) {
    return Deduccion(
      id: json['id_deduccion'].toString(),
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      porcentaje: double.tryParse(json['porcentaje']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_deduccion': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'porcentaje': porcentaje,
    };
  }
}

class EmpleadoDeduccion {
  final String id;
  final String empleadoId;
  final String deduccionId;
  final Deduccion deduccion;
  final bool activo;

  EmpleadoDeduccion({
    required this.id,
    required this.empleadoId,
    required this.deduccionId,
    required this.deduccion,
    this.activo = true,
  });

  factory EmpleadoDeduccion.fromJson(Map<String, dynamic> json) {
    return EmpleadoDeduccion(
      id: json['id_empleado_deduccion'].toString(),
      empleadoId: json['id_empleado'].toString(),
      deduccionId: json['id_deduccion'].toString(),
      deduccion: Deduccion.fromJson(json['deduccion']),
      activo: json['activo'] ?? true,
    );
  }
}