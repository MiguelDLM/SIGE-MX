class Grade {
  final String id;
  final String? evaluationId;
  final String? studentId;
  final String? calificacion;

  const Grade({
    required this.id,
    this.evaluationId,
    this.studentId,
    this.calificacion,
  });

  double? get calificacionDouble =>
      calificacion != null ? double.tryParse(calificacion!) : null;

  factory Grade.fromJson(Map<String, dynamic> json) => Grade(
        id: json['id'] as String,
        evaluationId: json['evaluation_id'] as String?,
        studentId: json['student_id'] as String?,
        calificacion: json['calificacion']?.toString(),
      );
}
