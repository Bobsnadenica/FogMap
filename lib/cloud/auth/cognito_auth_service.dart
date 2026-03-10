import 'dart:convert';

import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../backend_config.dart';
import 'auth_session.dart';

class CognitoAuthService {
  CognitoAuthService()
      : _userPool = CognitoUserPool(
          BackendConfig.cognitoUserPoolId,
          BackendConfig.cognitoUserPoolClientId,
        );

  final CognitoUserPool _userPool;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _emailKey = 'cognito_email';
  static const _idTokenKey = 'cognito_id_token';
  static const _accessTokenKey = 'cognito_access_token';
  static const _refreshTokenKey = 'cognito_refresh_token';
  static const _groupsKey = 'cognito_groups';
  static const _expKey = 'cognito_exp';
  static const _userIdKey = 'cognito_user_id';
  static const _displayNameOverrideKey = 'cognito_display_name_override';
  static const _displayNameLockedKey = 'cognito_display_name_locked';

  AuthSession? _currentSession;
  String? _displayNameOverride;
  bool _displayNameLockedOverride = false;

  AuthSession? get currentSession => _currentSession;

  bool get isSignedIn => _currentSession != null && !_currentSession!.isExpired;

  Future<void> init() async {
    final email = await _storage.read(key: _emailKey);
    final idToken = await _storage.read(key: _idTokenKey);
    final accessToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    final groupsRaw = await _storage.read(key: _groupsKey);
    final expRaw = await _storage.read(key: _expKey);
    final userId = await _storage.read(key: _userIdKey);
    final displayNameOverride = await _storage.read(
      key: _displayNameOverrideKey,
    );
    final displayNameLocked = await _storage.read(key: _displayNameLockedKey);

    if (email == null ||
        userId == null ||
        idToken == null ||
        accessToken == null ||
        refreshToken == null ||
        expRaw == null) {
      _currentSession = null;
      _displayNameOverride = null;
      _displayNameLockedOverride = false;
      return;
    }

    _displayNameOverride = displayNameOverride?.trim().isEmpty == true
        ? null
        : displayNameOverride?.trim();
    _displayNameLockedOverride = displayNameLocked == 'true';

    final groups = groupsRaw == null || groupsRaw.isEmpty
        ? <String>[]
        : (jsonDecode(groupsRaw) as List<dynamic>)
            .map((e) => e.toString())
            .toList();

    final exp = int.tryParse(expRaw) ?? 0;

    _currentSession = AuthSession(
      userId: userId,
      email: email,
      idToken: idToken,
      accessToken: accessToken,
      refreshToken: refreshToken,
      groups: groups,
      expiresAtEpochSeconds: exp,
    );

    if (_currentSession!.isExpired) {
      try {
        await _refreshSession();
      } catch (_) {
        await signOut();
      }
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _userPool.signUp(
      email.trim(),
      password,
      userAttributes: [
        AttributeArg(name: 'custom:display_name', value: displayName.trim()),
      ],
    );
  }

  Future<void> confirmSignUp({
    required String email,
    required String code,
  }) async {
    final user = CognitoUser(email.trim(), _userPool);
    await user.confirmRegistration(code.trim());
  }

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final user = CognitoUser(email.trim(), _userPool);
    final authDetails = AuthenticationDetails(
      username: email.trim(),
      password: password,
    );

    final CognitoUserSession? session =
        await user.authenticateUser(authDetails);

    if (session == null) {
      throw Exception('Cognito sign-in did not return a session.');
    }

    final authSession = _sessionFromCognitoSession(
      email: email.trim(),
      session: session,
      fallbackRefreshToken: '',
    );

    await _persist(authSession);
    _currentSession = authSession;
    return authSession;
  }

  Future<void> signOut() async {
    _currentSession = null;
    await _storage.deleteAll();
  }

  Future<String?> getIdToken() async {
    await ensureValidSession();
    return _currentSession?.idToken;
  }

  String? get currentUserId => _currentSession?.userId;

  String? get currentDisplayName {
    final current = _currentSession;
    if (current == null) return null;

    final override = _displayNameOverride?.trim();
    if (override != null && override.isNotEmpty) {
      return override;
    }

    try {
      final payload = _decodeJwtPayload(current.idToken);
      final customDisplayName =
          payload['custom:display_name']?.toString().trim();
      if (customDisplayName != null && customDisplayName.isNotEmpty) {
        return customDisplayName;
      }

      final name = payload['name']?.toString().trim();
      if (name != null && name.isNotEmpty) {
        return name;
      }
    } catch (_) {
      // Fall back to the signed-in email below.
    }

    return current.email;
  }

  bool get isDisplayNameLocked {
    final current = _currentSession;
    if (current == null) return false;
    return _displayNameLockedOverride || _extractDisplayNameLocked(current.idToken);
  }

