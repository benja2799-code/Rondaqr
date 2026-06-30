import 'package:flutter/foundation.dart';

class UserConfiguration {
  final String guardName;
  final String identifier;
  final String installationName;
  final String company;
  final String shift;
  final String role;

  const UserConfiguration({
    required this.guardName,
    required this.identifier,
    required this.installationName,
    required this.company,
    required this.shift,
    required this.role,
  });

  const UserConfiguration.empty()
    : guardName = '',
      identifier = '',
      installationName = '',
      company = '',
      shift = '',
      role = '';

  bool get isComplete {
    return guardName.isNotEmpty &&
        identifier.isNotEmpty &&
        installationName.isNotEmpty &&
        company.isNotEmpty &&
        shift.isNotEmpty &&
        role.isNotEmpty;
  }

  String get guardNameDisplay {
    return _displayValue(guardName, 'Guardia sin configurar');
  }

  String get identifierDisplay {
    return _displayValue(identifier, 'Sin identificar');
  }

  String get installationNameDisplay {
    return _displayValue(installationName, 'Instalación sin configurar');
  }

  String get companyDisplay {
    return _displayValue(company, 'Empresa sin configurar');
  }

  String get shiftDisplay {
    return _displayValue(shift, 'Turno sin configurar');
  }

  String get roleDisplay {
    return _displayValue(role, 'Cargo sin configurar');
  }

  String _displayValue(String value, String fallback) {
    return value.trim().isEmpty ? fallback : value.trim();
  }
}

class UserConfigurationStore extends ChangeNotifier {
  UserConfigurationStore._internal();

  static final UserConfigurationStore instance =
      UserConfigurationStore._internal();

  UserConfiguration _configuration = const UserConfiguration.empty();
  bool _initialized = false;

  Future<void> Function(UserConfiguration configuration)?
  onConfigurationChanged;

  UserConfiguration get configuration {
    return _configuration;
  }

  bool get initialized {
    return _initialized;
  }

  void loadConfiguration(UserConfiguration? savedConfiguration) {
    _configuration = savedConfiguration ?? const UserConfiguration.empty();
    _initialized = true;
    notifyListeners();
  }

  Future<void> saveConfiguration(UserConfiguration configuration) async {
    final saveFunction = onConfigurationChanged;

    if (saveFunction == null) {
      throw StateError(
        'No existe una función de guardado para la configuración.',
      );
    }

    await saveFunction(configuration);

    _configuration = configuration;
    _initialized = true;
    notifyListeners();
  }
}
