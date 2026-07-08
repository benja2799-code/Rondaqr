import 'package:flutter/material.dart';

import '../round_history.dart';

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
  static const Color naranja = Color(0xFFF59E0B);

  final Set<String> _readNotificationIds = {};

  List<_NoveltyNotification> _buildNotifications(
    List<RoundHistoryItem> rounds,
  ) {
    final List<_NoveltyNotification> notifications = [];

    for (final RoundHistoryItem round in rounds) {
      int noveltyPoints = 0;

      for (int index = 0; index < round.points.length; index++) {
        final RoundHistoryPoint point = round.points[index];

        if (!point.hasNovelty) {
          continue;
        }

        noveltyPoints++;

        final DateTime registeredAt = point.completedAt ?? round.finishedAt;
        final List<String> details = [
          if (point.noveltyCategory?.trim().isNotEmpty ?? false)
            point.noveltyCategory!.trim(),
          if (point.noveltySeverity?.trim().isNotEmpty ?? false)
            'Gravedad ${point.noveltySeverity!.trim().toLowerCase()}',
        ];
        final String observation = point.observation.trim();

        notifications.add(
          _NoveltyNotification(
            id: '${round.id}:$index:${registeredAt.microsecondsSinceEpoch}',
            title: 'Novedad en ${point.name}',
            message: observation.isNotEmpty
                ? observation
                : details.isNotEmpty
                ? details.join(' · ')
                : 'Se registró una novedad durante la ronda.',
            registeredAt: registeredAt,
            installation: round.installation,
            guardName: round.guardName,
          ),
        );
      }

      if (noveltyPoints == 0 && round.noveltyCount > 0) {
        notifications.add(
          _NoveltyNotification(
            id: '${round.id}:general',
            title: 'Ronda con novedades',
            message:
                'Esta ronda contiene ${round.noveltyCount} '
                '${round.noveltyCount == 1 ? 'novedad registrada' : 'novedades registradas'}.',
            registeredAt: round.finishedAt,
            installation: round.installation,
            guardName: round.guardName,
          ),
        );
      }
    }

    notifications.sort(
      (first, second) => second.registeredAt.compareTo(first.registeredAt),
    );

    return notifications;
  }

  String _formatDateTime(DateTime date) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime dateDay = DateTime(date.year, date.month, date.day);
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');

    if (dateDay == today) {
      return 'Hoy · $hour:$minute';
    }

    if (dateDay == today.subtract(const Duration(days: 1))) {
      return 'Ayer · $hour:$minute';
    }

    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year} · $hour:$minute';
  }

  void _markAllAsRead(List<_NoveltyNotification> notifications) {
    setState(() {
      _readNotificationIds.addAll(
        notifications.map((notification) => notification.id),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Todas las novedades fueron marcadas como revisadas.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openNotification(_NoveltyNotification notification) {
    setState(() {
      _readNotificationIds.add(notification.id);
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
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
                    color: const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: naranja,
                    size: 31,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  notification.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: azulOscuro,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  notification.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                _NotificationDetail(
                  icon: Icons.apartment_rounded,
                  value: notification.installation,
                ),
                const SizedBox(height: 9),
                _NotificationDetail(
                  icon: Icons.person_outline_rounded,
                  value: notification.guardName,
                ),
                const SizedBox(height: 9),
                _NotificationDetail(
                  icon: Icons.schedule_rounded,
                  value: _formatDateTime(notification.registeredAt),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(bottomSheetContext),
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
    final RoundHistoryStore historyStore = RoundHistoryStore.instance;

    return AnimatedBuilder(
      animation: historyStore,
      builder: (context, _) {
        final List<_NoveltyNotification> notifications = _buildNotifications(
          historyStore.rounds,
        );
        final int unread = notifications
            .where(
              (notification) => !_readNotificationIds.contains(notification.id),
            )
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
                          'Novedades',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Marcar todas como revisadas',
                        onPressed: unread == 0
                            ? null
                            : () => _markAllAsRead(notifications),
                        icon: Icon(
                          Icons.done_all_rounded,
                          color: unread == 0 ? Colors.white38 : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: notifications.isEmpty
                      ? const _EmptyNotifications()
                      : ListView(
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
                                    color: azulPrincipal.withValues(
                                      alpha: 0.22,
                                    ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Novedades reales',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 19,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          '${notifications.length} '
                                          '${notifications.length == 1 ? 'registro encontrado' : 'registros encontrados'}',
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
                                    'Actividad reciente',
                                    style: TextStyle(
                                      color: azulOscuro,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (unread > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF4E5),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$unread sin revisar',
                                      style: const TextStyle(
                                        color: naranja,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ...notifications.map((notification) {
                              return _NotificationCard(
                                notification: notification,
                                formattedTime: _formatDateTime(
                                  notification.registeredAt,
                                ),
                                read: _readNotificationIds.contains(
                                  notification.id,
                                ),
                                onTap: () => _openNotification(notification),
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

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF0866FF),
                size: 58,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Sin novedades registradas',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF061B44),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Las novedades aparecerán aquí únicamente después de registrarlas en una ronda real.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF667085),
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final _NoveltyNotification notification;
  final String formattedTime;
  final bool read;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.formattedTime,
    required this.read,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: read ? Colors.white : const Color(0xFFFFFBF5),
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
                        color: const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFF59E0B),
                        size: 26,
                      ),
                    ),
                    if (!read)
                      const Positioned(
                        top: -3,
                        right: -3,
                        child: CircleAvatar(
                          radius: 6,
                          backgroundColor: Color(0xFFF04438),
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
                        notification.title,
                        style: TextStyle(
                          color: const Color(0xFF061B44),
                          fontSize: 15,
                          fontWeight: read ? FontWeight.w600 : FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        notification.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${notification.installation} · $formattedTime',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

class _NotificationDetail extends StatelessWidget {
  final IconData icon;
  final String value;

  const _NotificationDetail({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: const Color(0xFF0866FF), size: 18),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _NoveltyNotification {
  final String id;
  final String title;
  final String message;
  final DateTime registeredAt;
  final String installation;
  final String guardName;

  const _NoveltyNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.registeredAt,
    required this.installation,
    required this.guardName,
  });
}
