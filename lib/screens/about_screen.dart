import 'package:flutter/material.dart';

import '../app_info.dart';
import '../services/supabase_service.dart';

class AboutRondaQrScreen extends StatelessWidget {
  const AboutRondaQrScreen({super.key});

  static const Color _darkBlue = Color(0xFF061B44);
  static const Color _mediumBlue = Color(0xFF073C85);
  static const Color _primaryBlue = Color(0xFF0866FF);
  static const Color _background = Color(0xFFF4F7FB);

  static const List<String> _features = <String>[
    'Control de turnos.',
    'Rondas mediante códigos QR.',
    'Registro de novedades.',
    'Historial de rondas.',
    'Reportes.',
    'Administración de puntos de control.',
    'Acceso rápido mediante PIN.',
  ];

  @override
  Widget build(BuildContext context) {
    final String operationMode = SupabaseService.instance.isConfigured
        ? 'Conectado con Supabase.'
        : 'Modo local sin conexión a Supabase.';

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[_darkBlue, _mediumBlue],
                ),
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Acerca de RondaQR',
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
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                child: Column(
                  children: <Widget>[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[_primaryBlue, _mediumBlue],
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        children: <Widget>[
                          Container(
                            width: 90,
                            height: 90,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Image.asset(
                              'assets/images/rondaqr_icon_minimal.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            RondaQrAppInfo.appName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            RondaQrAppInfo.company,
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 10),
                          FutureBuilder<String>(
                            future: RondaQrAppInfo.version,
                            builder:
                                (
                                  BuildContext context,
                                  AsyncSnapshot<String> snapshot,
                                ) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Text(
                                      'Versión ${snapshot.data ?? 'Cargando…'}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _InfoCard(
                      title: 'Descripción',
                      icon: Icons.info_outline_rounded,
                      child: Text(
                        'Aplicación para el control y trazabilidad de rondas de seguridad mediante códigos QR.',
                        style: TextStyle(color: Color(0xFF344054), height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _InfoCard(
                      title: 'Funciones principales',
                      icon: Icons.checklist_rounded,
                      child: Column(
                        children: _features
                            .map((String feature) => _Feature(text: feature))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _InfoCard(
                      title: 'Modo de operación',
                      icon: Icons.cloud_done_outlined,
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF12B76A),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              operationMode,
                              style: const TextStyle(
                                color: Color(0xFF344054),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
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

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: AboutRondaQrScreen._primaryBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AboutRondaQrScreen._darkBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final String text;

  const _Feature({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF12B76A),
              size: 18,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF344054), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
