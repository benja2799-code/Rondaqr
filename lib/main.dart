import 'dart:async';

import 'package:flutter/material.dart';

import 'access_control.dart';
import 'app_routes.dart';
import 'auth_models.dart';
import 'auth_repository.dart';
import 'control_points.dart';
import 'local_storage.dart';
import 'round_history.dart';
import 'round_state.dart';
import 'screens/home_screen.dart';
import 'screens/about_screen.dart';
import 'screens/control_points_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/help_screen.dart';
import 'screens/history_screen.dart';
import 'screens/login_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/users_screen.dart';
import 'services/pin_auth_service.dart';
import 'services/supabase_auth_service.dart';
import 'services/supabase_config_service.dart';
import 'services/supabase_data_coordinator.dart';
import 'services/supabase_service.dart';
import 'session_store.dart';
import 'user_accounts.dart';
import 'user_configuration.dart';
import 'work_shifts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const RondaQRApp());
}

Future<void> initializeRondaQRApplication() async {
  final LocalStorage localStorage = LocalStorage.instance;
  final RoundHistoryStore historyStore = RoundHistoryStore.instance;
  final RoundState roundState = RoundState.instance;
  final UserConfigurationStore configurationStore =
      UserConfigurationStore.instance;
  final ControlPointStore controlPointStore = ControlPointStore.instance;
  final SessionStore sessionStore = SessionStore.instance;
  final UserAccountStore userAccountStore = UserAccountStore.instance;
  final WorkShiftStore workShiftStore = WorkShiftStore.instance;
  final SupabaseService supabaseService = SupabaseService.instance;
  final PinAuthService pinAuthService = PinAuthService.instance;

  final savedRoundsFuture = localStorage.loadHistory();
  final savedActiveRoundFuture = localStorage.loadActiveRound();
  final savedConfigurationFuture = localStorage.loadUserConfiguration();
  final savedUsersFuture = localStorage.loadUsers();
  final savedShiftsFuture = localStorage.loadShiftDefinitions();
  final savedActiveShiftFuture = localStorage.loadActiveShift();
  final savedShiftHistoryFuture = localStorage.loadShiftHistory();
  final savedControlPointsFuture = localStorage.loadControlPoints();
  final savedSessionFuture = localStorage.loadSession();

  await supabaseService.initialize();

  historyStore.onHistoryChanged = localStorage.saveHistory;
  userAccountStore.onAccountsChanged = localStorage.saveUsers;
  workShiftStore.onDefinitionsChanged = localStorage.saveShiftDefinitions;
  workShiftStore.onActiveShiftChanged = localStorage.saveActiveShift;
  workShiftStore.onHistoryChanged = localStorage.saveShiftHistory;
  controlPointStore.onPointsChanged = (points) async {
    if (!supabaseService.onlineMode) {
      await localStorage.saveControlPoints(points);
      return points;
    }

    final AppUser? currentUser = sessionStore.currentUser;
    if (currentUser == null) {
      throw StateError('Debes iniciar sesión para guardar los puntos.');
    }

    final List<ControlPointDefinition> remotePoints =
        await SupabaseConfigService.instance.replaceControlPointsForUser(
          user: currentUser,
          points: points,
        );
    await localStorage.saveControlPoints(remotePoints);
    return remotePoints;
  };
  sessionStore.onSessionCreated = localStorage.saveSession;
  sessionStore.onSessionCleared = () async {
    await localStorage.clearSession();
    pinAuthService.clearUnlock();

    if (supabaseService.onlineMode) {
      await roundState.resetRound();
      await localStorage.saveActiveShift(null);
      workShiftStore.loadActiveShift(null);
      controlPointStore.loadPoints(const []);
      roundState.configureControlPoints(const []);
    }
  };
  configurationStore.onConfigurationChanged = (configuration) async {
    await localStorage.saveUserConfiguration(configuration);

    if (userAccountStore.initialized) {
      await userAccountStore.updateInstallation(
        installationName: configuration.installationNameDisplay,
        company: configuration.companyDisplay,
      );
      await sessionStore.refreshCurrentUser();
    }
  };
  roundState.onActiveRoundChanged = (activeRound) {
    if (activeRound == null) {
      return localStorage.clearActiveRound();
    }

    return localStorage.saveActiveRound(activeRound);
  };

  final List<RoundHistoryItem> savedRounds = await savedRoundsFuture;
  final ActiveRoundSnapshot? savedActiveRound = await savedActiveRoundFuture;
  final UserConfiguration? savedConfiguration = await savedConfigurationFuture;
  final List<LocalUserAccount>? savedUsers = await savedUsersFuture;
  final List<ShiftDefinition>? savedShifts = await savedShiftsFuture;
  final WorkShiftRecord? savedActiveShift = await savedActiveShiftFuture;
  final List<WorkShiftRecord> savedShiftHistory = await savedShiftHistoryFuture;
  final List<ControlPointDefinition>? savedControlPoints =
      await savedControlPointsFuture;
  final AppSession? savedSession = await savedSessionFuture;

  historyStore.loadRounds(savedRounds);
  configurationStore.loadConfiguration(savedConfiguration);
  final bool usersSeeded = userAccountStore.loadAccounts(
    supabaseService.onlineMode ? const [] : savedUsers,
    installationName: configurationStore.configuration.installationNameDisplay,
    company: configurationStore.configuration.companyDisplay,
    seedDefaults: !supabaseService.onlineMode,
  );
  sessionStore.useRepository(
    SupabaseAuthService(
      supabaseService: supabaseService,
      localFallback: LocalAuthRepository(accountStore: userAccountStore),
    ),
  );
  final bool shiftsSeeded = workShiftStore.loadDefinitions(
    supabaseService.onlineMode ? const [] : savedShifts,
    seedDefaults: !supabaseService.onlineMode,
  );
  workShiftStore.loadHistory(savedShiftHistory);
  workShiftStore.loadActiveShift(savedActiveShift);

  if (savedConfiguration == null) {
    await localStorage.saveUserConfiguration(configurationStore.configuration);
  }
  if (usersSeeded) {
    await localStorage.saveUsers(userAccountStore.accounts);
  }
  if (shiftsSeeded) {
    await localStorage.saveShiftDefinitions(workShiftStore.definitions);
  }

  controlPointStore.loadPoints(
    supabaseService.onlineMode ? const [] : savedControlPoints,
  );
  roundState.configureControlPoints(controlPointStore.activePoints);
  roundState.loadActiveRound(savedActiveRound);
  await sessionStore.loadSession(
    savedSession,
    refreshUser: !supabaseService.onlineMode,
  );
  await pinAuthService.prepareForUser(sessionStore.currentUser?.id);

  controlPointStore.addListener(() {
    roundState.configureControlPoints(controlPointStore.activePoints);
  });
  userAccountStore.addListener(() {
    unawaited(
      (() async {
        await sessionStore.refreshCurrentUser();

        final WorkShiftRecord? activeShift = workShiftStore.activeShift;
        if (activeShift == null) {
          return;
        }

        final AppUser? activeUser = userAccountStore
            .accountById(activeShift.userId)
            ?.user;
        if (activeUser != null) {
          await workShiftStore.refreshActiveUser(activeUser);
          await roundState.updateOperationalUser(
            userId: activeUser.id,
            guardName: activeUser.displayName,
            role: activeUser.role.label,
            installation: activeUser.installationName,
          );
        }
      })(),
    );
  });
  workShiftStore.addListener(() {
    final WorkShiftRecord? activeShift = workShiftStore.activeShift;
    final RoundOperationalContext? roundContext = roundState.operationalContext;

    if (activeShift != null &&
        roundContext != null &&
        activeShift.shiftId == roundContext.shiftId) {
      unawaited(
        roundState.updateOperationalShift(
          shiftName: activeShift.shiftName,
          scheduledStart: activeShift.scheduledStart,
          scheduledEnd: activeShift.scheduledEnd,
        ),
      );
    }
  });

  if (supabaseService.onlineMode && sessionStore.isAuthenticated) {
    unawaited(_refreshOnlineDataAfterStartup(sessionStore));
  }
}