  Future<String> updateDisplayNameOnce(String displayName) async {
    final current = _currentSession;
    final normalized = displayName.trim();

    if (current == null) {
      throw Exception('Please sign in before updating your display name.');
    }
    if (normalized.length < 3 || normalized.length > 80) {
      throw Exception('Display name must be between 3 and 80 characters.');
    }
    if (isDisplayNameLocked) {
      throw Exception('Display name can only be changed once.');
    }

    final user = CognitoUser(
      current.email,
      _userPool,
      signInUserSession: _toCognitoUserSession(current),
    );

    final updated = await user.updateAttributes([
      CognitoUserAttribute(name: 'custom:display_name', value: normalized),
      CognitoUserAttribute(name: 'custom:display_name_locked', value: 'true'),
    ]);

    if (!updated) {
      throw Exception('Display name update failed.');
    }

    _displayNameOverride = normalized;
    _displayNameLockedOverride = true;
    await _storage.write(key: _displayNameOverrideKey, value: normalized);
    await _storage.write(key: _displayNameLockedKey, value: 'true');

    try {
      await _refreshSession();
    } catch (_) {
      // Keep the local override if Cognito token refresh is delayed.
    }

    return normalized;
  }

  Future<void> ensureValidSession() async {
    if (_currentSession == null) return;
    if (!_currentSession!.isExpired) return;
    await _refreshSession();
  }

  Future<void> _refreshSession() async {
    final current = _currentSession;
    if (current == null) {
      throw Exception('No session available to refresh.');
    }
    if (current.refreshToken.isEmpty) {
      throw Exception('No refresh token available.');
    }

    final user = CognitoUser(current.email, _userPool);
    final refreshToken = CognitoRefreshToken(current.refreshToken);
    final CognitoUserSession? refreshed =
        await user.refreshSession(refreshToken);

    if (refreshed == null) {
      throw Exception('Failed to refresh Cognito session.');
    }

    final next = _sessionFromCognitoSession(
      email: current.email,
      session: refreshed,
      fallbackRefreshToken: current.refreshToken,
    );

    await _persist(next);
    _currentSession = next;
  }

  AuthSession _sessionFromCognitoSession({
    required String email,
    required CognitoUserSession session,
    required String fallbackRefreshToken,
  }) {
    final idToken = session.getIdToken().getJwtToken() ?? '';
    final accessToken = session.getAccessToken().getJwtToken() ?? '';
    final refreshToken =
        session.getRefreshToken()?.getToken() ?? fallbackRefreshToken;

    if (idToken.isEmpty || accessToken.isEmpty) {
      throw Exception('Cognito session returned empty tokens.');
    }

    final groups = _extractGroups(idToken);
    final exp = _extractExp(idToken);
    final userId = _extractSub(idToken);

    return AuthSession(
      userId: userId,
      email: email,
      idToken: idToken,
      accessToken: accessToken,
      refreshToken: refreshToken,
      groups: groups,
      expiresAtEpochSeconds: exp,
    );
  }

  Future<void> _persist(AuthSession session) async {
    await _storage.write(key: _userIdKey, value: session.userId);
    await _storage.write(key: _emailKey, value: session.email);
    await _storage.write(key: _idTokenKey, value: session.idToken);
    await _storage.write(key: _accessTokenKey, value: session.accessToken);
    await _storage.write(key: _refreshTokenKey, value: session.refreshToken);
    await _storage.write(key: _groupsKey, value: jsonEncode(session.groups));
    await _storage.write(
      key: _expKey,
      value: session.expiresAtEpochSeconds.toString(),
    );
  }

  List<String> _extractGroups(String jwt) {
    final payload = _decodeJwtPayload(jwt);
    final raw = payload['cognito:groups'];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return <String>[];
  }

  int _extractExp(String jwt) {
    final payload = _decodeJwtPayload(jwt);
    final exp = payload['exp'];
    if (exp is int) return exp;
    if (exp is num) return exp.toInt();
    return 0;
  }

  String _extractSub(String jwt) {
    final payload = _decodeJwtPayload(jwt);
    final sub = payload['sub'];
    if (sub is String && sub.isNotEmpty) return sub;
    throw Exception('Cognito token payload did not include a valid sub.');
  }

  bool _extractDisplayNameLocked(String jwt) {
    final payload = _decodeJwtPayload(jwt);
    final raw = payload['custom:display_name_locked'];
    if (raw is bool) return raw;
    if (raw is String) return raw.toLowerCase() == 'true';
    return false;
  }

  CognitoUserSession _toCognitoUserSession(AuthSession session) {
    return CognitoUserSession(
      CognitoIdToken(session.idToken),
      CognitoAccessToken(session.accessToken),
      refreshToken: CognitoRefreshToken(session.refreshToken),
    );
  }

  Map<String, dynamic> _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return <String, dynamic>{};
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    return Map<String, dynamic>.from(jsonDecode(decoded) as Map);
  }
}
