import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../round_state.dart';
import '../user_configuration.dart';
import 'round_summary_screen.dart';

class PointConfirmationScreen extends StatefulWidget {
  final String pointId;
  final String pointName;

  const PointConfirmationScreen({
    super.key,
    required this.pointId,
    required this.pointName,
  });

  @override
  State<PointConfirmationScreen> createState() =>
      _PointConfirmationScreenState();
}

class _PointConfirmationScreenState extends State<PointConfirmationScreen> {
  static const Color azulOscuro = Color(0xFF061B44);
  static const Color azulMedio = Color(0xFF073C85);
  static const Color azulPrincipal = Color(0xFF0866FF);
  static const Color fondo = Color(0xFFF4F7FB);
  static const Color naranja = Color(0xFFF59E0B);

  static const List<String> categoriasNovedad = [
    'Acceso',
    'Seguridad',
    'Infraestructura',
    'Equipamiento',
    'Iluminación',
    'Otro',
  ];

  static const List<String> gravedadesNovedad = [
    'Baja',
    'Media',
    'Alta',
    'Crítica',
  ];

  final TextEditingController observacionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool conNovedad = false;
  bool guardando = false;
  String? categoriaNovedad;
  String? gravedadNovedad;
  String? fotoNovedadPath;

  @override
  void initState() {
    super.initState();
    _recuperarImagenInterrumpida();
  }

  @override
  void dispose() {
    observacionController.dispose();
    super.dispose();
  }

  Future<void> _recuperarImagenInterrumpida() async {
    try {
      final LostDataResponse response = await _imagePicker.retrieveLostData();

      if (response.isEmpty || !mounted) {
        return;
      }

      final XFile? recoveredFile = response.files?.firstOrNull;

      if (recoveredFile != null) {
        setState(() {
          conNovedad = true;
          fotoNovedadPath = recoveredFile.path;
        });
      }
    } catch (_) {
      // La pantalla puede continuar sin la fotografía recuperada.
    }
  }

