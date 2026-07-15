import 'package:flutter/material.dart';

import '../control_points.dart';
import '../round_state.dart';
import 'control_point_qr_screen.dart';

class ControlPointsScreen extends StatelessWidget {
  const ControlPointsScreen({super.key});

  static const Color azulOscuro = Color(0xFF061B44);
  static const Color azulMedio = Color(0xFF073C85);
  static const Color azulPrincipal = Color(0xFF0866FF);
  static const Color fondo = Color(0xFFF4F7FB);
  static const Color verde = Color(0xFF16A36A);
  static const Color rojo = Color(0xFFD92D20);

  Future<bool> _canModify(BuildContext context) async {
    if (!RoundState.instance.roundStarted) {
      return true;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
              SizedBox(width: 10),
              Expanded(child: Text('Ronda activa')),
            ],
          ),
          content: const Text(
            'No es posible crear, editar, activar, desactivar o eliminar '
            'puntos mientras existe una ronda activa. Finalízala o reiníciala '
            'antes de modificar la configuración.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );

    return false;
  }

  Future<void> _openPointForm(
    BuildContext context, {
    ControlPointDefinition? point,
  }) async {
    if (!await _canModify(context) || !context.mounted) {
      return;
    }

    final bool? saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ControlPointFormScreen(point: point)),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            point == null
                ? 'Punto de control creado correctamente.'
                : 'Punto de control actualizado.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openQr(BuildContext context, ControlPointDefinition point) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ControlPointQrScreen(point: point)),
    );
  }

  Future<void> _togglePoint(
    BuildContext context,
    ControlPointDefinition point,
  ) async {
    if (!await _canModify(context) || !context.mounted) {
      return;
    }

    try {
      await ControlPointStore.instance.updatePoint(
        point.copyWith(isActive: !point.isActive),
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            point.isActive
                ? '${point.name} quedó inactivo.'
                : '${point.name} quedó activo.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (context.mounted) {
        _showSaveError(context, error);
      }
    }
  }

  Future<void> _deletePoint(
    BuildContext context,
    ControlPointDefinition point,
  ) async {
    if (!await _canModify(context) || !context.mounted) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: rojo),
              SizedBox(width: 10),
              Expanded(child: Text('Eliminar punto')),
            ],
          ),
          content: Text(
            '¿Deseas eliminar “${point.name}”? Esta acción no borrará '
            'las rondas antiguas donde el punto ya fue registrado.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: rojo,
                foregroundColor: Colors.white,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await ControlPointStore.instance.deletePoint(point.id);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Punto de control eliminado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (context.mounted) {
        _showSaveError(context, error);
      }
    }
  }

  void _showSaveError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is StateError
              ? error.message
              : 'No fue posible guardar los puntos de control. Intenta nuevamente.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ControlPointStore pointStore = ControlPointStore.instance;
    final RoundState roundState = RoundState.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([pointStore, roundState]),
      builder: (context, _) {
        final List<ControlPointDefinition> points = pointStore.points;
        final int activeCount = pointStore.activePoints.length;

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
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Puntos de control',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _openPointForm(context),
                        icon: const Icon(
                          Icons.add_circle_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F6FFF), azulMedio],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: azulPrincipal.withValues(alpha: 0.24),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$activeCount puntos activos',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${points.length} configurados en total',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (roundState.roundStarted) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4E5),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFF59E0B),
                              ),
                              SizedBox(width: 11),
                              Expanded(
                                child: Text(
                                  'La configuración está bloqueada mientras '
                                  'la ronda actual permanezca activa.',
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
                      ],
                      const SizedBox(height: 22),
                      if (points.isEmpty)
                        const _EmptyPoints()
                      else
                        ...points.map((point) {
                          return _ControlPointCard(
                            point: point,
                            onViewQr: () => _openQr(context, point),
                            onEdit: () => _openPointForm(context, point: point),
                            onToggle: () => _togglePoint(context, point),
                            onDelete: () => _deletePoint(context, point),
                          );
                        }),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: () => _openPointForm(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Crear punto de control'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: azulPrincipal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
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

class ControlPointFormScreen extends StatefulWidget {
  final ControlPointDefinition? point;

  const ControlPointFormScreen({super.key, this.point});

  @override
  State<ControlPointFormScreen> createState() => _ControlPointFormScreenState();
}

class _ControlPointFormScreenState extends State<ControlPointFormScreen> {
  static const Color azulOscuro = Color(0xFF061B44);
  static const Color azulMedio = Color(0xFF073C85);
  static const Color azulPrincipal = Color(0xFF0866FF);
  static const Color fondo = Color(0xFFF4F7FB);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _qrController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _orderController;

  late bool _isActive;
  String? _iconKey;
  bool _saving = false;

  bool get _editing {
    return widget.point != null;
  }

  @override
  void initState() {
    super.initState();

    final ControlPointDefinition? point = widget.point;
    final List<ControlPointDefinition> existingPoints =
        ControlPointStore.instance.points;
    final int nextOrder = existingPoints.isEmpty
        ? 1
        : existingPoints
                  .map((item) => item.order)
                  .reduce((a, b) => a > b ? a : b) +
              1;

    _nameController = TextEditingController(text: point?.name ?? '');
    _qrController = TextEditingController(text: point?.qrIdentifier ?? '');
    _descriptionController = TextEditingController(
      text: point?.description ?? '',
    );
    _orderController = TextEditingController(
      text: (point?.order ?? nextOrder).toString(),
    );
    _isActive = point?.isActive ?? true;
    _iconKey = point?.iconKey;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qrController.dispose();
    _descriptionController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio.';
    }

    return null;
  }

  String? _validateQr(String? value) {
    final String? requiredError = _requiredText(value);

    if (requiredError != null) {
      return requiredError;
    }

    final String normalized = ControlPointDefinition.normalizeQrIdentifier(
      value!,
    );

    if (!RegExp(r'^[A-Z0-9_]+$').hasMatch(normalized)) {
      return 'Usa solo letras, números y guion bajo.';
    }

    if (ControlPointStore.instance.hasQrIdentifier(
      normalized,
      excludingId: widget.point?.id,
    )) {
      return 'Este identificador QR ya está en uso.';
    }

    return null;
  }

  String? _validateOrder(String? value) {
    final int? order = int.tryParse(value?.trim() ?? '');

    if (order == null || order <= 0) {
      return 'Ingresa un número mayor que cero.';
    }

    return null;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    if (RoundState.instance.roundStarted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No puedes modificar puntos mientras existe una ronda activa.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
    });

    final String normalizedQr = ControlPointDefinition.normalizeQrIdentifier(
      _qrController.text,
    );
    final ControlPointDefinition point = ControlPointDefinition(
      id: widget.point?.id ?? 'point_${DateTime.now().microsecondsSinceEpoch}',
      name: _nameController.text.trim(),
      qrIdentifier: normalizedQr,
      description: _descriptionController.text.trim(),
      order: int.parse(_orderController.text.trim()),
      isActive: _isActive,
      iconKey: _iconKey,
    );

    try {
      if (_editing) {
        await ControlPointStore.instance.updatePoint(point);
      } else {
        await ControlPointStore.instance.addPoint(point);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message
                : 'No fue posible guardar el punto.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      prefixIcon: Icon(icon, color: azulPrincipal),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: azulPrincipal, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String normalizedPreview =
        ControlPointDefinition.normalizeQrIdentifier(_qrController.text);

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
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _editing ? 'Editar punto' : 'Nuevo punto',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
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
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Container(
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
                        TextFormField(
                          controller: _nameController,
                          enabled: !_saving,
                          textInputAction: TextInputAction.next,
                          validator: _requiredText,
                          decoration: _inputDecoration(
                            label: 'Nombre',
                            icon: Icons.location_on_outlined,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _qrController,
                          enabled: !_saving,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.next,
                          validator: _validateQr,
                          onChanged: (_) => setState(() {}),
                          decoration: _inputDecoration(
                            label: 'Identificador QR',
                            icon: Icons.qr_code_rounded,
                            helperText: normalizedPreview.isEmpty
                                ? 'Ejemplo: PORTON_TRASERO'
                                : 'Código: RONDAQR:$normalizedPreview',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          enabled: !_saving,
                          textInputAction: TextInputAction.next,
                          minLines: 2,
                          maxLines: 3,
                          validator: _requiredText,
                          decoration: _inputDecoration(
                            label: 'Descripción o ubicación',
                            icon: Icons.notes_rounded,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _orderController,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          validator: _validateOrder,
                          decoration: _inputDecoration(
                            label: 'Orden dentro de la ronda',
                            icon: Icons.format_list_numbered_rounded,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _iconKey ?? '',
                          decoration: _inputDecoration(
                            label: 'Icono opcional',
                            icon: Icons.insert_emoticon_outlined,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Sin icono específico'),
                            ),
                            ...ControlPointIcons.values.entries.map((entry) {
                              return DropdownMenuItem(
                                value: entry.key,
                                child: Row(
                                  children: [
                                    Icon(
                                      entry.value,
                                      color: azulPrincipal,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 9),
                                    Text(
                                      ControlPointIcons.labels[entry.key] ??
                                          entry.key,
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) {
                                  setState(() {
                                    _iconKey = value == null || value.isEmpty
                                        ? null
                                        : value;
                                  });
                                },
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Punto activo',
                            style: TextStyle(
                              color: azulOscuro,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: const Text(
                            'Solo los puntos activos forman parte de una ronda.',
                          ),
                          value: _isActive,
                          activeThumbColor: azulPrincipal,
                          onChanged: _saving
                              ? null
                              : (value) {
                                  setState(() {
                                    _isActive = value;
                                  });
                                },
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded),
                            label: Text(
                              _saving ? 'Guardando...' : 'Guardar punto',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: azulPrincipal,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: azulPrincipal.withValues(
                                alpha: 0.65,
                              ),
                              disabledForegroundColor: Colors.white,
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
                      ],
                    ),
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

class _ControlPointCard extends StatelessWidget {
  final ControlPointDefinition point;
  final VoidCallback onViewQr;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ControlPointCard({
    required this.point,
    required this.onViewQr,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const Color azulOscuro = Color(0xFF061B44);
    const Color azulPrincipal = Color(0xFF0866FF);
    const Color verde = Color(0xFF16A36A);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: point.isActive
                  ? const Color(0xFFEAF2FF)
                  : const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              point.icon,
              color: point.isActive ? azulPrincipal : const Color(0xFF98A2B3),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${point.order}. ${point.name}',
                        style: const TextStyle(
                          color: azulOscuro,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: point.isActive
                            ? const Color(0xFFE8F8F0)
                            : const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        point.isActive ? 'Activo' : 'Inactivo',
                        style: TextStyle(
                          color: point.isActive
                              ? verde
                              : const Color(0xFF667085),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  point.description,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  point.qrContent,
                  style: const TextStyle(
                    color: azulPrincipal,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opciones',
            onSelected: (value) {
              switch (value) {
                case 'qr':
                  onViewQr();
                case 'edit':
                  onEdit();
                case 'toggle':
                  onToggle();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'qr',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.qr_code_rounded,
                    color: Color(0xFF0866FF),
                  ),
                  title: Text('Ver QR'),
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Editar'),
                ),
              ),
              PopupMenuItem(
                value: 'toggle',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    point.isActive
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  title: Text(point.isActive ? 'Desactivar' : 'Activar'),
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFD92D20),
                  ),
                  title: Text(
                    'Eliminar',
                    style: TextStyle(color: Color(0xFFD92D20)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyPoints extends StatelessWidget {
  const _EmptyPoints();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.add_location_alt_outlined,
            color: Color(0xFF0866FF),
            size: 48,
          ),
          SizedBox(height: 12),
          Text(
            'No hay puntos configurados',
            style: TextStyle(
              color: Color(0xFF061B44),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Crea al menos un punto activo para iniciar una ronda.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF667085), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
