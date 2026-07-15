import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../auth_models.dart';
import '../auth_repository.dart';
import '../services/pin_auth_service.dart';
import '../services/supabase_data_coordinator.dart';
import '../services/supabase_service.dart';
import '../session_store.dart';
import '../user_accounts.dart';

class LoginScreen extends StatefulWidget {
  static const String pinSetupPrompt =
      '¿Quieres crear un PIN de 4 dígitos para entrar más rápido la próxima vez?';

  final String? initialMessage;

  const LoginScreen({super.key, this.initialMessage});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool ocultarPassword = true;
  bool recordarme = true;
  bool ingresando = false;
  String? mensajeError;

  final TextEditingController correoController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  static const Color azulOscuro = Color(0xFF061B44);
  static const Color azulMedio = Color(0xFF073C85);
  static const Color azulPrincipal = Color(0xFF0866FF);
  static const Color azulClaro = Color(0xFF48A7FF);

  @override
  void initState() {
    super.initState();

    final String message = widget.initialMessage?.trim() ?? '';
    if (message.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    });
  }

  @override
  void dispose() {
    correoController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> ingresar() async {
    if (ingresando) {
      return;
    }

    final String correo = correoController.text.trim();
    final String password = passwordController.text;

    if (correo.isEmpty || password.isEmpty) {
      setState(() {
        mensajeError = 'Ingresa el correo y la contraseña.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      ingresando = true;
      mensajeError = null;
    });

    try {
      await SessionStore.instance.signIn(
        email: correo,
        password: password,
        persistent: recordarme,
      );
      await SupabaseDataCoordinator.instance.refreshCurrentUserData(
        force: true,
      );
      final AppUser? signedUser = SessionStore.instance.currentUser;
      if (signedUser != null) {
        await PinAuthService.instance.prepareForUser(signedUser.id);
        PinAuthService.instance.markUnlockedForUser(signedUser.id);
      }
      final String? notice = SessionStore.instance.consumeNotice();

      if (!mounted) {
        return;
      }

      if (notice != null && notice.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(notice), behavior: SnackBarBehavior.floating),
        );
      }

      await _offerPinSetupIfNeeded();

      if (!mounted) {
        return;
      }

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      );
    } on AuthenticationException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        ingresando = false;
        mensajeError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        ingresando = false;
        mensajeError = 'No fue posible iniciar sesión. Intenta nuevamente.';
      });
    }
  }

  Future<void> _offerPinSetupIfNeeded() async {
    final SupabaseService supabaseService = SupabaseService.instance;
    final AppUser? user = SessionStore.instance.currentUser;

    if (!recordarme || !supabaseService.onlineMode || user == null) {
      return;
    }

    final bool hasPin = await PinAuthService.instance.hasPinForUser(user.id);
    if (!mounted || hasPin) {
      return;
    }

    final bool? createPin = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.pin_rounded, color: azulPrincipal),
              SizedBox(width: 10),
              Expanded(child: Text('Crear PIN de acceso')),
            ],
          ),
          content: const Text(LoginScreen.pinSetupPrompt),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Omitir por ahora'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: azulPrincipal,
                foregroundColor: Colors.white,
              ),
              child: const Text('Crear PIN'),
            ),
          ],
        );
      },
    );

    if (createPin == true && mounted) {
      await _showCreatePinDialog(user);
    }
  }

  Future<void> _showCreatePinDialog(AppUser user) async {
    final TextEditingController pinController = TextEditingController();
    final TextEditingController confirmController = TextEditingController();
    bool saving = false;
    bool hidePin = true;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> savePin() async {
              if (saving) {
                return;
              }

              final String pin = pinController.text.trim();
              final String confirm = confirmController.text.trim();

              if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
                setDialogState(() {
                  errorMessage = 'El PIN debe tener 4 dígitos.';
                });
                return;
              }

              if (pin != confirm) {
                setDialogState(() {
                  errorMessage = 'Los PIN no coinciden.';
                });
                return;
              }

              setDialogState(() {
                saving = true;
                errorMessage = null;
              });

              try {
                await PinAuthService.instance.createOrUpdatePin(
                  userId: user.id,
                  pin: pin,
                );

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PIN creado correctamente.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (_) {
                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  saving = false;
                  errorMessage = 'No fue posible guardar el PIN.';
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Define tu PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pinController,
                    enabled: !saving,
                    obscureText: hidePin,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: 'PIN de 4 dígitos',
                      counterText: '',
                      suffixIcon: IconButton(
                        onPressed: saving
                            ? null
                            : () {
                                setDialogState(() {
                                  hidePin = !hidePin;
                                });
                              },
                        icon: Icon(
                          hidePin
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmController,
                    enabled: !saving,
                    obscureText: hidePin,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar PIN',
                      counterText: '',
                    ),
                    onSubmitted: (_) => savePin(),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFD92D20),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : savePin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: azulPrincipal,
                    foregroundColor: Colors.white,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Guardar PIN'),
                ),
              ],
            );
          },
        );
      },
    );

    pinController.dispose();
    confirmController.dispose();
  }

  void mostrarCuentasDemo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0D5DD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Cuentas de demostración',
                  style: TextStyle(
                    color: azulOscuro,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Acceso local para pruebas. No es autenticación segura de producción.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF667085), fontSize: 12),
                ),
                const SizedBox(height: 14),
                ...UserAccountStore.instance.accounts.map((account) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: azulPrincipal,
                      ),
                    ),
                    title: Text(
                      account.user.role.label,
                      style: const TextStyle(
                        color: azulOscuro,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${account.user.email}\n${account.password}',
                    ),
                    isThreeLine: true,
                    onTap: () {
                      correoController.text = account.user.email;
                      passwordController.text = account.password;
                      Navigator.pop(bottomSheetContext);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void mostrarFuncionNoDisponible(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SupabaseService supabaseService = SupabaseService.instance;
    final bool supabaseReady =
        supabaseService.isConfigured && supabaseService.isInitialized;
    final String modeText = supabaseReady
        ? 'Acceso en línea con Supabase'
        : supabaseService.isConfigured
        ? 'Supabase configurado · requiere internet'
        : 'Modo local activo';
    final IconData modeIcon = supabaseReady
        ? Icons.cloud_done_rounded
        : supabaseService.isConfigured
        ? Icons.cloud_off_rounded
        : Icons.storage_rounded;

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
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 28,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 6),

                      Container(
                        width: 94,
                        height: 94,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: const Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.shield_rounded,
                              size: 76,
                              color: Colors.white,
                            ),
                            Icon(
                              Icons.qr_code_2_rounded,
                              size: 40,
                              color: azulOscuro,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text: 'Ronda',
                              style: TextStyle(color: Colors.white),
                            ),
                            TextSpan(
                              text: 'QR',
                              style: TextStyle(color: azulClaro),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 3),

                      const Text(
                        'L G  S E G U R I D A D  S P A',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 26),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Acceso',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Ingresa tus credenciales para continuar',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 14,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(modeIcon, color: azulClaro, size: 20),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                modeText,
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

                      const SizedBox(height: 14),

                      TextField(
                        controller: correoController,
                        enabled: !ingresando,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        style: const TextStyle(color: Color(0xFF14213D)),
                        decoration: InputDecoration(
                          hintText: 'Correo',
                          prefixIcon: const Icon(Icons.mail_outline),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 11),

                      TextField(
                        controller: passwordController,
                        enabled: !ingresando,
                        obscureText: ocultarPassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => ingresar(),
                        style: const TextStyle(color: Color(0xFF14213D)),
                        decoration: InputDecoration(
                          hintText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              ocultarPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                ocultarPassword = !ocultarPassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Checkbox(
                            value: recordarme,
                            activeColor: azulPrincipal,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onChanged: ingresando
                                ? null
                                : (value) {
                                    setState(() {
                                      recordarme = value ?? false;
                                    });
                                  },
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Mantener sesión',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          const Spacer(),
                          Flexible(
                            child: TextButton(
                              onPressed: ingresando
                                  ? null
                                  : () {
                                      mostrarFuncionNoDisponible(
                                        'La recuperación de contraseña estará disponible con el servicio en línea.',
                                      );
                                    },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text(
                                '¿Olvidaste tu contraseña?',
                                maxLines: 2,
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  color: azulClaro,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (mensajeError != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE8E8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            mensajeError!,
                            style: const TextStyle(
                              color: Color(0xFFD92D20),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: ingresando ? null : ingresar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: azulPrincipal,
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: ingresando
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Ingresar',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      if (!supabaseService.isConfigured) ...[
                        const SizedBox(height: 28),

                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'o continúa con',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton.icon(
                            onPressed: ingresando ? null : mostrarCuentasDemo,
                            icon: const Icon(Icons.badge_outlined),
                            label: const Text('Ver cuentas de demostración'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: azulPrincipal),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      Text(
                        'Protegemos lo que más importa',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13,
                        ),
                      ),
                    ],
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
