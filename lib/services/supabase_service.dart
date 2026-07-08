import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService extends ChangeNotifier {
  SupabaseService._internal();

  static final SupabaseService instance = SupabaseService._internal();

  static const String _environmentUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _environmentPublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  bool _initialized = false;
  bool _initializationAttempted = false;
  String? _initializationError;
  SupabaseClient? _client;

  bool get isConfigured {
    return _cleanEnvironmentValue(_environmentUrl).isNotEmpty &&
        _cleanEnvironmentValue(_environmentPublishableKey).isNotEmpty;
  }

  bool get isInitialized => _initialized;
  bool get initializationAttempted => _initializationAttempted;
  String? get initializationError => _initializationError;
  SupabaseClient? get client => _client;

  String get modeLabel {
    if (!isConfigured) {
      return 'Modo local';
    }

    if (_initialized) {
      return 'Supabase conectado';
    }

    return 'Supabase no disponible';
  }

  Future<void> initialize() async {
    if (_initializationAttempted) {
      return;
    }

    _initializationAttempted = true;

    if (!isConfigured) {
      _initialized = false;
      _client = null;
      notifyListeners();
      return;
    }

    try {
      await Supabase.initialize(
        url: _cleanEnvironmentValue(_environmentUrl),
        publishableKey: _cleanEnvironmentValue(_environmentPublishableKey),
      );

      _client = Supabase.instance.client;
      _initialized = true;
      _initializationError = null;
    } catch (error) {
      debugPrint('No fue posible inicializar Supabase: $error');
      _client = null;
      _initialized = false;
      _initializationError = error.toString();
    }

    notifyListeners();
  }

  static String _cleanEnvironmentValue(String value) {
    String result = value.trim();

    if (result.startsWith('[') && result.endsWith(']')) {
      result = result.substring(1, result.length - 1).trim();
    }

    if (result.startsWith('(') && result.endsWith(')')) {
      result = result.substring(1, result.length - 1).trim();
    }

    if (result.endsWith('/') && result.startsWith('http')) {
      result = result.substring(0, result.length - 1);
    }

    return result;
  }
}