Future<void> _refreshOnlineDataAfterStartup(SessionStore sessionStore) async {
  try {
    await sessionStore.refreshCurrentUser();
    await SupabaseDataCoordinator.instance.refreshCurrentUserData(force: true);
  } catch (error) {
    debugPrint(
      'Actualización online posterior al inicio no disponible: $error',
    );
  }
}

class RondaQRApp extends StatefulWidget {
  final Future<void>? initialization;

  const RondaQRApp({super.key, this.initialization});

  @override
  State<RondaQRApp> createState() => _RondaQRAppState();
}

class _RondaQRAppState extends State<RondaQRApp> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = widget.initialization ?? initializeRondaQRApplication();
  }

  void _retryInitialization() {
    setState(() {
      _initialization = initializeRondaQRApplication();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RondaQR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: _AppStartupGate(
        initialization: _initialization,
        onRetry: _retryInitialization,
      ),
      routes: {
        AppRoutes.pinUnlock: (_) => const SessionGuard(child: HomeScreen()),
        AppRoutes.home: (_) => const SessionGuard(child: HomeScreen()),
        AppRoutes.history: (_) => const PermissionGuard(
          permission: AppPermission.viewHistory,
          child: HistoryScreen(),
        ),
        AppRoutes.reports: (_) => const PermissionGuard(
          permission: AppPermission.viewReports,
          child: ReportsScreen(),
        ),
        AppRoutes.profile: (_) => const PermissionGuard(
          permission: AppPermission.viewProfile,
          child: ProfileScreen(),
        ),
        AppRoutes.help: (_) => const PermissionGuard(
          permission: AppPermission.viewProfile,
          child: HelpScreen(),
        ),
        AppRoutes.about: (_) => const PermissionGuard(
          permission: AppPermission.viewProfile,
          child: AboutRondaQrScreen(),
        ),
        AppRoutes.notifications: (_) => const PermissionGuard(
          permission: AppPermission.viewNovelties,
          child: NotificationsScreen(),
        ),
        AppRoutes.controlPoints: (_) => const PermissionGuard(
          permission: AppPermission.manageControlPoints,
          child: ControlPointsScreen(),
        ),
        AppRoutes.editInstallation: (_) => const PermissionGuard(
          permission: AppPermission.manageInstallations,
          child: EditProfileScreen(),
        ),
        AppRoutes.users: (_) => const PermissionGuard(
          permission: AppPermission.manageUsers,
          child: UsersScreen(),
        ),
      },
    );
  }
}

class _AppStartupGate extends StatelessWidget {
  final Future<void> initialization;
  final VoidCallback onRetry;

  const _AppStartupGate({required this.initialization, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AppLoadingScreen();
        }

        if (snapshot.hasError) {
          debugPrint('No fue posible iniciar RondaQR: ${snapshot.error}');
          return _AppStartupErrorScreen(onRetry: onRetry);
        }

        final SessionStore sessionStore = SessionStore.instance;
        final AppUser? user = sessionStore.currentUser;

        if (!sessionStore.isAuthenticated || user == null) {
          return const LoginScreen();
        }

        return const SessionGuard(child: HomeScreen());
      },
    );
  }
}

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Color(0xFF0866FF),
          ),
        ),
      ),
    );
  }
}

class _AppStartupErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const _AppStartupErrorScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 54,
                  color: Color(0xFF0866FF),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No fue posible iniciar la aplicación.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF061B44),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Reintenta para volver a cargar tus datos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF667085)),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
