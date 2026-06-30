import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'control_points.dart';
import 'local_storage.dart';
import 'round_history.dart';
import 'round_state.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'user_configuration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final LocalStorage localStorage = LocalStorage.instance;
  final RoundHistoryStore historyStore = RoundHistoryStore.instance;
  final RoundState roundState = RoundState.instance;
  final UserConfigurationStore configurationStore =
      UserConfigurationStore.instance;
  final ControlPointStore controlPointStore = ControlPointStore.instance;

  historyStore.onHistoryChanged = localStorage.saveHistory;
  configurationStore.onConfigurationChanged =
      localStorage.saveUserConfiguration;
  controlPointStore.onPointsChanged = localStorage.saveControlPoints;
  roundState.onActiveRoundChanged = (activeRound) {
    if (activeRound == null) {
      return localStorage.clearActiveRound();
    }

    return localStorage.saveActiveRound(activeRound);
  };

  final List<RoundHistoryItem> savedRounds = await localStorage.loadHistory();
  final ActiveRoundSnapshot? savedActiveRound = await localStorage
      .loadActiveRound();
  final UserConfiguration? savedConfiguration = await localStorage
      .loadUserConfiguration();
  final List<ControlPointDefinition>? savedControlPoints = await localStorage
      .loadControlPoints();

  historyStore.loadRounds(savedRounds);
  configurationStore.loadConfiguration(savedConfiguration);
  controlPointStore.loadPoints(savedControlPoints);
  roundState.configureControlPoints(controlPointStore.activePoints);
  roundState.loadActiveRound(savedActiveRound);

  controlPointStore.addListener(() {
    roundState.configureControlPoints(controlPointStore.activePoints);
  });

  runApp(const RondaQRApp());
}

class RondaQRApp extends StatelessWidget {
  const RondaQRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RondaQR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: AppRoutes.login,
      routes: {
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.home: (_) => const HomeScreen(),
      },
    );
  }
}
