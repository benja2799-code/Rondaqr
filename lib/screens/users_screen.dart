import 'package:flutter/material.dart';

import '../auth_models.dart';
import '../user_accounts.dart';
import '../user_configuration.dart';
import '../work_shifts.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  static const Color azulOscuro = Color(0xFF061B44);
  static const Color azulMedio = Color(0xFF073C85);
  static const Color azulPrincipal = Color(0xFF0866FF);
  static const Color fondo = Color(0xFFF4F7FB);

  Future<void> _openUserForm(
    BuildContext context, {
    LocalUserAccount? account,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UserFormDialog(account: account),
    );
  }

  Future<void> _openShiftForm(
    BuildContext context, {
    ShiftDefinition? shift,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ShiftFormDialog(shift: shift),
    );
  }

  String _assignedGuardName(ShiftDefinition shift, UserAccountStore userStore) {
    if (shift.assignedUserId.isEmpty) {
      return 'Sin guardia asignado';
    }
    return userStore.accountById(shift.assignedUserId)?.user.displayName ??
        'Guardia no disponible';
  }

  @override
  Widget build(BuildContext context) {
    final UserAccountStore userStore = UserAccountStore.instance;
    final WorkShiftStore shiftStore = WorkShiftStore.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([userStore, shiftStore]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: fondo,
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [azulOscuro, azulMedio]),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Guardias y turnos',
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
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(17),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF2FF),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.storage_rounded, color: azulPrincipal),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Configuración local de demostración. Las '
                                'contraseñas se guardan en el dispositivo y '
                                'no son autenticación segura de producción.',
                                style: TextStyle(
                                  color: azulOscuro,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _SectionHeader(
                        title: 'Guardias y usuarios',
                        count: userStore.accounts.length,
                        actionLabel: 'Agregar',
                        onAction: () => _openUserForm(context),
                      ),
                      const SizedBox(height: 12),
                      ...userStore.accounts.map((account) {
                        final AppUser user = account.user;
                        final ShiftDefinition? shift = shiftStore
                            .definitionForUser(user);

                        return _ConfigurationCard(
                          icon: user.role == AppRole.administrator
                              ? Icons.admin_panel_settings_outlined
                              : Icons.security_rounded,
                          title: user.displayName,
                          subtitle:
                              '${user.email}\n'
                              '${user.jobTitle} · ${user.role.label}\n'
                              '${shift?.displayName ?? 'Sin turno asignado'}',
                          status: user.isActive ? 'Activo' : 'Inactivo',
                          active: user.isActive,
                          onTap: () => _openUserForm(context, account: account),
                        );
                      }),
                      const SizedBox(height: 24),
                      _SectionHeader(
                        title: 'Turnos configurados',
                        count: shiftStore.definitions.length,
                        actionLabel: 'Agregar',
                        onAction: () => _openShiftForm(context),
                      ),
                      const SizedBox(height: 12),
                      ...shiftStore.definitions.map((shift) {
                        return _ConfigurationCard(
                          icon: shift.id == 'shift_night'
                              ? Icons.nightlight_round
                              : Icons.wb_sunny_outlined,
                          title: shift.name,
                          subtitle:
                              '${shift.schedule}\n'
                              '${_assignedGuardName(shift, userStore)}',
                          status: shift.isActive ? 'Activo' : 'Inactivo',
                          active: shift.isActive,
                          onTap: () => _openShiftForm(context, shift: shift),
                        );
                      }),
                    ],
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

class _UserFormDialog extends StatefulWidget {
  final LocalUserAccount? account;

  const _UserFormDialog({this.account});

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _identifierController;
  late final TextEditingController _jobTitleController;
  late AppRole _role;
  late bool _isActive;
  String _shiftId = '';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final LocalUserAccount? account = widget.account;
    _nameController = TextEditingController(
      text: account?.user.displayName ?? '',
    );
    _emailController = TextEditingController(text: account?.user.email ?? '');
    _passwordController = TextEditingController(text: account?.password ?? '');
    _identifierController = TextEditingController(
      text: account?.user.identifier ?? '',
    );
    _jobTitleController = TextEditingController(
      text: account?.user.jobTitle ?? 'Guardia de seguridad',
    );
    _role = account?.user.role ?? AppRole.guard;
    _isActive = account?.user.isActive ?? true;
    _shiftId = account?.user.shiftId ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _identifierController.dispose();
    _jobTitleController.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty
        ? 'Este campo es obligatorio.'
        : null;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    if (_role == AppRole.guard && _isActive && _shiftId.isEmpty) {
      setState(() => _error = 'Asigna un turno al guardia.');
      return;
    }