  Future<void> _mostrarOpcionesFoto() async {
    if (guardando) {
      return;
    }

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
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
                const SizedBox(height: 20),
                const Text(
                  'Agregar fotografía',
                  style: TextStyle(
                    color: azulOscuro,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(
                    Icons.photo_camera_outlined,
                    color: azulPrincipal,
                  ),
                  title: const Text('Tomar fotografía'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext, ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: azulPrincipal,
                  ),
                  title: const Text('Elegir desde galería'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext, ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) {
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
        requestFullMetadata: false,
      );

      if (image != null && mounted) {
        setState(() {
          fotoNovedadPath = image.path;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No fue posible obtener la fotografía. Revisa los permisos de cámara.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<String?> _guardarFotoPermanente() async {
    final String? sourcePath = fotoNovedadPath;

    if (sourcePath == null || sourcePath.isEmpty) {
      return null;
    }

    final File sourceFile = File(sourcePath);

    if (!await sourceFile.exists()) {
      throw StateError('La fotografía seleccionada ya no está disponible.');
    }

    final Directory supportDirectory = await getApplicationSupportDirectory();
    final Directory photosDirectory = Directory(
      '${supportDirectory.path}${Platform.pathSeparator}novelty_photos',
    );

    if (!await photosDirectory.exists()) {
      await photosDirectory.create(recursive: true);
    }

    final String rawExtension = sourcePath.contains('.')
        ? sourcePath.split('.').last.toLowerCase()
        : 'jpg';
    const Set<String> supportedExtensions = {
      'jpg',
      'jpeg',
      'png',
      'webp',
      'heic',
    };
    final String extension = supportedExtensions.contains(rawExtension)
        ? rawExtension
        : 'jpg';
    final String safePointId = widget.pointId.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]+'),
      '_',
    );
    final String destinationPath =
        '${photosDirectory.path}${Platform.pathSeparator}'
        'novelty_${safePointId}_${DateTime.now().microsecondsSinceEpoch}.'
        '$extension';

    final File savedFile = await sourceFile.copy(destinationPath);
    return savedFile.path;
  }

  Future<void> confirmarRegistro() async {
    if (guardando) {
      return;
    }

    final String observacion = observacionController.text.trim();

    if (conNovedad && (categoriaNovedad == null || gravedadNovedad == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona la categoría y la gravedad de la novedad.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (conNovedad && observacion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Describe brevemente la novedad antes de confirmar.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (RoundState.instance.isPointCompleted(widget.pointId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este punto ya fue registrado en la ronda actual.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      guardando = true;
    });

    try {
      final String? savedPhotoPath = conNovedad
          ? await _guardarFotoPermanente()
          : null;

      await RoundState.instance.completePoint(
        pointId: widget.pointId,
        hasNovelty: conNovedad,
        observation: observacion,
        noveltyCategory: categoriaNovedad,
        noveltySeverity: gravedadNovedad,
        noveltyPhotoPath: savedPhotoPath,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        guardando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No fue posible guardar la novedad o su fotografía. Intenta nuevamente.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RoundSummaryScreen(
          pointName: widget.pointName,
          pointStatus: conNovedad ? 'Con novedad' : 'Sin novedad',
          observation: observacion,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UserConfiguration configuration =
        UserConfigurationStore.instance.configuration;
    final RoundPoint? currentPoint = RoundState.instance.getPointById(
      widget.pointId,
    );
    final DateTime ahora = DateTime.now();

    final String fecha =
        '${ahora.day.toString().padLeft(2, '0')}/'
        '${ahora.month.toString().padLeft(2, '0')}/'
        '${ahora.year}';

    final String hora =
        '${ahora.hour.toString().padLeft(2, '0')}:'
        '${ahora.minute.toString().padLeft(2, '0')}';

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
                    onPressed: guardando ? null : () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Confirmar punto',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Selecciona el estado del punto y agrega una observación si es necesario.',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.help_outline_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.07),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF2FF),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: azulPrincipal,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.pointName,
                                      style: const TextStyle(
                                        color: azulOscuro,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      currentPoint?.description.isNotEmpty ==
                                              true
                                          ? currentPoint!.description
                                          : configuration
                                                .installationNameDisplay,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF667085),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                color: azulPrincipal,
                                size: 19,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                fecha,
                                style: const TextStyle(
                                  color: azulOscuro,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.access_time_rounded,
                                color: azulPrincipal,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                hora,
                                style: const TextStyle(
                                  color: azulOscuro,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Estado del punto',
                      style: TextStyle(
                        color: azulOscuro,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _StatusButton(
                            text: 'Sin novedad',
                            icon: Icons.check_circle_rounded,
                            selected: !conNovedad,
                            color: azulPrincipal,
                            onTap: guardando
                                ? () {}
                                : () {
                                    setState(() {
                                      conNovedad = false;
                                      categoriaNovedad = null;
                                      gravedadNovedad = null;
                                      fotoNovedadPath = null;
                                    });
                                  },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatusButton(
                            text: 'Con novedad',
                            icon: Icons.warning_amber_rounded,
                            selected: conNovedad,
                            color: naranja,
                            onTap: guardando
                                ? () {}
                                : () {
                                    setState(() {
                                      conNovedad = true;
                                    });
                                  },
                          ),
                        ),
                      ],
                    ),
                    if (conNovedad) ...[
                      const SizedBox(height: 26),
                      const Text(
                        'Detalle de la novedad',
                        style: TextStyle(
                          color: azulOscuro,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: categoriaNovedad,
                        decoration: InputDecoration(
                          labelText: 'Categoría',
                          prefixIcon: const Icon(
                            Icons.category_outlined,
                            color: azulPrincipal,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(
                              color: Color(0xFFD9E2F0),
                            ),
                          ),
                        ),
                        items: categoriasNovedad.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: guardando
                            ? null
                            : (value) {
                                setState(() {
                                  categoriaNovedad = value;
                                });
                              },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: gravedadNovedad,
                        decoration: InputDecoration(
                          labelText: 'Gravedad',
                          prefixIcon: const Icon(
                            Icons.priority_high_rounded,
                            color: naranja,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(
                              color: Color(0xFFD9E2F0),
                            ),
                          ),
                        ),
                        items: gravedadesNovedad.map((severity) {
                          return DropdownMenuItem(
                            value: severity,
                            child: Text(severity),
                          );
                        }).toList(),
                        onChanged: guardando
                            ? null
                            : (value) {
                                setState(() {
                                  gravedadNovedad = value;
                                });
                              },
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFD9E2F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.photo_camera_outlined,
                                  color: azulPrincipal,
                                ),
                                SizedBox(width: 9),
                                Text(
                                  'Fotografía (opcional)',
                                  style: TextStyle(
                                    color: azulOscuro,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (fotoNovedadPath != null) ...[
                              const SizedBox(height: 13),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: Image.file(
                                  File(fotoNovedadPath!),
                                  width: double.infinity,
                                  height: 190,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) {
                                    return Container(
                                      height: 130,
                                      alignment: Alignment.center,
                                      color: const Color(0xFFF2F4F7),
                                      child: const Text(
                                        'No fue posible mostrar la fotografía.',
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: guardando
                                          ? null
                                          : _mostrarOpcionesFoto,
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text('Cambiar'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: guardando
                                          ? null
                                          : () {
                                              setState(() {
                                                fotoNovedadPath = null;
                                              });
                                            },
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                      ),
                                      label: const Text('Quitar'),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Puedes tomar una foto o elegirla desde la galería.',
                                style: TextStyle(
                                  color: Color(0xFF667085),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 11),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: guardando
                                      ? null
                                      : _mostrarOpcionesFoto,
                                  icon: const Icon(Icons.add_a_photo_outlined),
                                  label: const Text('Agregar fotografía'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: azulPrincipal,
                                    side: const BorderSide(
                                      color: azulPrincipal,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        const Text(
                          'Observaciones',
                          style: TextStyle(
                            color: azulOscuro,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          conNovedad ? '(obligatoria)' : '(opcional)',
                          style: TextStyle(
                            color: conNovedad ? naranja : Colors.grey.shade600,
                            fontSize: 13,
                            fontWeight: conNovedad
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: observacionController,
                      enabled: !guardando,
                      maxLines: 5,
                      maxLength: 200,
                      decoration: InputDecoration(
                        hintText: conNovedad
                            ? 'Describe la novedad encontrada...'
                            : 'Escribe una observación si es necesario...',
                        hintStyle: const TextStyle(color: Color(0xFF98A2B3)),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFD9E2F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFD9E2F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: azulPrincipal,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: azulPrincipal,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Al confirmar, el punto cambiará a completado en la pantalla de inicio.',
                              style: TextStyle(
                                color: azulOscuro,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: guardando ? null : confirmarRegistro,
                        icon: guardando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.verified_user_rounded),
                        label: Text(
                          guardando ? 'Guardando...' : 'Confirmar registro',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: azulPrincipal,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: azulPrincipal.withValues(
                            alpha: 0.65,
                          ),
                          elevation: 8,
                          shadowColor: azulPrincipal.withValues(alpha: 0.35),
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
          ],
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _StatusButton({
    required this.text,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : const Color(0xFFD9E2F0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? Colors.white : color, size: 21),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF061B44),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
