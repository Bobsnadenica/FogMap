class AuthSession {
  const AuthSession({
    required this.email,
    required this.idToken,
    required this.accessToken,
    required this.refreshToken,
    required this.groups,
    required this.expiresAtEpochSeconds,
  });

  final String email;
  final String idToken;
  final String accessToken;
  final String refreshToken;
  final List<String> groups;
  final int expiresAtEpochSeconds;

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch >= expiresAtEpochSeconds * 1000;

  bool get isAdminOrModerator =>
      groups.contains('admin') || groups.contains('moderator');
}