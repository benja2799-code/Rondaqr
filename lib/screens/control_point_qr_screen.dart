import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../control_points.dart';
import '../user_configuration.dart';

class ControlPointQrScreen extends StatefulWidget {
  final ControlPointDefinition point;

  const ControlPointQrScreen({super.key, required this.point});

  @override
  State<ControlPointQrScreen> createState() => _ControlPointQrScreenState();
}

class _ControlPointQrScreenState extends State<ControlPointQrScreen> {
  static const Color azulOscuro = Color(0xFF061B44);
  static const Color azulMedio = Color(0xFF073C85);
  static const Color azulPrincipal = Color(0xFF0866FF);
  static const Color fondo = Color(0xFFF4F7FB);

  final GlobalKey _labelKey = GlobalKey();

  bool _processingImage = false;

  Future<File> _createTemporaryPng() async {
    await WidgetsBinding.instance.endOfFrame;

    final BuildContext? labelContext = _labelKey.currentContext;
    final RenderObject? renderObject = labelContext?.findRenderObject();

    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('La etiqueta todavía no está lista.');
    }

    final ui.Image image = await renderObject.toImage(pixelRatio: 3);

    try {
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        throw StateError('No fue posible generar la imagen PNG.');
      }

      final Directory temporaryDirectory = await getTemporaryDirectory();
      final String safeIdentifier = widget.point.qrIdentifier
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
      final File imageFile = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}'
        'rondaqr_$safeIdentifier.png',
      );

      await imageFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

      return imageFile;
    } finally {
      image.dispose();
    }
  }

  Future<void> _saveTemporaryImage() async {
    if (_processingImage) {
      return;
    }

    setState(() {
      _processingImage = true;
    });

    try {
      final File file = await _createTemporaryPng();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imagen temporal preparada: ${file.uri.pathSegments.last}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (mounted) {
        _showImageError();
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingImage = false;
        });
      }
    }
  }

  Future<void> _sharePng() async {
    if (_processingImage) {
      return;
    }

    setState(() {
      _processingImage = true;
    });

    try {
      final File file = await _createTemporaryPng();

      if (!mounted) {
        return;
      }

      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      final Rect? shareOrigin = renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;

      await SharePlus.instance.share(
        ShareParams(
          title: 'QR ${widget.point.name}',
          subject: 'Código QR de ${widget.point.name}',
          text:
              '${widget.point.name}\n'
              '${widget.point.qrContent}',
          files: [
            XFile(
              file.path,
              mimeType: 'image/png',
              name: file.uri.pathSegments.last,
            ),
          ],
          sharePositionOrigin: shareOrigin,
        ),
      );
    } catch (_) {
      if (mounted) {
        _showImageError();
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingImage = false;
        });
      }
    }
  }

  void _showImageError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No fue posible generar la imagen del QR. Intenta nuevamente.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
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
                        onPressed: _processingImage
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Código QR',
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
                        const Row(
                          children: [
                            Icon(Icons.print_outlined, color: azulPrincipal),
                            SizedBox(width: 9),
                            Text(
                              'Etiqueta lista para imprimir',
                              style: TextStyle(
                                color: azulOscuro,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        RepaintBoundary(
                          key: _labelKey,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFFD0D5DD),
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: azulOscuro,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.shield_rounded,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 9),
                                      Text(
                                        'RondaQR',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  configuration.installationNameDisplay,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: azulMedio,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  widget.point.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: azulOscuro,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (widget.point.description.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    widget.point.description,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF667085),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final double availableSize =
                                        constraints.maxWidth - 24;
                                    final double qrSize = availableSize < 250
                                        ? availableSize
                                        : 250;

                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      color: Colors.white,
                                      child: QrImageView(
                                        data: widget.point.qrContent,
                                        version: QrVersions.auto,
                                        size: qrSize,
                                        padding: EdgeInsets.zero,
                                        backgroundColor: Colors.white,
                                        errorCorrectionLevel:
                                            QrErrorCorrectLevel.M,
                                        eyeStyle: const QrEyeStyle(
                                          eyeShape: QrEyeShape.square,
                                          color: Colors.black,
                                        ),
                                        dataModuleStyle:
                                            const QrDataModuleStyle(
                                              dataModuleShape:
                                                  QrDataModuleShape.square,
                                              color: Colors.black,
                                            ),
                                        semanticsLabel:
                                            'Código QR de ${widget.point.name}',
                                        errorStateBuilder: (_, _) {
                                          return SizedBox(
                                            width: qrSize,
                                            height: qrSize,
                                            child: const Center(
                                              child: Text(
                                                'No fue posible generar el QR.',
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'IDENTIFICADOR QR',
                                  style: TextStyle(
                                    color: Color(0xFF667085),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  widget.point.qrContent,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: azulOscuro,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                const Text(
                                  'Escanea este código desde la aplicación '
                                  'RondaQR para registrar el punto.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF98A2B3),
                                    fontSize: 10,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF2FF),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: azulPrincipal,
                              ),
                              SizedBox(width: 11),
                              Expanded(
                                child: Text(
                                  'La imagen se guarda únicamente en la '
                                  'carpeta temporal de la aplicación. No se '
                                  'requieren permisos de almacenamiento.',
                                  style: TextStyle(
                                    color: azulOscuro,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton.icon(
                            onPressed: _processingImage ? null : _sharePng,
                            icon: _processingImage
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.share_rounded),
                            label: Text(
                              _processingImage
                                  ? 'Preparando imagen...'
                                  : 'Compartir QR como PNG',
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
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _processingImage
                                ? null
                                : _saveTemporaryImage,
                            icon: const Icon(Icons.image_outlined),
                            label: const Text('Guardar temporalmente'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: azulPrincipal,
                              side: const BorderSide(color: azulPrincipal),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
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
      },
    );
  }
}
