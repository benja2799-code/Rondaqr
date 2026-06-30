import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const Color azulOscuro = Color(0xFF061B44);
  static const Color azulMedio = Color(0xFF073C85);
  static const Color azulPrincipal = Color(0xFF0866FF);
  static const Color fondo = Color(0xFFF4F7FB);
  static const Color verde = Color(0xFF16A36A);
  static const Color naranja = Color(0xFFF59E0B);

  final List<Map<String, dynamic>> notificaciones = [
    {
      'titulo': 'Ronda pendiente',
      'mensaje': 'Recuerda completar la ronda programada para este turno.',
      'hora': 'Hace 10 min',
      'icono': Icons.schedule_rounded,
      'color': naranja,
      'leida': false,
    },
    {
      'titulo': 'Punto registrado',
      'mensaje': 'Acceso principal fue registrado correctamente.',
      'hora': 'Hace 25 min',
      'icono': Icons.check_circle_rounded,
      'color': verde,
      'leida': false,
    },
    {
      'titulo': 'Novedad registrada',
      'mensaje': 'Se registró una novedad en el estacionamiento.',
      'hora': 'Ayer · 18:40',
      'icono': Icons.warning_amber_rounded,
      'color': naranja,
      'leida': true,
    },
    {
      'titulo': 'Ronda finalizada',
      'mensaje': 'La ronda del turno anterior fue completada.',
      'hora': 'Ayer · 10:35',
      'icono': Icons.verified_rounded,
      'color': verde,
      'leida': true,
    },
  ];

  void marcarTodasComoLeidas() {
    setState(() {
      for (final notificacion in notificaciones) {
        notificacion['leida'] = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Todas las notificaciones fueron marcadas como leídas.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void abrirNotificacion(int index) {
    setState(() {
      notificaciones[index]['leida'] = true;
    });

    final notificacion = notificaciones[index];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                const SizedBox(height: 22),
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: (notificacion['color'] as Color).withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    notificacion['icono'] as IconData,
                    color: notificacion['color'] as Color,
                    size: 31,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  notificacion['titulo'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: azulOscuro,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  notificacion['mensaje'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  notificacion['hora'] as String,
                  style: const TextStyle(
                    color: Color(0xFF98A2B3),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: azulPrincipal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Entendido',
                      style: TextStyle(fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    final int noLeidas = notificaciones
        .where((item) => item['leida'] == false)
        .length;

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
                      'Notificaciones',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: noLeidas == 0 ? null : marcarTodasComoLeidas,
                    icon: Icon(
                      Icons.done_all_rounded,
                      color: noLeidas == 0 ? Colors.white38 : Colors.white,
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
                          color: azulPrincipal.withValues(alpha: 0.22),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.notifications_active_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Centro de notificaciones',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                noLeidas == 0
                                    ? 'No tienes notificaciones pendientes.'
                                    : 'Tienes $noLeidas notificaciones sin leer.',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Notificaciones recientes',
                          style: TextStyle(
                            color: azulOscuro,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (noLeidas > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF2FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$noLeidas nuevas',
                            style: const TextStyle(
                              color: azulPrincipal,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...List.generate(notificaciones.length, (index) {
                    final notificacion = notificaciones[index];

                    return _NotificationCard(
                      title: notificacion['titulo'] as String,
                      message: notificacion['mensaje'] as String,
                      time: notificacion['hora'] as String,
                      icon: notificacion['icono'] as IconData,
                      color: notificacion['color'] as Color,
                      read: notificacion['leida'] as bool,
                      onTap: () => abrirNotificacion(index),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final String title;
  final String message;
  final String time;
  final IconData icon;
  final Color color;
  final bool read;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    required this.color,
    required this.read,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: read ? Colors.white : const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(17),
        elevation: read ? 1 : 3,
        shadowColor: Colors.black.withValues(alpha: 0.07),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(icon, color: color, size: 26),
                    ),
                    if (!read)
                      const Positioned(
                        top: -3,
                        right: -3,
                        child: CircleAvatar(
                          radius: 6,
                          backgroundColor: Color(0xFF0866FF),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: const Color(0xFF061B44),
                          fontSize: 15,
                          fontWeight: read ? FontWeight.w600 : FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        time,
                        style: const TextStyle(
                          color: Color(0xFF98A2B3),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
