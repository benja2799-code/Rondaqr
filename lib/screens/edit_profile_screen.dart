import 'package:flutter/material.dart';

import '../user_configuration.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const Color azulOscuro = Color(0xFF061B44);
  static const Color azulMedio = Color(0xFF073C85);
  static const Color azulPrincipal = Color(0xFF0866FF);
  static const Color fondo = Color(0xFFF4F7FB);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _guardNameController;
  late final TextEditingController _identifierController;
  late final TextEditingController _installationController;
  late final TextEditingController _companyController;
  late final TextEditingController _shiftController;
  late final TextEditingController _roleController;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final UserConfiguration configuration =
        UserConfigurationStore.instance.configuration;

    _guardNameController = TextEditingController(text: configuration.guardName);
    _identifierController = TextEditingController(
      text: configuration.identifier,
    );
    _installationController = TextEditingController(
      text: configuration.installationName,
    );
    _companyController = TextEditingController(text: configuration.company);
    _shiftController = TextEditingController(text: configuration.shift);
    _roleController = TextEditingController(text: configuration.role);
  }

  @override
  void dispose() {
    _guardNameController.dispose();
    _identifierController.dispose();
    _installationController.dispose();
    _companyController.dispose();
    _shiftController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio.';
    }

    return null;
  }

  Future<void> _saveConfiguration() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
    });

    final UserConfiguration configuration = UserConfiguration(
      guardName: _guardNameController.text.trim(),
      identifier: _identifierController.text.trim(),
      installationName: _installationController.text.trim(),
      company: _companyController.text.trim(),
      shift: _shiftController.text.trim(),
      role: _roleController.text.trim(),
    );

    try {
      await UserConfigurationStore.instance.saveConfiguration(configuration);

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No fue posible guardar la información. Intenta nuevamente.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_saving,
      textInputAction: textInputAction,
      validator: _requiredValidator,
      onFieldSubmitted: textInputAction == TextInputAction.done
          ? (_) => _saveConfiguration()
          : null,
      decoration: InputDecoration(
        labelText: label,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  const Expanded(
                    child: Text(
                      'Editar información',
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
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF2FF),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: azulPrincipal,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Estos datos aparecerán en las rondas, el '
                                'historial y los reportes.',
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
                      const SizedBox(height: 20),
                      Container(
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
                            _buildField(
                              controller: _guardNameController,
                              label: 'Nombre del guardia',
                              icon: Icons.person_outline_rounded,
                            ),
                            const SizedBox(height: 16),
                            _buildField(
                              controller: _identifierController,
                              label: 'Identificador o RUT',
                              icon: Icons.badge_outlined,
                            ),
                            const SizedBox(height: 16),
                            _buildField(
                              controller: _installationController,
                              label: 'Nombre de la instalación',
                              icon: Icons.apartment_rounded,
                            ),
                            const SizedBox(height: 16),
                            _buildField(
                              controller: _companyController,
                              label: 'Empresa',
                              icon: Icons.business_rounded,
                            ),
                            const SizedBox(height: 16),
                            _buildField(
                              controller: _shiftController,
                              label: 'Horario o turno',
                              icon: Icons.access_time_rounded,
                            ),
                            const SizedBox(height: 16),
                            _buildField(
                              controller: _roleController,
                              label: 'Cargo',
                              icon: Icons.work_outline_rounded,
                              textInputAction: TextInputAction.done,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _saveConfiguration,
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
                            _saving ? 'Guardando...' : 'Guardar información',
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
          ],
        ),
      ),
    );
  }
}
