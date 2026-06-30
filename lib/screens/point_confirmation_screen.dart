import 'package:flutter/material.dart';

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

  final TextEditingController observacionController = TextEditingController();

  bool conNovedad = false;
  bool guardando = false;

  @override
  void dispose() {
    observacionController.dispose();
    super.dispose();
  }

  Future<void> confirmarRegistro() async {
    if (guardando) {
      return;
    }

    final String observacion = observacionController.text.trim();

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

    await RoundState.instance.completePoint(
      pointId: widget.pointId,
      hasNovelty: conNovedad,
      observation: observacion,
    );

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
