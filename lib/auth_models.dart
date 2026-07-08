enum AppRole { administrator, guard }

enum AppPermission {
  manageRounds,
  scanQr,
  viewHistory,
  viewReports,
  viewNovelties,
  viewProfile,
  manageUsers,
  manageInstallations,
  manageControlPoints,
}

extension AppRoleAccess on AppRole {
  String get label {
    return switch (this) {
      AppRole.administrator => 'Administrador',
      AppRole.guard => 'Guardia',
    };
  }

  Set<AppPermission> get permissions {
    return switch (this) {
      AppRole.administrator => Set<AppPermission>.from(AppPermission.values),
      AppRole.guard => {
        AppPermission.manageRounds,
        AppPermission.scanQr,
        AppPermission.viewHistory,
        AppPermission.viewProfile,
      },
    };
  }

  bool can(AppPermission permission) {
    return permissions.contains(permission);
  }
}

class AppUser {
  final String id;
  final String email;
  final String displayName;
  final String identifier;
  final String jobTitle;
  final String installationId;
  final String installationName;
  final String company;
  final String shiftId;
  final String shift;
  final AppRole role;
  final bool isActive;

  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.identifier,
    required this.jobTitle,
    required this.installationId,
    required this.installationName,
    required this.company,
    this.shiftId = '',
    required this.shift,
    required this.role,
    this.isActive = true,
  });

  bool can(AppPermission permission) {
    return isActive && role.can(permission);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'identifier': identifier,
      'jobTitle': jobTitle,
      'installationId': installationId,
      'installationName': installationName,
      'company': company,
      'shiftId': shiftId,
      'shift': shift,
      'role': role.name,
      'isActive': isActive,
    };
  }

  static AppUser? fromJson(Map<String, dynamic> json) {
    String readText(String key) {
      final dynamic value = json[key];
      return value is String ? value.trim() : '';
    }

    final String id = readText('id');
    final String email = readText('email');
    final String displayName = readText('displayName');
    final String roleName = readText('role');
    AppRole? role;

    for (final AppRole candidate in AppRole.values) {
      if (candidate.name == roleName) {
        role = candidate;
        break;
      }
    }

    if (id.isEmpty || email.isEmpty || displayName.isEmpty || role == null) {
      return null;
    }

    return AppUser(
      id: id,
      email: email,
      displayName: displayName,
      identifier: readText('identifier'),
      jobTitle: readText('jobTitle'),
      installationId: readText('installationId'),
      installationName: readText('installationName'),
      company: readText('company'),
      shiftId: readText('shiftId'),
      shift: readText('shift'),
      role: role,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? identifier,
    String? jobTitle,
    String? installationId,
    String? installationName,
    String? company,
    String? shiftId,
    String? shift,
    AppRole? role,
    bool? isActive,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      identifier: identifier ?? this.identifier,
      jobTitle: jobTitle ?? this.jobTitle,
      installationId: installationId ?? this.installationId,
      installationName: installationName ?? this.installationName,
      company: company ?? this.company,
      shiftId: shiftId ?? this.shiftId,
      shift: shift ?? this.shift,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
    );
  }
}

class LocalUserAccount {
  final AppUser user;
  final String password;

  const LocalUserAccount({required this.user, required this.password});

  Map<String, dynamic> toJson() {
    return {'user': user.toJson(), 'password': password};
  }

  static LocalUserAccount? fromJson(Map<String, dynamic> json) {
    final dynamic userData = json['user'];
    final String password = json['password'] is String
        ? (json['password'] as String)
        : '';

    if (userData is! Map || password.isEmpty) {
      return null;
    }

    final AppUser? user = AppUser.fromJson(Map<String, dynamic>.from(userData));

    if (user == null) {
      return null;
    }

    return LocalUserAccount(user: user, password: password);
  }

  LocalUserAccount copyWith({AppUser? user, String? password}) {
    return LocalUserAccount(
      user: user ?? this.user,
      password: password ?? this.password,
    );
  }
}

class AppSession {
  final AppUser user;
  final DateTime startedAt;
  final bool persistent;

  const AppSession({
    required this.user,
    required this.startedAt,
    required this.persistent,
  });

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'startedAt': startedAt.toIso8601String(),
      'persistent': persistent,
    };
  }

  static AppSession? fromJson(Map<String, dynamic> json) {
    final dynamic userData = json['user'];
    final DateTime? startedAt = DateTime.tryParse(
      json['startedAt'] as String? ?? '',
    );

    if (userData is! Map || startedAt == null) {
      return null;
    }

    final AppUser? user = AppUser.fromJson(Map<String, dynamic>.from(userData));

    if (user == null) {
      return null;
    }

    return AppSession(
      user: user,
      startedAt: startedAt,
      persistent: json['persistent'] as bool? ?? true,
    );
  }
}
