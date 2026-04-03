class UserSummary {
  final String id;
  final String? nombre;
  final String? apellidoPaterno;
  final String? apellidoMaterno;
  final List<String> roles;

  const UserSummary({
    required this.id,
    this.nombre,
    this.apellidoPaterno,
    this.apellidoMaterno,
    this.roles = const [],
  });

  String get nombreCompleto => [nombre, apellidoPaterno, apellidoMaterno]
      .where((s) => s != null && s.isNotEmpty)
      .join(' ');

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
        id: json['id'] as String,
        nombre: json['nombre'] as String?,
        apellidoPaterno: json['apellido_paterno'] as String?,
        apellidoMaterno: json['apellido_materno'] as String?,
        roles: (json['roles'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}
