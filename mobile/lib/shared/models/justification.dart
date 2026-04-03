class Justification {
  final String id;
  final String? studentId;
  final String? fechaInicio;
  final String? fechaFin;
  final String? motivo;
  final String? archivoUrl;
  final String? status;
  final String? reviewedBy;
  final String? createdAt;

  const Justification({
    required this.id,
    this.studentId,
    this.fechaInicio,
    this.fechaFin,
    this.motivo,
    this.archivoUrl,
    this.status,
    this.reviewedBy,
    this.createdAt,
  });

  factory Justification.fromJson(Map<String, dynamic> json) => Justification(
        id: json['id'] as String,
        studentId: json['student_id'] as String?,
        fechaInicio: json['fecha_inicio'] as String?,
        fechaFin: json['fecha_fin'] as String?,
        motivo: json['motivo'] as String?,
        archivoUrl: json['archivo_url'] as String?,
        status: json['status'] as String?,
        reviewedBy: json['reviewed_by'] as String?,
        createdAt: json['created_at'] as String?,
      );
}
