import 'package:flutter/material.dart';

import '../app_info.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const Color _darkBlue = Color(0xFF061B44);
  static const Color _mediumBlue = Color(0xFF073C85);
  static const Color _primaryBlue = Color(0xFF0866FF);
  static const Color _background = Color(0xFFF4F7FB);

  static const List<_HelpContent> _sections = <_HelpContent>[
    _HelpContent(
      title: 'Primer acceso',
      icon: Icons.login_rounded,
      bullets: <String>[
        'Ingresa con el correo y contraseña asignados por el administrador.',
        'Después del primer inicio puedes crear un PIN de 4 dígitos.',
        'El PIN permite ingresar rápidamente mientras la sesión esté activa.',
        'Usa “Cambiar de usuario” para entrar con otra cuenta.',
      ],
    ),
    _HelpContent(
      title: 'PIN de acceso',
      icon: Icons.pin_rounded,
      bullets: <String>[
        'El PIN es personal y está asociado al usuario actual.',
        'No compartas el PIN.',
        'Después de varios intentos incorrectos se solicitará el ingreso con correo y contraseña.',
        'Si olvidas el PIN, selecciona “Olvidé mi PIN”.',
        'Después de iniciar sesión nuevamente podrás crear otro PIN.',
        'El PIN no reemplaza la contraseña de la cuenta.',
      ],
    ),
    _HelpContent(
      title: 'Turnos',
      icon: Icons.schedule_rounded,
      bullets: <String>[
        'Inicia tu turno antes de realizar una ronda.',
        'Comprueba que el turno asignado sea correcto.',
        'No puedes iniciar una ronda sin un turno activo.',
        'Al terminar la jornada, presiona “Cerrar turno”.',
      ],
    ),
    _HelpContent(
      title: 'Rondas',
      icon: Icons.route_rounded,
      bullets: <String>[
        'Presiona “Iniciar ronda”.',
        'Recorre los puntos de control.',
        'Escanea cada código QR.',
        'Confirma si el punto está sin novedad o con novedad.',
        'Completa todos los puntos activos.',
        'Presiona “Finalizar ronda”.',
      ],
    ),
    _HelpContent(
      title: 'Novedades',
      icon: Icons.report_problem_outlined,
      bullets: <String>[
        'Selecciona “Con novedad”.',
        'Ingresa una descripción clara de la situación.',
        'La novedad quedará asociada al punto, ronda, guardia, fecha y hora.',
        'El administrador podrá verla en historial y reportes.',
      ],
    ),
    _HelpContent(
      title: 'Historial',
      icon: Icons.history_rounded,
      bullets: <String>[
        'Permite revisar las rondas finalizadas.',
        'Los guardias pueden revisar sus propias rondas.',
        'El administrador puede revisar las rondas de la instalación.',
        'Usa Reintentar o actualizar cuando sea necesario.',
      ],
    ),
    _HelpContent(
      title: 'Reportes',
      icon: Icons.bar_chart_rounded,
      bullets: <String>[
        'Permite revisar información semanal y mensual.',
        'Los reportes utilizan las rondas finalizadas guardadas en Supabase.',
        'Revisa el guardia, las fechas, los puntos completados y las novedades.',
      ],
    ),
    _HelpContent(
      title: 'Funciones del administrador',
      icon: Icons.admin_panel_settings_outlined,
      bullets: <String>[
        'Revisar turnos.',
        'Revisar rondas.',
        'Consultar historial y reportes.',
        'Activar o desactivar puntos de control.',
        'Configurar datos de la instalación.',
        'Revisar cuentas y turnos asignados.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _Header(title: 'Ayuda', onBack: () => Navigator.pop(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[_primaryBlue, _mediumBlue],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.support_agent_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Centro de ayuda RondaQR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Selecciona una sección para consultar instrucciones y resolver dudas frecuentes.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final _HelpContent section in _sections) ...<Widget>[
                    _HelpSection(content: section),
                    const SizedBox(height: 10),
                  ],
                  const _FrequentProblemsSection(),
                  const SizedBox(height: 10),
                  const _SupportSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _Header({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[HelpScreen._darkBlue, HelpScreen._mediumBlue],
        ),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          Expanded(
            child: Text(
              title,
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
    );
  }
}

class _HelpContent {
  final String title;
  final IconData icon;
  final List<String> bullets;

  const _HelpContent({
    required this.title,
    required this.icon,
    required this.bullets,
  });
}

class _HelpSection extends StatelessWidget {
  final _HelpContent content;

  const _HelpSection({required this.content});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(content.icon, color: HelpScreen._primaryBlue),
        ),
        title: Text(
          content.title,
          style: const TextStyle(
            color: HelpScreen._darkBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        children: content.bullets
            .map((String bullet) => _Bullet(text: bullet))
            .toList(),
      ),
    );
  }
}

