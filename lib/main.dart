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
import 'screens/control_points_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/history_screen.dart';
import 'screens/login_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/users_screen.dart';
import 'services/supabase_auth_service.dart';
import 'services/supabase_service.dart';
import 'session_store.dart';
import 'user_accounts.dart';
import 'user_configuration.dart';
import 'work_shifts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  await supabaseService.initialize();

  historyStore.onHistoryChanged = localStorage.saveHistory;
  userAccountStore.onAccountsChanged = localStorage.saveUsers;
  workShiftStore.onDefinitionsChanged = localStorage.saveShiftDefinitions;
  workShiftStore.onActiveShiftChanged = localStorage.saveActiveShift;
  workShiftStore.onHistoryChanged = localStorage.saveShiftHistory;
  controlPointStore.onPointsChanged = localStorage.saveControlPoints;
  sessionStore.onSessionCreated = localStorage.saveSession;
  sessionStore.onSessionCleared = localStorage.clearSession;
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

  final List<RoundHistoryItem> savedRounds = await localStorage.loadHistory();
  final ActiveRoundSnapshot? savedActiveRound = await localStorage
      .loadActiveRound();
  final UserConfiguration? savedConfiguration = await localStorage
      .loadUserConfiguration();
  final List<LocalUserAccount>? savedUsers = await localStorage.loadUsers();
  final List<ShiftDefinition>? savedShifts = await localStorage
      .loadShiftDefinitions();
  final WorkShiftRecord? savedActiveShift = await localStorage
      .loadActiveShift();
  final List<WorkShiftRecord> savedShiftHistory = await localStorage
      .loadShiftHistory();
  final List<ControlPointDefinition>? savedControlPoints = await localStorage
      .loadControlPoints();
  final AppSession? savedSession = await localStorage.loadSession();

  historyStore.loadRounds(savedRounds);
  configurationStore.loadConfiguration(savedConfiguration);
  final bool usersSeeded = userAccountStore.loadAccounts(
    savedUsers,
    installationName: configurationStore.configuration.installationNameDisplay,
    company: configurationStore.configuration.companyDisplay,
  );
  sessionStore.useRepository(
    SupabaseAuthService(
      supabaseService: supabaseService,
      localFallback: LocalAuthRepository(accountStore: userAccountStore),
    ),
  );
  final bool shiftsSeeded = workShiftStore.loadDefinitions(savedShifts);
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

  controlPointStore.loadPoints(savedControlPoints);
  roundState.configureControlPoints(controlPointStore.activePoints);
  roundState.loadActiveRound(savedActiveRound);
  await sessionStore.loadSession(savedSession);

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
      initialRoute: SessionStore.instance.isAuthenticated
          ? AppRoutes.home
          : AppRoutes.login,
      routes: {
        AppRoutes.login: (_) => const LoginScreen(),
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
