class Group {
  final String id;
  final String? nombre;
  final int? grado;
  final String? turno;
  final String? cicloId;

  const Group({
    required this.id,
    this.nombre,
    this.grado,
    this.turno,
    this.cicloId,
  });

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'] as String,
        nombre: json['nombre'] as String?,
        grado: json['grado'] as int?,
        turno: json['turno'] as String?,
        cicloId: json['ciclo_id'] as String?,
      );
}
