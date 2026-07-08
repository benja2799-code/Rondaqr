import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'auth_models.dart';
import 'session_store.dart';

class SessionGuard extends StatelessWidget {
  final Widget child;

  const SessionGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final SessionStore sessionStore = SessionStore.instance;

    return AnimatedBuilder(
      animation: sessionStore,
      builder: (context, _) {
        if (!sessionStore.isAuthenticated) {
          return const AccessDeniedScreen(sessionRequired: true);
        }

        return child;
      },
    );
  }
}

class PermissionGuard extends StatelessWidget {
  final AppPermission permission;
  final Widget child;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final SessionStore sessionStore = SessionStore.instance;

    return AnimatedBuilder(
      animation: sessionStore,
      builder: (context, _) {
        if (!sessionStore.isAuthenticated) {
          return const AccessDeniedScreen(sessionRequired: true);
        }

        if (!sessionStore.can(permission)) {
          return const AccessDeniedScreen(sessionRequired: false);
        }

        return child;
      },
    );
  }
}

class AccessDeniedScreen extends StatelessWidget {
  final bool sessionRequired;

  const AccessDeniedScreen({super.key, required this.sessionRequired});

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF061B44);
    const Color mediumBlue = Color(0xFF073C85);
    const Color primaryBlue = Color(0xFF0866FF);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 72,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [darkBlue, mediumBlue]),
              ),
              alignment: Alignment.center,
              child: const Text(
                'RondaQR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Container(
                        width: 108,
                        height: 108,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEAF2FF),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          sessionRequired
                              ? Icons.lock_outline_rounded
                              : Icons.admin_panel_settings_outlined,
                          color: primaryBlue,
                          size: 56,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        sessionRequired
                            ? 'Sesión requerida'
                            : 'Acceso restringido',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: darkBlue,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        sessionRequired
                            ? 'Inicia sesión para acceder a esta sección.'
                            : 'Tu rol no tiene permiso para acceder a esta sección.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: () {
                          if (sessionRequired) {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRoutes.login,
                              (route) => false,
                            );
                          } else if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRoutes.home,
                              (route) => false,
                            );
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(
                          sessionRequired
                              ? Icons.login_rounded
                              : Icons.arrow_back_rounded,
                        ),
                        label: Text(
                          sessionRequired ? 'Ir al acceso' : 'Volver',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
