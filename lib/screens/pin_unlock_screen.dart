import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../auth_models.dart';
import 'login_screen.dart';
import '../services/pin_auth_service.dart';
import '../session_store.dart';

class PinUnlockScreen extends StatefulWidget {
  const PinUnlockScreen({super.key});

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  static const Color azulOscuro = Color(0xFF061B44);
  static const Color azulMedio = Color(0xFF073C85);
  static const Color azulClaro = Color(0xFF48A7FF);

  String _pin = '';
  int _failedAttempts = 0;
  String? _message;
  bool _busy = false;
  bool _leavingScreen = false;

  AppUser? get _user => SessionStore.instance.currentUser;

  Future<void> _appendDigit(String digit) async {
    if (_busy || _pin.length >= 4) {
      return;
    }

    setState(() {
      _message = null;
      _pin += digit;
    });

    if (_pin.length == 4) {
      await _verifyPin();
    }
  }

  void _deleteDigit() {
    if (_busy || _pin.isEmpty) {
      return;
    }

    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _message = null;
    });
  }

  Future<void> _verifyPin() async {
    final AppUser? user = _user;
    if (user == null) {
      await _goToLogin();
      return;
    }

    setState(() {
      _busy = true;
    });

    bool valid;
    try {
      valid = await PinAuthService.instance.verifyPin(
        userId: user.id,
        pin: _pin,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _busy = false;
        _pin = '';
        _message = 'No fue posible verificar el PIN. Intenta nuevamente.';
      });
      return;
    }

    if (!mounted) {
      return;
    }

    if (valid) {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
      return;
    }

    _failedAttempts++;
    _pin = '';

    if (_failedAttempts >= 5) {
      await _goToLogin(
        message: 'Demasiados intentos. Inicia sesión nuevamente.',
      );
      return;
    }

    setState(() {
      _busy = false;
      _message = 'PIN incorrecto.';
    });
  }

  Future<void> _forgotPin() async {
    final AppUser? user = _user;
    try {
      if (user != null) {
        await PinAuthService.instance.deletePinForUser(user.id);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _message = 'No fue posible restablecer el PIN.';
      });
      return;
    }

    await _goToLogin(
      message: 'Inicia sesión nuevamente para crear un nuevo PIN.',
    );
  }

  Future<void> _changeUser() async {
    await _goToLogin();
  }

  Future<void> _goToLogin({String? message}) async {
    if (_leavingScreen) {
      return;
    }

    _leavingScreen = true;

    try {
      await SessionStore.instance.signOut();
    } catch (_) {
      // El cierre remoto no debe impedir volver al acceso tradicional.
    } finally {
      PinAuthService.instance.clearUnlock();
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(initialMessage: message),
        settings: const RouteSettings(name: AppRoutes.login),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppUser? user = _user;
    final String name = user?.displayName ?? 'Usuario';

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [azulOscuro, Color(0xFF082B64), azulMedio],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool compact = constraints.maxHeight < 720;
              final double logoSize = compact ? 60 : 68;
              final double keySize = compact ? 56 : 62;

              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: compact ? 8 : 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: logoSize,
                          height: logoSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.shield_rounded,
                                size: logoSize * 0.80,
                                color: Colors.white,
                              ),
                              Icon(
                                Icons.qr_code_2_rounded,
                                size: logoSize * 0.42,
                                color: azulOscuro,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: compact ? 10 : 14),
                        Text(
                          'Hola, $name',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ingresa tu PIN para acceder',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: compact ? 14 : 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            final bool filled = index < _pin.length;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.symmetric(horizontal: 7),
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: filled ? azulClaro : Colors.transparent,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.4,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 20,
                          child: Text(
                            _message ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFFB4B4),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 8 : 12),
                        _PinKeyboard(
                          busy: _busy,
                          keySize: keySize,
                          rowSpacing: compact ? 7 : 9,
                          onDigit: _appendDigit,
                          onDelete: _deleteDigit,
                          onBiometric: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Huella preparada para una próxima etapa.',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                        SizedBox(height: compact ? 8 : 12),
                        TextButton(
                          onPressed: _busy ? null : _forgotPin,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text(
                            'Olvidé mi PIN',
                            style: TextStyle(color: azulClaro),
                          ),
                        ),
                        TextButton(
                          onPressed: _busy ? null : _changeUser,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text(
                            'Cambiar de usuario',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        SizedBox(height: compact ? 6 : 10),
                        Text(
                          'RondaQR · Acceso rápido seguro',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PinKeyboard extends StatelessWidget {
  final bool busy;
  final double keySize;
  final double rowSpacing;
  final Future<void> Function(String digit) onDigit;
  final VoidCallback onDelete;
  final VoidCallback onBiometric;

  const _PinKeyboard({
    required this.busy,
    required this.keySize,
    required this.rowSpacing,
    required this.onDigit,
    required this.onDelete,
    required this.onBiometric,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final List<String> row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ]) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((digit) {
              return _PinKey(
                label: digit,
                enabled: !busy,
                size: keySize,
                onTap: () => onDigit(digit),
              );
            }).toList(),
          ),
          SizedBox(height: rowSpacing),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PinIconKey(
              icon: Icons.fingerprint_rounded,
              enabled: !busy,
              size: keySize,
              onTap: onBiometric,
            ),
            _PinKey(
              label: '0',
              enabled: !busy,
              size: keySize,
              onTap: () => onDigit('0'),
            ),
            _PinIconKey(
              icon: Icons.backspace_outlined,
              enabled: !busy,
              size: keySize,
              onTap: onDelete,
            ),
          ],
        ),
      ],
    );
  }
}

class _PinKey extends StatelessWidget {
  final String label;
  final bool enabled;
  final double size;
  final VoidCallback onTap;

  const _PinKey({
    required this.label,
    required this.enabled,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _KeyShell(
      enabled: enabled,
      size: size,
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _PinIconKey extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final double size;
  final VoidCallback onTap;

  const _PinIconKey({
    required this.icon,
    required this.enabled,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _KeyShell(
      enabled: enabled,
      size: size,
      onTap: onTap,
      child: Icon(icon, color: Colors.white, size: 27),
    );
  }
}

class _KeyShell extends StatelessWidget {
  final Widget child;
  final bool enabled;
  final double size;
  final VoidCallback onTap;

  const _KeyShell({
    required this.child,
    required this.enabled,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.white.withValues(alpha: enabled ? 0.12 : 0.06),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