    final UserAccountStore userStore = UserAccountStore.instance;
    final WorkShiftStore shiftStore = WorkShiftStore.instance;
    final String userId =
        widget.account?.user.id ??
        'user_${DateTime.now().microsecondsSinceEpoch}';
    final WorkShiftRecord? activeShift = shiftStore.activeForUser(userId);

    if (activeShift != null &&
        (!_isActive ||
            _role != AppRole.guard ||
            _shiftId != activeShift.shiftId)) {
      setState(() {
        _error =
            'Cierra el turno activo antes de desactivar o cambiar la asignación.';
      });
      return;
    }

    final ShiftDefinition? selectedShift = _shiftId.isEmpty
        ? null
        : shiftStore.definitionById(_shiftId);
    if (_role == AppRole.guard &&
        _isActive &&
        selectedShift?.isActive != true) {
      setState(() => _error = 'Selecciona un turno activo.');
      return;
    }
    final WorkShiftRecord? deviceActiveShift = shiftStore.activeShift;
    if (selectedShift != null &&
        deviceActiveShift?.shiftId == selectedShift.id &&
        deviceActiveShift?.userId != userId) {
      setState(() {
        _error = 'Cierra el turno activo antes de asignarlo a otro guardia.';
      });
      return;
    }
    final UserConfiguration configuration =
        UserConfigurationStore.instance.configuration;
    final bool keepsShift = _role == AppRole.guard && _isActive;
    final AppUser user = AppUser(
      id: userId,
      email: _emailController.text.trim().toLowerCase(),
      displayName: _nameController.text.trim(),
      identifier: _identifierController.text.trim(),
      jobTitle: _jobTitleController.text.trim(),
      installationId: 'inst_local',
      installationName: configuration.installationNameDisplay,
      company: configuration.companyDisplay,
      shiftId: keepsShift ? _shiftId : '',
      shift: keepsShift
          ? selectedShift?.displayName ?? ''
          : _role == AppRole.administrator
          ? 'Administración'
          : '',
      role: _role,
      isActive: _isActive,
    );

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final String previousAssignee = selectedShift?.assignedUserId ?? '';
      await userStore.saveAccount(
        LocalUserAccount(user: user, password: _passwordController.text),
      );
      await shiftStore.assignUser(
        shiftId: keepsShift ? _shiftId : '',
        userId: userId,
      );

      if (previousAssignee.isNotEmpty && previousAssignee != userId) {
        await userStore.clearShiftForUsers([previousAssignee]);
      }

      if (!mounted) {
        return;
      }
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = error is StateError
            ? error.message.toString()
            : 'No fue posible guardar el usuario.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<ShiftDefinition> shifts = WorkShiftStore.instance.definitions
        .where((shift) => shift.isActive)
        .toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.account == null ? 'Agregar usuario' : 'Editar usuario',
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogField(
                  controller: _nameController,
                  label: 'Nombre',
                  validator: _required,
                ),
                _DialogField(
                  controller: _emailController,
                  label: 'Correo o usuario',
                  validator: _required,
                ),
                _DialogField(
                  controller: _passwordController,
                  label: 'Contraseña local',
                  validator: _required,
                  obscureText: true,
                ),
                _DialogField(
                  controller: _identifierController,
                  label: 'Identificador o RUT',
                  validator: _required,
                ),
                _DialogField(
                  controller: _jobTitleController,
                  label: 'Cargo',
                  validator: _required,
                ),
                DropdownButtonFormField<AppRole>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: AppRole.values.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role.label),
                    );
                  }).toList(),
                  onChanged: _saving
                      ? null
                      : (value) {
                          setState(() {
                            _role = value ?? AppRole.guard;
                            if (_role == AppRole.administrator) {
                              _shiftId = '';
                            }
                          });
                        },
                ),
                if (_role == AppRole.guard) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: shifts.any((shift) => shift.id == _shiftId)
                        ? _shiftId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Turno asignado',
                    ),
                    items: shifts.map((shift) {
                      return DropdownMenuItem(
                        value: shift.id,
                        child: Text(shift.displayName),
                      );
                    }).toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _shiftId = value ?? ''),
                  ),
                ],
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Usuario activo'),
                  value: _isActive,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _isActive = value),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFD92D20)),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Guardando...' : 'Guardar'),
        ),
      ],
    );
  }
}

