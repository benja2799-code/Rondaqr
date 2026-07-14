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
  String? get lastNotice {
    if (supabaseService.isConfigured) {
      return _lastNotice;
    }

    return _lastNotice ?? localFallback.lastNotice;
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    _lastNotice = null;

    final SupabaseClient? client = supabaseService.client;
    if (!supabaseService.isConfigured || client == null) {
      if (supabaseService.isConfigured) {
        throw const AuthenticationException(
          'Se requiere conexión a internet para usar RondaQR v2.0.',
        );
      }

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

      return await loadProfileForAuthUser(client, authUser);
    } on AuthenticationException {
      rethrow;
    } on AuthException catch (error) {
      if (_isCredentialError(error)) {
        throw const AuthenticationException('Correo o contraseña incorrectos.');
      }

      debugPrint('Login Supabase no disponible: $error');
      if (!supabaseService.isLikelyNetworkError(error)) {
        throw const AuthenticationException(
          'No fue posible iniciar sesión en Supabase.',
        );
      }
      if (!supabaseService.isLikelyNetworkError(error)) {
        throw const AuthenticationException(
          'No fue posible iniciar sesión en Supabase.',
        );
      }
      throw const AuthenticationException(
        'Se requiere conexión a internet para usar RondaQR v2.0.',
      );
    } catch (error) {
      debugPrint('Login Supabase no disponible: $error');
      throw const AuthenticationException(
        'Se requiere conexión a internet para usar RondaQR v2.0.',
      );
    }
  }

  @override
  Future<AppUser?> restoreUser(String userId) async {
    _lastNotice = null;

    final SupabaseClient? client = supabaseService.client;
    if (!supabaseService.isConfigured || client == null) {
      if (supabaseService.isConfigured) {
        _lastNotice =
            'Sin conexión. Esta versión conectada requiere internet para registrar datos.';
        return null;
      }

      return localFallback.restoreUser(userId);
    }

    try {
      final User? authUser = client.auth.currentUser;
      if (authUser == null || authUser.id != userId) {
        return null;
      }

      return await loadProfileForAuthUser(client, authUser);
    } catch (error) {
      debugPrint('No fue posible restaurar perfil Supabase: $error');
      _lastNotice =
          'Sin conexión. Esta versión conectada requiere internet para registrar datos.';
      return null;
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

    if (!supabaseService.isConfigured) {
      await localFallback.signOut();
    }
  }

  Future<AppUser> loadProfileForAuthUser(
    SupabaseClient client,
    User authUser,
  ) async {
    final Map<String, dynamic> profile = await _loadSingleRow(
      client.from('profiles').select('*').eq('id', authUser.id).limit(1),
      missingMessage: 'No existe perfil vinculado para este usuario.',
    );

    final String installationId = readSupabaseText(profile, 'installation_id');
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

    return appUserFromSupabaseProfile(
      profile: profile,
      authUser: authUser,
      installation: installation,
    );
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
}

AppUser appUserFromSupabaseProfile({
  required Map<String, dynamic> profile,
  required User? authUser,
  required Map<String, dynamic> installation,
}) {
  final AppRole role = parseSupabaseRole(readSupabaseText(profile, 'role'));
  final String shiftCode = readSupabaseText(profile, 'assigned_shift_code');
  final String normalizedShiftId = normalizeSupabaseShiftId(shiftCode);
  final String shiftDisplay = shiftDisplayForSupabaseCode(shiftCode);
  final String profileEmail = readSupabaseText(profile, 'email');
  final String installationName = firstSupabaseText(installation, [
    'name',
    'installation_name',
    'display_name',
  ]);
  final String company = firstSupabaseText(installation, [
    'company',
    'company_name',
    'business_name',
  ]);
  final String authUserId = authUser?.id ?? readSupabaseText(profile, 'id');
  final String authEmail = authUser?.email ?? '';
  final String fullName = readSupabaseText(profile, 'full_name');

  return AppUser(
    id: authUserId,
    email: profileEmail.isNotEmpty ? profileEmail : authEmail,
    displayName: fullName.isNotEmpty
        ? fullName
        : profileEmail.isNotEmpty
        ? profileEmail
        : authEmail.isNotEmpty
        ? authEmail
        : 'Usuario Supabase',
    identifier: authUserId,
    jobTitle: readSupabaseText(profile, 'position').isNotEmpty
        ? readSupabaseText(profile, 'position')
        : role.label,
    installationId: readSupabaseText(profile, 'installation_id'),
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

AppRole parseSupabaseRole(String value) {
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

  if (normalized == 'supervisor') {
    return AppRole.supervisor;
  }

  throw const AuthenticationException(
    'El perfil no tiene un rol válido en Supabase.',
  );
}

String normalizeSupabaseShiftId(String code) {
  final String normalized = code.trim().toLowerCase();

  if (normalized == 'day' ||
      normalized == 'dia' ||
      normalized == 'día' ||
      normalized.contains('day')) {
    return 'shift_day';
  }

  if (normalized == 'night' ||
      normalized == 'noche' ||
      normalized.contains('night')) {
    return 'shift_night';
  }

  return code.trim();
}

String shiftDisplayForSupabaseCode(String code) {
  final String normalized = code.trim().toLowerCase();

  if (normalized == 'day' ||
      normalized == 'dia' ||
      normalized == 'día' ||
      normalized.contains('day')) {
    return 'Turno Día · 08:00 - 20:00';
  }

  if (normalized == 'night' ||
      normalized == 'noche' ||
      normalized.contains('night')) {
    return 'Turno Noche · 20:00 - 08:00';
  }

  return code.trim().isEmpty ? 'Sin turno asignado' : code.trim();
}

String readSupabaseText(Map<String, dynamic> json, String key) {
  final dynamic value = json[key];
  return value == null ? '' : value.toString().trim();
}

String firstSupabaseText(Map<String, dynamic> json, List<String> keys) {
  for (final String key in keys) {
    final String value = readSupabaseText(json, key);
    if (value.isNotEmpty) {
      return value;
    }
  }

  return '';
}
