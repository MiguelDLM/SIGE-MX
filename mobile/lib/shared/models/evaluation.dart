class Evaluation {
  final String id;
  final String? titulo;
  final String? tipo;
  final String? subjectId;
  final String? groupId;

  const Evaluation({
    required this.id,
    this.titulo,
    this.tipo,
    this.subjectId,
    this.groupId,
  });

  factory Evaluation.fromJson(Map<String, dynamic> json) => Evaluation(
        id: json['id'] as String,
        titulo: json['titulo'] as String?,
        tipo: json['tipo'] as String?,
        subjectId: json['subject_id'] as String?,
        groupId: json['group_id'] as String?,
      );
}
