import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth_models.dart';
import '../auth_repository.dart';
import 'supabase_service.dart';

class SupabaseAuthService implements AuthRepository {
  final SupabaseService supabaseService;
  final AuthRepository localFallback;

  String? _lastNotice;

  SupabaseAuthService({
    required this.supabaseService,
    required this.localFallback,
  });

  @override
  String? get lastNotice => _lastNotice ?? localFallback.lastNotice;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    _lastNotice = null;

    final SupabaseClient? client = supabaseService.client;
    if (!supabaseService.isConfigured || client == null) {
      return localFallback.signIn(email: email, password: password);
    }

    try {
      final AuthResponse response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final User? authUser = response.user;

      if (authUser == null) {
        throw const AuthenticationException(
          'No fue posible iniciar sesión en Supabase.',
        );
      }

      return await _loadProfileForAuthUser(client, authUser);
    } on AuthenticationException {
      rethrow;
    } on AuthException catch (error) {
      if (_isCredentialError(error)) {
        throw const AuthenticationException('Correo o contraseña incorrectos.');
      }

      return _signInWithLocalFallback(
        email: email,
        password: password,
        originalError: error,
      );
    } catch (error) {
      return _signInWithLocalFallback(
        email: email,
        password: password,
        originalError: error,
      );
    }
  }

  @override
  Future<AppUser?> restoreUser(String userId) async {
    _lastNotice = null;

    final SupabaseClient? client = supabaseService.client;
    if (!supabaseService.isConfigured || client == null) {
      return localFallback.restoreUser(userId);
    }

    try {
      final User? authUser = client.auth.currentUser;
      if (authUser == null || authUser.id != userId) {
        return await localFallback.restoreUser(userId);
      }

      return await _loadProfileForAuthUser(client, authUser);
    } catch (error) {
      debugPrint('No fue posible restaurar perfil Supabase: $error');
      _lastNotice = 'Sin conexión, usando datos locales.';
      return await localFallback.restoreUser(userId);
    }
  }

  @override
  Future<void> signOut() async {
    _lastNotice = null;
    final SupabaseClient? client = supabaseService.client;
    if (client != null) {
      try {
        await client.auth.signOut();
      } catch (error) {
        debugPrint('No fue posible cerrar sesión Supabase: $error');
      }
    }
    await localFallback.signOut();
  }

  Future<AppUser> _loadProfileForAuthUser(
    SupabaseClient client,
    User authUser,
  ) async {
    final Map<String, dynamic> profile = await _loadSingleRow(
      client
          .from('profiles')
          .select(
            'id, full_name, email, role, position, assigned_shift_code, installation_id',
          )
          .eq('id', authUser.id)
          .limit(1),
      missingMessage: 'No existe perfil vinculado para este usuario.',
    );

    final String installationId = _readText(profile, 'installation_id');
    Map<String, dynamic> installation = {};

    if (installationId.isNotEmpty) {
      try {
        installation = await _loadSingleRow(
          client
              .from('installations')
              .select('*')
              .eq('id', installationId)
              .limit(1),
          missingMessage: 'No existe instalación vinculada al perfil.',
        );
      } catch (error) {
        debugPrint('No fue posible leer instalación Supabase: $error');
      }
    }

    final AppRole role = _parseRole(_readText(profile, 'role'));
    final String shiftCode = _readText(profile, 'assigned_shift_code');
    final String normalizedShiftId = _normalizeShiftId(shiftCode);
    final String shiftDisplay = _shiftDisplayForCode(shiftCode);
    final String profileEmail = _readText(profile, 'email');
    final String installationName = _firstText(installation, [
      'name',
      'installation_name',
      'display_name',
    ]);
    final String company = _firstText(installation, [
      'company',
      'company_name',
      'business_name',
    ]);

    return AppUser(
      id: authUser.id,
      email: profileEmail.isNotEmpty ? profileEmail : authUser.email ?? '',
      displayName: _readText(profile, 'full_name').isNotEmpty
          ? _readText(profile, 'full_name')
          : authUser.email ?? 'Usuario Supabase',
      identifier: authUser.id,
      jobTitle: _readText(profile, 'position').isNotEmpty
          ? _readText(profile, 'position')
          : role.label,
      installationId: installationId,
      installationName: installationName.isNotEmpty
          ? installationName
          : 'Instalación',
      company: company.isNotEmpty ? company : 'LG Seguridad SPA',
      shiftId: normalizedShiftId,
      shift: shiftDisplay,
      role: role,
      isActive: true,
    );
  }

  Future<AppUser> _signInWithLocalFallback({
    required String email,
    required String password,
    required Object originalError,
  }) async {
    try {
      final AppUser localUser = await localFallback.signIn(
        email: email,
        password: password,
      );
      debugPrint('Login Supabase no disponible, usando local: $originalError');
      _lastNotice = 'Sin conexión, usando datos locales.';
      return localUser;
    } on AuthenticationException {
      throw const AuthenticationException(
        'Sin conexión, usando datos locales. Las credenciales locales no coinciden.',
      );
    }
  }

  bool _isCredentialError(AuthException error) {
    final String message = error.message.toLowerCase();
    return message.contains('invalid login') ||
        message.contains('invalid credentials') ||
        message.contains('email not confirmed') ||
        message.contains('invalid email or password');
  }

  Future<Map<String, dynamic>> _loadSingleRow(
    dynamic query, {
    required String missingMessage,
  }) async {
    final dynamic response = await query;
    final List<dynamic> rows = response is List ? response : const [];

    if (rows.isEmpty) {
      throw AuthenticationException(missingMessage);
    }

    final dynamic first = rows.first;
    if (first is! Map) {
      throw AuthenticationException(missingMessage);
    }

    return Map<String, dynamic>.from(first);
  }

  AppRole _parseRole(String value) {
    final String normalized = value.trim().toLowerCase();

    if (normalized == 'administrator' ||
        normalized == 'admin' ||
        normalized == 'administrador') {
      return AppRole.administrator;
    }

    if (normalized == 'guard' ||
        normalized == 'guardia' ||
        normalized == 'security_guard') {
      return AppRole.guard;
    }

    throw const AuthenticationException(
      'El perfil no tiene un rol válido en Supabase.',
    );
  }

  String _normalizeShiftId(String code) {
    final String normalized = code.trim().toLowerCase();

    if (normalized.contains('day') || normalized.contains('dia')) {
      return 'shift_day';
    }

    if (normalized.contains('night') || normalized.contains('noche')) {
      return 'shift_night';
    }

    return code.trim();
  }

  String _shiftDisplayForCode(String code) {
    final String normalized = code.trim().toLowerCase();

    if (normalized.contains('day') || normalized.contains('dia')) {
      return 'Turno Día · 08:00 - 20:00';
    }

    if (normalized.contains('night') || normalized.contains('noche')) {
      return 'Turno Noche · 20:00 - 08:00';
    }

    return code.trim().isEmpty ? 'Sin turno asignado' : code.trim();
  }

  String _readText(Map<String, dynamic> json, String key) {
    final dynamic value = json[key];
    return value == null ? '' : value.toString().trim();
  }

  String _firstText(Map<String, dynamic> json, List<String> keys) {
    for (final String key in keys) {
      final String value = _readText(json, key);
      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }
}
