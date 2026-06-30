import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:rondaqr/control_points.dart';
import 'package:rondaqr/round_state.dart';
import 'point_confirmation_screen.dart';

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  static const Color azulOscuro = Color(0xFF061B44);
  static const Color azulMedio = Color(0xFF073C85);
  static const Color azulPrincipal = Color(0xFF0866FF);
  static const Color azulClaro = Color(0xFF48A7FF);
  static const Color verde = Color(0xFF16A36A);

  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _processingPoint = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
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

    try {
      await _scannerController.stop();
    } on MobileScannerException {
      // La navegación puede continuar aunque la cámara ya esté detenida.
    }

    if (!context.mounted) {
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
      await _startCamera(showReadyMessage: false);
    }
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_processingPoint || capture.barcodes.isEmpty) {
      return;
    }

    final String? rawValue = capture.barcodes.first.rawValue?.trim();

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

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void mostrarSelectorPuntos(BuildContext context) {
    final RoundState roundState = RoundState.instance;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return AnimatedBuilder(
          animation: roundState,
          builder: (context, _) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
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
                      'Simular punto QR',
                      style: TextStyle(
                        color: azulOscuro,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Selecciona el punto que deseas registrar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF667085), fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    ...roundState.points.map((point) {
                      return _PointSelectorCard(
                        name: point.name,
                        icon: point.icon,
                        completed: point.completed,
                        onTap: () {
                          if (point.completed) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${point.name} ya fue completado.',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }

                          Navigator.pop(bottomSheetContext);

                          abrirConfirmacion(context, point);
                        },
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
            'También puedes usar "Simular QR escaneado" durante las pruebas.',
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

  Future<void> escanearAhora(BuildContext context) async {
    if (_scannerController.value.isRunning) {
      _showMessage(
        context,
        'La cámara está activa. Ubica el QR dentro del recuadro.',
      );
      return;
    }

    await _startCamera(showReadyMessage: true);
  }

  Future<void> _startCamera({required bool showReadyMessage}) async {
    try {
      await _scannerController.start();

      if (showReadyMessage && mounted) {
        _showMessage(context, 'Cámara lista. Ubica el QR dentro del recuadro.');
      }
    } on MobileScannerException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(context, _cameraErrorMessage(error));
    }
  }

  String _cameraErrorMessage(MobileScannerException error) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'Permiso de cámara rechazado. '
            'Habilítalo en los ajustes de la aplicación.';
      case MobileScannerErrorCode.unsupported:
        return 'La cámara no está disponible en este dispositivo.';
      default:
        return 'No fue posible iniciar la cámara. '
            'Verifica que no esté siendo usada por otra aplicación.';
    }
  }

  Widget _buildCameraError(BuildContext context, MobileScannerException error) {
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
            _cameraErrorMessage(error),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              escanearAhora(context);
            },
            child: const Text('Reintentar', style: TextStyle(color: azulClaro)),
          ),
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
                                            child: MobileScanner(
                                              controller: _scannerController,
                                              fit: BoxFit.cover,
                                              onDetect: _handleDetection,
                                              errorBuilder: _buildCameraError,
                                              placeholderBuilder: (context) {
                                                return const ColoredBox(
                                                  color: azulOscuro,
                                                  child: Center(
                                                    child: Icon(
                                                      Icons.qr_code_2_rounded,
                                                      size: 112,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                );
                                              },
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
                                            : 'Escanea el QR del punto o usa la simulación para pruebas.',
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
                              const SizedBox(height: 28),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton.icon(
                                  onPressed: completed == total
                                      ? null
                                      : () {
                                          escanearAhora(context);
                                        },
                                  icon: const Icon(
                                    Icons.qr_code_scanner_rounded,
                                  ),
                                  label: const Text('Escanear ahora'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: azulPrincipal,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: Colors.white24,
                                    disabledForegroundColor: Colors.white60,
                                    elevation: 9,
                                    shadowColor: azulPrincipal.withValues(
                                      alpha: 0.35,
                                    ),
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
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: OutlinedButton.icon(
                                  onPressed: completed == total
                                      ? null
                                      : () {
                                          mostrarSelectorPuntos(context);
                                        },
                                  icon: Icon(
                                    completed == total
                                        ? Icons.check_circle_rounded
                                        : Icons.developer_mode_rounded,
                                  ),
                                  label: Text(
                                    completed == total
                                        ? 'Todos los puntos completados'
                                        : 'Simular QR escaneado',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: completed == total
                                        ? verde
                                        : Colors.white,
                                    disabledForegroundColor: verde,
                                    side: BorderSide(
                                      color: completed == total
                                          ? verde
                                          : azulClaro.withValues(alpha: 0.75),
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
                              Text(
                                'Modo de desarrollo',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 12,
                                ),
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

class _PointSelectorCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool completed;
  final VoidCallback onTap;

  const _PointSelectorCard({
    required this.name,
    required this.icon,
    required this.completed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color azulOscuro = Color(0xFF061B44);
    const Color azulPrincipal = Color(0xFF0866FF);
    const Color verde = Color(0xFF16A36A);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: completed ? const Color(0xFFF3FBF7) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: completed
                        ? const Color(0xFFE8F8F0)
                        : const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    completed ? Icons.check_circle_rounded : icon,
                    color: completed ? verde : azulPrincipal,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: azulOscuro,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (completed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F8F0),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'Completado',
                      style: TextStyle(
                        color: verde,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF98A2B3),
                  ),
              ],
            ),
          ),
        ),
      ),
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
