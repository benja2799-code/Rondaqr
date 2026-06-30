import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../user_configuration.dart';
import 'control_points_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const Color azulOscuro = Color(0xFF061B44);
  static const Color azulMedio = Color(0xFF073C85);
  static const Color azulPrincipal = Color(0xFF0866FF);
  static const Color fondo = Color(0xFFF4F7FB);
  static const Color rojo = Color(0xFFD92D20);

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
              onPressed: () {
                Navigator.pop(dialogContext);

                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (route) => false,
                );
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
    final bool? saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );

    if (saved == true && context.mounted) {
      mostrarMensaje(context, 'La información fue guardada correctamente.');
    }
  }

  void abrirPuntosDeControl(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ControlPointsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UserConfigurationStore configurationStore =
        UserConfigurationStore.instance;

    return AnimatedBuilder(
      animation: configurationStore,
      builder: (context, _) {
        final UserConfiguration configuration =
            configurationStore.configuration;

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
                                configuration.guardNameDisplay,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 23,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                configuration.roleDisplay,
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
                                child: const Text(
                                  'Usuario activo',
                                  style: TextStyle(
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
                                value: configuration.installationNameDisplay,
                              ),
                              const Divider(height: 28),
                              _ProfileInfoRow(
                                icon: Icons.business_rounded,
                                label: 'Empresa',
                                value: configuration.companyDisplay,
                              ),
                              const Divider(height: 28),
                              _ProfileInfoRow(
                                icon: Icons.access_time_rounded,
                                label: 'Turno',
                                value: configuration.shiftDisplay,
                              ),
                              const Divider(height: 28),
                              _ProfileInfoRow(
                                icon: Icons.badge_outlined,
                                label: 'Identificador o RUT',
                                value: configuration.identifierDisplay,
                              ),
                              const Divider(height: 28),
                              _ProfileInfoRow(
                                icon: Icons.work_outline_rounded,
                                label: 'Cargo',
                                value: configuration.roleDisplay,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        _ProfileOption(
                          icon: Icons.edit_outlined,
                          title: 'Editar información',
                          subtitle:
                              'Actualiza tus datos y los de la instalación',
                          onTap: () {
                            editarInformacion(context);
                          },
                        ),
                        const SizedBox(height: 12),
                        _ProfileOption(
                          icon: Icons.location_on_outlined,
                          title: 'Puntos de control',
                          subtitle: 'Crea y administra los puntos de la ronda',
                          onTap: () {
                            abrirPuntosDeControl(context);
                          },
                        ),
                        const SizedBox(height: 12),
                        _ProfileOption(
                          icon: Icons.lock_outline_rounded,
                          title: 'Cambiar contraseña',
                          subtitle: 'Actualiza tu contraseña de acceso',
                          onTap: () {
                            mostrarMensaje(
                              context,
                              'La opción para cambiar contraseña se agregará más adelante.',
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _ProfileOption(
                          icon: Icons.help_outline_rounded,
                          title: 'Ayuda',
                          subtitle: 'Consulta información sobre la aplicación',
                          onTap: () {
                            mostrarMensaje(
                              context,
                              'La sección de ayuda se agregará más adelante.',
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _ProfileOption(
                          icon: Icons.info_outline_rounded,
                          title: 'Acerca de RondaQR',
                          subtitle: 'Versión 1.0.0',
                          onTap: () {
                            showAboutDialog(
                              context: context,
                              applicationName: 'RondaQR',
                              applicationVersion: '1.0.0',
                              applicationLegalese: configuration.companyDisplay,
                              children: const [
                                SizedBox(height: 12),
                                Text(
                                  'Aplicación para el control de rondas de seguridad.',
                                ),
                              ],
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
                          'RondaQR · ${configuration.companyDisplay}',
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