class _ShiftFormDialog extends StatefulWidget {
  final ShiftDefinition? shift;

  const _ShiftFormDialog({this.shift});

  @override
  State<_ShiftFormDialog> createState() => _ShiftFormDialogState();
}

class _ShiftFormDialogState extends State<_ShiftFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  late String _assignedUserId;
  late bool _isActive;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.shift?.name ?? '');
    _startController = TextEditingController(
      text: widget.shift?.scheduledStart ?? '08:00',
    );
    _endController = TextEditingController(
      text: widget.shift?.scheduledEnd ?? '20:00',
    );
    _assignedUserId = widget.shift?.assignedUserId ?? '';
    _isActive = widget.shift?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty
        ? 'Este campo es obligatorio.'
        : null;
  }

  String? _timeValidator(String? value) {
    if (!ShiftDefinition.isValidClockTime(value?.trim() ?? '')) {
      return 'Usa formato HH:mm, por ejemplo 08:00.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    final WorkShiftStore shiftStore = WorkShiftStore.instance;
    final UserAccountStore userStore = UserAccountStore.instance;
    final String shiftId =
        widget.shift?.id ?? 'shift_${DateTime.now().microsecondsSinceEpoch}';
    final WorkShiftRecord? active = shiftStore.activeShift;

    if (active != null &&
        active.shiftId == shiftId &&
        (!_isActive || _assignedUserId != active.userId)) {
      setState(() {
        _error = 'Cierra este turno activo antes de modificar su asignación.';
      });
      return;
    }

    final ShiftDefinition definition = ShiftDefinition(
      id: shiftId,
      name: _nameController.text.trim(),
      scheduledStart: _startController.text.trim(),
      scheduledEnd: _endController.text.trim(),
      assignedUserId: _assignedUserId,
      isActive: _isActive,
    );
    final String oldAssignee = widget.shift?.assignedUserId ?? '';

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await shiftStore.saveDefinition(definition);

      if (oldAssignee.isNotEmpty && oldAssignee != _assignedUserId) {
        await userStore.clearShiftForUsers([oldAssignee]);
      }
      if (_assignedUserId.isNotEmpty) {
        await userStore.assignShift(
          userId: _assignedUserId,
          shiftId: definition.id,
          shiftDisplay: definition.displayName,
        );
      }

      if (!mounted) {
        return;
      }
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = error is StateError
            ? error.message.toString()
            : 'No fue posible guardar el turno.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<AppUser> guards = UserAccountStore.instance.activeGuards;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.shift == null ? 'Agregar turno' : 'Editar turno'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogField(
                  controller: _nameController,
                  label: 'Nombre del turno',
                  validator: _required,
                ),
                _DialogField(
                  controller: _startController,
                  label: 'Hora de inicio (HH:mm)',
                  validator: _timeValidator,
                ),
                _DialogField(
                  controller: _endController,
                  label: 'Hora de término (HH:mm)',
                  validator: _timeValidator,
                ),
                DropdownButtonFormField<String>(
                  initialValue:
                      guards.any((guard) => guard.id == _assignedUserId)
                      ? _assignedUserId
                      : '',
                  decoration: const InputDecoration(
                    labelText: 'Guardia asignado',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Sin guardia asignado'),
                    ),
                    ...guards.map(
                      (guard) => DropdownMenuItem(
                        value: guard.id,
                        child: Text(guard.displayName),
                      ),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) =>
                            setState(() => _assignedUserId = value ?? ''),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Turno activo'),
                  value: _isActive,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _isActive = value),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFD92D20)),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Guardando...' : 'Guardar'),
        ),
      ],
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final bool obscureText;

  const _DialogField({
    required this.controller,
    required this.label,
    this.validator,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        validator: validator,
        obscureText: obscureText,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$title ($count)',
            style: const TextStyle(
              color: Color(0xFF061B44),
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.add_rounded),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

class _ConfigurationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final bool active;
  final VoidCallback onTap;

  const _ConfigurationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFF0866FF);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: primary),
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFFE8F8F0)
                            : const Color(0xFFFEECEC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: active
                              ? const Color(0xFF16A36A)
                              : const Color(0xFFD92D20),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFF667085),
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
