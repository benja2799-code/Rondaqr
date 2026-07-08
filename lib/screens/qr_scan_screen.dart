import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as image_scanner;
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart' as live_scanner;

import 'package:rondaqr/control_points.dart';
import 'package:rondaqr/round_state.dart';
import 'point_confirmation_screen.dart';

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen>
    with WidgetsBindingObserver {
  static const Color azulOscuro = Color(0xFF061B44);
  static const Color azulMedio = Color(0xFF073C85);
  static const Color azulClaro = Color(0xFF48A7FF);
  static const Color verde = Color(0xFF16A36A);

  final ImagePicker _imagePicker = ImagePicker();
  final image_scanner.MobileScannerController _imageAnalyzer =
      image_scanner.MobileScannerController(
        autoStart: false,
        formats: const [image_scanner.BarcodeFormat.qrCode],
      );

  late GlobalKey<State<StatefulWidget>> _qrViewKey;
  live_scanner.QRViewController? _liveCameraController;
  StreamSubscription<live_scanner.Barcode>? _scanSubscription;

  bool _processingPoint = false;
  bool _analyzingPhoto = false;
  bool _cameraInitializing = true;
  bool _cameraReady = false;
  bool _permissionGranted = false;
  String? _cameraError;
  int _scannerGeneration = 0;

  GlobalKey<State<StatefulWidget>> _createQrViewKey() {
    return GlobalKey<State<StatefulWidget>>(
      debugLabel: 'RondaQRScanner$_scannerGeneration',
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _qrViewKey = _createQrViewKey();
    _recoverInterruptedQrPhoto();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_scanSubscription?.cancel());
    unawaited(_imageAnalyzer.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final live_scanner.QRViewController? controller = _liveCameraController;

    if (controller == null || controller.disposed) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (_permissionGranted &&
          !_processingPoint &&
          !_analyzingPhoto &&
          !RoundState.instance.allPointsCompleted) {
        unawaited(_resumeLiveCamera());
      }
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_pauseLiveCamera());
    }
  }

  Future<void> abrirConfirmacion(BuildContext context, RoundPoint point) async {
    if (_processingPoint) {
      return;
    }

    final RoundState roundState = RoundState.instance;

    if (point.completed) {
      _showMessage(context, '${point.name} ya fue registrado en esta ronda.');
      return;
    }

    _processingPoint = true;
    await _pauseLiveCamera();

    if (!context.mounted) {
      _processingPoint = false;
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PointConfirmationScreen(pointId: point.id, pointName: point.name),
      ),
    );

    if (!mounted) {
      return;
    }

    _processingPoint = false;

    if (!roundState.allPointsCompleted) {
      await _resumeLiveCamera();
    }
  }

  Future<void> _handleLiveDetection(live_scanner.Barcode barcode) async {
    await _processQrValue(barcode.code);
  }

  Future<void> _processQrValue(String? value) async {
    if (_processingPoint) {
      return;
    }

    final String? rawValue = value?.trim();

    if (rawValue == null || rawValue.isEmpty) {
      _showMessage(context, 'QR inválido. No fue posible leer su contenido.');
      return;
    }

    final String normalizedValue = rawValue.toUpperCase();

    if (!normalizedValue.startsWith('RONDAQR:')) {
      _showMessage(context, 'QR inválido. Usa un código oficial de RondaQR.');
      return;
    }

    final String qrIdentifier = ControlPointDefinition.normalizeQrIdentifier(
      normalizedValue,
    );
    final RoundPoint? point = RoundState.instance.getPointByQrIdentifier(
      qrIdentifier,
    );

    if (point == null) {
      _showMessage(
        context,
        'El QR corresponde a un punto inexistente, inactivo o fuera de esta ronda.',
      );
      return;
    }

    await abrirConfirmacion(context, point);
  }

  void _onQrViewCreated(live_scanner.QRViewController controller) {
    _liveCameraController = controller;
    unawaited(_scanSubscription?.cancel());
    _scanSubscription = controller.scannedDataStream.listen(
      _handleLiveDetection,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Error leyendo QR en vivo: $error');
        debugPrintStack(stackTrace: stackTrace);

        if (mounted) {
          setState(() {
            _cameraInitializing = false;
            _cameraReady = false;
            _cameraError =
                'No fue posible iniciar la cámara en vivo. Intenta nuevamente.';
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _cameraInitializing = false;
        _cameraReady = controller.hasPermissions;
        if (controller.hasPermissions) {
          _permissionGranted = true;
          _cameraError = null;
        }
      });
    }
  }

  void _onPermissionSet(
    live_scanner.QRViewController controller,
    bool granted,
  ) {
    if (!mounted || controller != _liveCameraController) {
      return;
    }

    setState(() {
      _cameraInitializing = false;
      _permissionGranted = granted;
      _cameraReady = granted;
      _cameraError = granted
          ? null
          : 'Permiso de cámara rechazado. Habilítalo en los ajustes de la aplicación.';
    });

    if (granted) {
      unawaited(_resumeLiveCamera());
    }
  }

  Future<void> _pauseLiveCamera() async {
    final live_scanner.QRViewController? controller = _liveCameraController;

    if (controller == null || controller.disposed) {
      return;
    }

    try {
      await controller.pauseCamera();
    } catch (error) {
      debugPrint('No fue posible pausar la cámara QR: $error');
    }
  }

  Future<void> _resumeLiveCamera() async {
    final live_scanner.QRViewController? controller = _liveCameraController;

    if (controller == null || controller.disposed || !_permissionGranted) {
      return;
    }

    try {
      await controller.resumeCamera();

      if (mounted) {
        setState(() {
          _cameraInitializing = false;
          _cameraReady = true;
          _cameraError = null;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('No fue posible reanudar la cámara QR: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        setState(() {
          _cameraInitializing = false;
          _cameraReady = false;
          _cameraError =
              'No fue posible abrir la cámara. Toca “Reintentar cámara”.';
        });
      }
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _recoverInterruptedQrPhoto() async {
    try {
      final LostDataResponse response = await _imagePicker.retrieveLostData();

      if (response.isEmpty || !mounted) {
        return;
      }

      final XFile? recoveredImage = response.files?.firstOrNull;

      if (recoveredImage != null) {
        await _analyzeQrPhoto(recoveredImage);
      }
    } catch (error) {
      debugPrint('No fue posible recuperar la foto del QR: $error');
    }
  }

  Future<void> _scanWithSystemCamera() async {
    if (_analyzingPhoto || _processingPoint) {
      return;
    }

    setState(() {
      _analyzingPhoto = true;
    });

    try {
      await _pauseLiveCamera();
      await Future<void>.delayed(const Duration(milliseconds: 250));

      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 90,
        requestFullMetadata: false,
      );

      if (photo == null || !mounted) {
        return;
      }

      await _analyzeQrPhoto(photo);
    } catch (error, stackTrace) {
      debugPrint('Error usando la cámara del teléfono: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        _showMessage(
          context,
          'No fue posible tomar la foto. Revisa el permiso de cámara.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _analyzingPhoto = false;
        });

        if (!_processingPoint && !RoundState.instance.allPointsCompleted) {
          await _resumeLiveCamera();
        }
      }
    }
  }

  Future<void> _analyzeQrPhoto(XFile photo) async {
    try {
      final image_scanner.BarcodeCapture? capture = await _imageAnalyzer
          .analyzeImage(
            photo.path,
            formats: const [image_scanner.BarcodeFormat.qrCode],
          );

      if (!mounted) {
        return;
      }

      if (capture == null || capture.barcodes.isEmpty) {
        _showMessage(
          context,
          'No se encontró un código QR legible en la foto. '
          'Acércate al código e intenta nuevamente.',
        );
        return;
      }

      await _processQrValue(
        capture.barcodes
            .map((image_scanner.Barcode barcode) => barcode.rawValue)
            .firstWhere(
              (String? value) => value != null && value.trim().isNotEmpty,
              orElse: () => null,
            ),
      );
    } catch (error, stackTrace) {
      debugPrint('No fue posible analizar la foto del QR: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        _showMessage(
          context,
          'No fue posible leer el QR de la foto. Intenta nuevamente.',
        );
      }
    }
  }

  void mostrarAyuda(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Cómo escanear'),
          content: const Text(
            'Ubica el código QR dentro del recuadro. '
            'La aplicación solicitará permiso para usar la cámara. '
            'La lectura es automática y no guarda una fotografía del código.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _retryCamera() async {
    await _pauseLiveCamera();
    await _scanSubscription?.cancel();

    if (!mounted) {
      return;
    }

    setState(() {
      _scannerGeneration++;
      _qrViewKey = _createQrViewKey();
      _liveCameraController = null;
      _scanSubscription = null;
      _cameraInitializing = true;
      _cameraReady = false;
      _cameraError = null;
    });

    _showMessage(context, 'Reiniciando cámara...');
  }

  Widget _buildCameraError(BuildContext context) {
    return Container(
      color: azulOscuro,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.no_photography_outlined,
            color: Colors.white,
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            _cameraError ??
                'No fue posible abrir la cámara. Intenta nuevamente.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          if (_analyzingPhoto)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          else ...[
            ElevatedButton.icon(
              onPressed: _scanWithSystemCamera,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Usar cámara del teléfono'),
              style: ElevatedButton.styleFrom(
                backgroundColor: azulClaro,
                foregroundColor: azulOscuro,
              ),
            ),
            TextButton(
              onPressed: _retryCamera,
              child: const Text(
                'Reintentar cámara',
                style: TextStyle(color: azulClaro),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final RoundState roundState = RoundState.instance;

    return AnimatedBuilder(
      animation: roundState,
      builder: (context, _) {
        final int completed = roundState.completedPoints;
        final int total = roundState.totalPoints;

        return Scaffold(
          backgroundColor: azulOscuro,
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [azulOscuro, Color(0xFF082B64), azulMedio],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: 110,
                    left: -90,
                    child: _DecorativeCircle(size: 240, opacity: 0.05),
                  ),
                  Positioned(
                    bottom: 70,
                    right: -100,
                    child: _DecorativeCircle(size: 280, opacity: 0.05),
                  ),
                  Column(
                    children: [
                      Container(
                        height: 72,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
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
                                'Escanear QR',
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
                                mostrarAyuda(context);
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
                          padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$completed de $total puntos completados',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              const Text(
                                'Ubica el código dentro\ndel recuadro',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'El punto se identificará automáticamente.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 36),
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 280,
                                    height: 280,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 230,
                                    height: 230,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.08,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 235,
                                    height: 235,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.03,
                                      ),
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              28,
                                            ),
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                live_scanner.QRView(
                                                  key: _qrViewKey,
                                                  onQRViewCreated:
                                                      _onQrViewCreated,
                                                  onPermissionSet:
                                                      _onPermissionSet,
                                                  cameraFacing: live_scanner
                                                      .CameraFacing
                                                      .back,
                                                  formatsAllowed: const [
                                                    live_scanner
                                                        .BarcodeFormat
                                                        .qrcode,
                                                  ],
                                                ),
                                                if (_cameraInitializing)
                                                  const ColoredBox(
                                                    color: azulOscuro,
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                            color: azulClaro,
                                                            strokeWidth: 2.5,
                                                          ),
                                                    ),
                                                  ),
                                                if (_cameraError != null)
                                                  _buildCameraError(context),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const Positioned(
                                          top: 0,
                                          left: 0,
                                          child: _ScannerCorner(
                                            type: _CornerType.topLeft,
                                          ),
                                        ),
                                        const Positioned(
                                          top: 0,
                                          right: 0,
                                          child: _ScannerCorner(
                                            type: _CornerType.topRight,
                                          ),
                                        ),
                                        const Positioned(
                                          bottom: 0,
                                          left: 0,
                                          child: _ScannerCorner(
                                            type: _CornerType.bottomLeft,
                                          ),
                                        ),
                                        const Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: _ScannerCorner(
                                            type: _CornerType.bottomRight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 38),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.10),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      color: azulClaro,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        completed == total
                                            ? 'Todos los puntos ya fueron registrados.'
                                            : 'La cámara leerá automáticamente el QR real del punto.',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.80,
                                          ),
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: OutlinedButton.icon(
                                  onPressed:
                                      completed == total || _analyzingPhoto
                                      ? null
                                      : _scanWithSystemCamera,
                                  icon: _analyzingPhoto
                                      ? const SizedBox(
                                          width: 19,
                                          height: 19,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.3,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.photo_camera_outlined),
                                  label: Text(
                                    _analyzingPhoto
                                        ? 'Leyendo QR...'
                                        : 'Escanear tomando una foto',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    disabledForegroundColor: Colors.white60,
                                    side: BorderSide(
                                      color: azulClaro.withValues(alpha: 0.75),
                                      width: 1.3,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Builder(
                                builder: (context) {
                                  final bool hasError = _cameraError != null;
                                  final String status = completed == total
                                      ? 'Ronda completada'
                                      : _analyzingPhoto
                                      ? 'Analizando fotografía...'
                                      : hasError
                                      ? 'Cámara no disponible · toca Reintentar cámara'
                                      : _cameraInitializing
                                      ? 'Iniciando cámara...'
                                      : _cameraReady
                                      ? 'Cámara activa · lectura automática'
                                      : 'Preparando cámara...';
                                  final Color statusColor = hasError
                                      ? azulClaro
                                      : verde;

                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        hasError
                                            ? Icons.info_outline_rounded
                                            : Icons.camera_alt_outlined,
                                        color: statusColor,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 7),
                                      Flexible(
                                        child: Text(
                                          status,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.78,
                                            ),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _CornerType { topLeft, topRight, bottomLeft, bottomRight }

class _ScannerCorner extends StatelessWidget {
  final _CornerType type;

  const _ScannerCorner({required this.type});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: CustomPaint(painter: _ScannerCornerPainter(type)),
    );
  }
}

class _ScannerCornerPainter extends CustomPainter {
  final _CornerType type;

  _ScannerCornerPainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF2180FF)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final Path path = Path();

    switch (type) {
      case _CornerType.topLeft:
        path.moveTo(0, size.height * 0.75);
        path.lineTo(0, 0);
        path.lineTo(size.width * 0.75, 0);
        break;
      case _CornerType.topRight:
        path.moveTo(size.width * 0.25, 0);
        path.lineTo(size.width, 0);
        path.lineTo(size.width, size.height * 0.75);
        break;
      case _CornerType.bottomLeft:
        path.moveTo(0, size.height * 0.25);
        path.lineTo(0, size.height);
        path.lineTo(size.width * 0.75, size.height);
        break;
      case _CornerType.bottomRight:
        path.moveTo(size.width * 0.25, size.height);
        path.lineTo(size.width, size.height);
        path.lineTo(size.width, size.height * 0.25);
        break;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class _DecorativeCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _DecorativeCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: opacity),
          width: 38,
        ),
      ),
    );
  }
}
