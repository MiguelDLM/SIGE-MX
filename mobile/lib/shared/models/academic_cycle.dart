class AcademicCycle {
  final String id;
  final String? nombre;
  final String? fechaInicio;
  final String? fechaFin;
  final bool activo;

  const AcademicCycle({
    required this.id,
    this.nombre,
    this.fechaInicio,
    this.fechaFin,
    required this.activo,
  });

  factory AcademicCycle.fromJson(Map<String, dynamic> json) => AcademicCycle(
        id: json['id'] as String,
        nombre: json['nombre'] as String?,
        fechaInicio: json['fecha_inicio'] as String?,
        fechaFin: json['fecha_fin'] as String?,
        activo: json['activo'] as bool? ?? false,
      );
}
