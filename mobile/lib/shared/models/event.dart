class Event {
  final String id;
  final String? titulo;
  final String? descripcion;
  final String? tipo;
  final String? fechaInicio;
  final String? fechaFin;

  const Event({
    required this.id,
    this.titulo,
    this.descripcion,
    this.tipo,
    this.fechaInicio,
    this.fechaFin,
  });

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        id: json['id'] as String,
        titulo: json['titulo'] as String?,
        descripcion: json['descripcion'] as String?,
        tipo: json['tipo'] as String?,
        fechaInicio: json['fecha_inicio'] as String?,
        fechaFin: json['fecha_fin'] as String?,
      );
}