class _FrequentProblemsSection extends StatelessWidget {
  const _FrequentProblemsSection();

  static const List<_Problem> _problems = <_Problem>[
    _Problem(
      title: 'No puedo iniciar una ronda',
      solutions: <String>['Comprueba que exista un turno activo.'],
    ),
    _Problem(
      title: 'El QR no es válido',
      solutions: <String>[
        'Comprueba que el QR pertenezca a la instalación.',
        'Comprueba que el punto esté activo.',
      ],
    ),
    _Problem(
      title: 'No aparece una ronda en el historial',
      solutions: <String>[
        'Comprueba que la ronda haya sido finalizada.',
        'Comprueba la conexión a internet.',
        'Presiona Reintentar.',
      ],
    ),
    _Problem(
      title: 'No puedo entrar con PIN',
      solutions: <String>[
        'Selecciona “Olvidé mi PIN”.',
        'Inicia sesión con correo y contraseña.',
        'Crea un PIN nuevo.',
      ],
    ),
    _Problem(
      title: 'No se cargan los reportes',
      solutions: <String>[
        'Comprueba la conexión.',
        'Comprueba que existan rondas finalizadas.',
        'Presiona Reintentar.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(
          Icons.build_circle_outlined,
          color: HelpScreen._primaryBlue,
          size: 34,
        ),
        title: const Text(
          'Problemas frecuentes',
          style: TextStyle(
            color: HelpScreen._darkBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        children: <Widget>[
          for (int index = 0; index < _problems.length; index++) ...<Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '“${_problems[index].title}”',
                style: const TextStyle(
                  color: HelpScreen._darkBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            for (final String solution in _problems[index].solutions)
              _Bullet(text: solution),
            if (index < _problems.length - 1) const Divider(height: 24),
          ],
        ],
      ),
    );
  }
}

class _Problem {
  final String title;
  final List<String> solutions;

  const _Problem({required this.title, required this.solutions});
}

class _SupportSection extends StatelessWidget {
  const _SupportSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(
          Icons.support_rounded,
          color: HelpScreen._primaryBlue,
          size: 34,
        ),
        title: const Text(
          'Soporte',
          style: TextStyle(
            color: HelpScreen._darkBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        children: <Widget>[
          const _SupportRow(label: 'Soporte', value: 'Soporte RondaQR'),
          const Divider(height: 22),
          const _SupportRow(label: 'Empresa', value: RondaQrAppInfo.company),
          const Divider(height: 22),
          FutureBuilder<String>(
            future: RondaQrAppInfo.version,
            builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
              return _SupportRow(
                label: 'Versión',
                value: snapshot.data ?? 'Cargando…',
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SupportRow extends StatelessWidget {
  final String label;
  final String value;

  const _SupportRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: HelpScreen._darkBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 7, color: HelpScreen._primaryBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF344054), height: 1.42),
            ),
          ),
        ],
      ),
    );
  }
}
