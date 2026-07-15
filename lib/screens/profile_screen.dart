import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_routes.dart';
import '../app_info.dart';
import '../auth_models.dart';
import '../services/supabase_service.dart';
import '../session_store.dart';
import '../user_configuration.dart';
import '../work_shifts.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const Color azulOscuro = Color(0xFF061B44);
  static const Color azulMedio = Color(0xFF073C85);
  static const Color azulPrincipal = Color(0xFF0866FF);
  static const Color fondo = Color(0xFFF4F7FB);
  static const Color rojo = Color(0xFFD92D20);

  String _formatTime(DateTime value) {
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void cerrarSesion(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: rojo),
              SizedBox(width: 10),
              Expanded(child: Text('Cerrar sesión')),
            ],
          ),
          content: const Text('¿Estás seguro de que deseas cerrar la sesión?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await SessionStore.instance.signOut();

                  if (!dialogContext.mounted || !context.mounted) {
                    return;
                  }

                  Navigator.pop(dialogContext);
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                    (route) => false,
                  );
                } catch (_) {
                  if (!dialogContext.mounted || !context.mounted) {
                    return;
                  }

                  Navigator.pop(dialogContext);
                  mostrarMensaje(
                    context,
                    'No fue posible cerrar la sesión. Intenta nuevamente.',
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: rojo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );
  }

  void mostrarMensaje(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> editarInformacion(BuildContext context) async {
    final Object? saved = await Navigator.pushNamed(
      context,
      AppRoutes.editInstallation,
    );

    if (saved == true && context.mounted) {
      mostrarMensaje(context, 'La información fue guardada correctamente.');
    }
  }

  void abrirPuntosDeControl(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.controlPoints);
  }

  void abrirUsuarios(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.users);
  }

  Future<void> cambiarContrasena(BuildContext context) async {
    if (!SupabaseService.instance.onlineMode) {
      mostrarMensaje(
        context,
        'El cambio de contraseña está disponible en modo Supabase.',
      );
      return;
    }

    final AppUser? user = SessionStore.instance.currentUser;
    if (user == null || user.email.isEmpty) {
      mostrarMensaje(context, 'No existe una sesión activa.');
      return;
    }

    final bool? changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return _ChangePasswordDialog(user: user);
      },
    );

    if (changed != true || !context.mounted) {
      return;
    }

    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contraseña actualizada. Inicia sesión nuevamente.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UserConfigurationStore configurationStore =
        UserConfigurationStore.instance;
    final SessionStore sessionStore = SessionStore.instance;
    final WorkShiftStore shiftStore = WorkShiftStore.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([
        configurationStore,
        sessionStore,
        shiftStore,
      ]),
      builder: (context, _) {
        final UserConfiguration configuration =
            configurationStore.configuration;
        final AppUser? user = sessionStore.currentUser;
        final String displayName = user?.displayName ?? 'Usuario';
        final String jobTitle = user?.jobTitle ?? 'Cargo sin configurar';
        final String installation =
            user?.installationName ?? configuration.installationNameDisplay;
        final String company = user?.company ?? configuration.companyDisplay;
        final ShiftDefinition? assignedShift = user == null
            ? null
            : shiftStore.definitionForUser(user);
        final WorkShiftRecord? activeShift = user == null
            ? null
            : shiftStore.activeForUser(user.id);
        final String shift =
            assignedShift?.displayName ?? user?.shift ?? 'Turno sin configurar';
        final String identifier =
            user?.identifier ?? configuration.identifierDisplay;
        final String role = user?.role.label ?? 'Sin rol';
        final bool canManageUsers = sessionStore.can(AppPermission.manageUsers);
        final bool canManageInstallations = sessionStore.can(
          AppPermission.manageInstallations,
        );
        final bool canManageControlPoints = sessionStore.can(
          AppPermission.manageControlPoints,
        );

        return Scaffold(
          backgroundColor: fondo,
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [azulOscuro, azulMedio],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Mi perfil',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F6FFF), azulMedio],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: azulPrincipal.withValues(alpha: 0.25),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 92,
                                height: 92,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 58,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                displayName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 23,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                jobTitle,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  role,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 15,
                                offset: const Offset(0, 7),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _ProfileInfoRow(
                                icon: Icons.apartment_rounded,
                                label: 'Instalación',
                                value: installation,
                              ),
                              const Divider(height: 28),
                              _ProfileInfoRow(
                                icon: Icons.business_rounded,
                                label: 'Empresa',
                                value: company,
                              ),
                              const Divider(height: 28),
                              _ProfileInfoRow(
                                icon: Icons.access_time_rounded,
                                label: 'Turno',
                                value: shift,
                              ),
                              if (user?.role == AppRole.guard) ...[
                                const Divider(height: 28),
                                _ProfileInfoRow(
                                  icon: Icons.login_rounded,
                                  label: 'Estado del turno',
                                  value: activeShift == null
                                      ? 'Turno no iniciado'
                                      : 'Activo desde ${_formatTime(activeShift.actualStartedAt)}',
                                ),
                              ],
                              const Divider(height: 28),
                              _ProfileInfoRow(
                                icon: Icons.badge_outlined,
                                label: 'Identificador o RUT',
                                value: identifier,
                              ),
                              const Divider(height: 28),
                              _ProfileInfoRow(
                                icon: Icons.work_outline_rounded,
                                label: 'Cargo',
                                value: jobTitle,
                              ),
                              const Divider(height: 28),
                              _ProfileInfoRow(
                                icon: Icons.admin_panel_settings_outlined,
                                label: 'Rol de acceso',
                                value: role,
                              ),
                            ],
                          ),
                        ),
                        if (canManageUsers ||
                            canManageInstallations ||
                            canManageControlPoints) ...[
                          const SizedBox(height: 22),
                          if (canManageUsers) ...[
                            _ProfileOption(
                              icon: Icons.manage_accounts_outlined,
                              title: 'Guardias y turnos',
                              subtitle:
                                  'Configura cuentas, roles y horarios locales',
                              onTap: () {
                                abrirUsuarios(context);
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (canManageInstallations) ...[
                            _ProfileOption(
                              icon: Icons.apartment_rounded,
                              title: 'Configuración de instalación',
                              subtitle:
                                  'Actualiza los datos operativos y de empresa',
                              onTap: () {
                                editarInformacion(context);
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (canManageControlPoints)
                            _ProfileOption(
                              icon: Icons.location_on_outlined,
                              title: 'Puntos de control',
                              subtitle:
                                  'Crea y administra los puntos de la ronda',
                              onTap: () {
                                abrirPuntosDeControl(context);
                              },
                            ),
                        ],
                        const SizedBox(height: 12),
                        _ProfileOption(
                          icon: Icons.lock_outline_rounded,
                          title: 'Cambiar contraseña',
                          subtitle: 'Actualiza tu contraseña de acceso',
                          onTap: () {
                            cambiarContrasena(context);
                          },
                        ),
                        const SizedBox(height: 12),
                        _ProfileOption(
                          icon: Icons.help_outline_rounded,
                          title: 'Ayuda',
                          subtitle: 'Consulta información sobre la aplicación',
                          onTap: () {
                            Navigator.pushNamed(context, AppRoutes.help);
                          },
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<String>(
                          future: RondaQrAppInfo.version,
                          builder: (context, snapshot) {
                            return _ProfileOption(
                              icon: Icons.info_outline_rounded,
                              title: 'Acerca de RondaQR',
                              subtitle:
                                  'Versión ${snapshot.data ?? 'Cargando…'}',
                              onTap: () {
                                Navigator.pushNamed(context, AppRoutes.about);
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 26),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              cerrarSesion(context);
                            },
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Cerrar sesión'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: rojo,
                              side: const BorderSide(color: rojo, width: 1.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'RondaQR · $company',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF98A2B3),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  final AppUser user;

  const _ChangePasswordDialog({required this.user});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  static const Color azulPrincipal = Color(0xFF0866FF);
  static const Color rojo = Color(0xFFD92D20);

  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;
  bool _saving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) {
      return;
    }

    final String email = widget.user.email.trim();
    final String currentPassword = _currentController.text;
    final String newPassword = _newController.text;
    final String confirmPassword = _confirmController.text;
    final String? validationMessage = _validate(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'No existe un correo válido para esta sesión.';
      });
      return;
    }

    if (validationMessage != null) {
      setState(() {
        _errorMessage = validationMessage;
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    bool currentPasswordValidated = false;

    try {
      final SupabaseClient client = SupabaseService.instance.requireClient();

      await client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      currentPasswordValidated = true;

      await client.auth.updateUser(UserAttributes(password: newPassword));
      await SessionStore.instance.signOut();

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _errorMessage = !currentPasswordValidated && _isCredentialError(error)
            ? 'La contraseña actual no es correcta.'
            : 'No se pudo cambiar la contraseña.';
      });
    } catch (error) {
      debugPrint('No se pudo cambiar la contraseña: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _errorMessage = 'No se pudo cambiar la contraseña.';
      });
    }
  }

  String? _validate({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      return 'Completa todos los campos.';
    }

    if (newPassword.length < 8) {
      return 'La nueva contraseña debe tener al menos 8 caracteres.';
    }

    if (newPassword == currentPassword) {
      return 'La nueva contraseña debe ser distinta a la actual.';
    }

    if (newPassword != confirmPassword) {
      return 'Las contraseñas no coinciden.';
    }

    return null;
  }

  bool _isCredentialError(AuthException error) {
    final String message = error.message.toLowerCase();
    return message.contains('invalid login') ||
        message.contains('invalid credentials') ||
        message.contains('invalid email or password') ||
        message.contains('incorrect');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.lock_reset_rounded, color: azulPrincipal),
          SizedBox(width: 10),
          Expanded(child: Text('Cambiar contraseña')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PasswordField(
              controller: _currentController,
              label: 'Contraseña actual',
              obscureText: _hideCurrent,
              enabled: !_saving,
              onToggle: () {
                setState(() {
                  _hideCurrent = !_hideCurrent;
                });
              },
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _newController,
              label: 'Nueva contraseña',
              obscureText: _hideNew,
              enabled: !_saving,
              onToggle: () {
                setState(() {
                  _hideNew = !_hideNew;
                });
              },
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _confirmController,
              label: 'Confirmar nueva contraseña',
              obscureText: _hideConfirm,
              enabled: !_saving,
              onSubmitted: (_) => _submit(),
              onToggle: () {
                setState(() {
                  _hideConfirm = !_hideConfirm;
                });
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: rojo,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: azulPrincipal,
            foregroundColor: Colors.white,
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final bool enabled;
  final VoidCallback onToggle;
  final ValueChanged<String>? onSubmitted;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscureText,
    required this.enabled,
    required this.onToggle,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      textInputAction: TextInputAction.next,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          onPressed: enabled ? onToggle : null,
          icon: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF0866FF), size: 22),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF061B44),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF0866FF)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF061B44),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF98A2B3)),
            ],
          ),
        ),
      ),
    );
  }
}
