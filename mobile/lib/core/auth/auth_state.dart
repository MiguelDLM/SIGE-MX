sealed class AuthState {
  const AuthState();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final String userId;
  final List<String> roles;
  final String primaryRole;
  final bool mustChangePassword;

  const AuthAuthenticated({
    required this.userId,
    required this.roles,
    required this.primaryRole,
    this.mustChangePassword = false,
  });
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}
