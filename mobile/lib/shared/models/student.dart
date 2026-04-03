class Student {
  final String id;
  final String matricula;
  final String? nombre;
  final String? apellidoPaterno;
  final String? apellidoMaterno;

  const Student({
    required this.id,
    required this.matricula,
    this.nombre,
    this.apellidoPaterno,
    this.apellidoMaterno,
  });

  String get nombreCompleto => [nombre, apellidoPaterno, apellidoMaterno]
      .where((s) => s != null && s.isNotEmpty)
      .join(' ');

  factory Student.fromJson(Map<String, dynamic> json) => Student(
        id: json['id'] as String,
        matricula: json['matricula'] as String,
        nombre: json['nombre'] as String?,
        apellidoPaterno: json['apellido_paterno'] as String?,
        apellidoMaterno: json['apellido_materno'] as String?,
      );
}
