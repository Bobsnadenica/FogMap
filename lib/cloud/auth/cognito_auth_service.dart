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

  AuthSession? _currentSession;
  AuthSession? get currentSession => _currentSession;
  bool get isSignedIn => _currentSession != null && !_currentSession!.isExpired;

  Future<void> init() async {
    final email = await _storage.read(key: _emailKey);
    final idToken = await _storage.read(key: _idTokenKey);
    final accessToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    final groupsRaw = await _storage.read(key: _groupsKey);
    final expRaw = await _storage.read(key: _expKey);

    if (email == null ||
        idToken == null ||
        accessToken == null ||
        refreshToken == null ||
        expRaw == null) {
      _currentSession = null;
      return;
    }

    final groups = groupsRaw == null || groupsRaw.isEmpty
        ? <String>[]
        : (jsonDecode(groupsRaw) as List<dynamic>)
            .map((e) => e.toString())
            .toList();

    final exp = int.tryParse(expRaw) ?? 0;
    final restored = AuthSession(
      email: email,
      idToken: idToken,
      accessToken: accessToken,
      refreshToken: refreshToken,
      groups: groups,
      expiresAtEpochSeconds: exp,
    );

    if (restored.isExpired) {
      await signOut();
      return;
    }

    _currentSession = restored;
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
      throw Exception('Cognito sign-in did not return a user session.');
    }

    final String idToken = session.getIdToken().getJwtToken() ?? '';
    final String accessToken = session.getAccessToken().getJwtToken() ?? '';
    final String refreshToken = session.getRefreshToken()?.getToken() ?? '';

    if (idToken.isEmpty || accessToken.isEmpty) {
      throw Exception('Cognito sign-in returned empty tokens.');
    }

    final groups = _extractGroups(idToken);
    final exp = _extractExp(idToken);

    final authSession = AuthSession(
      email: email.trim(),
      idToken: idToken,
      accessToken: accessToken,
      refreshToken: refreshToken,
      groups: groups,
      expiresAtEpochSeconds: exp,
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
    if (!isSignedIn) return null;
    return _currentSession!.idToken;
  }

  Future<void> _persist(AuthSession session) async {
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

  Map<String, dynamic> _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return <String, dynamic>{};
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    return Map<String, dynamic>.from(jsonDecode(decoded) as Map);
  }
}