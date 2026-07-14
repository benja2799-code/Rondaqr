import 'package:flutter/foundation.dart';

import '../auth_models.dart';
import '../session_store.dart';
import 'supabase_config_service.dart';
import 'supabase_round_service.dart';
import 'supabase_service.dart';
import 'supabase_shift_service.dart';

class SupabaseDataCoordinator {
  SupabaseDataCoordinator._internal();

  static final SupabaseDataCoordinator instance =
      SupabaseDataCoordinator._internal();

  String _refreshingForUserId = '';
  DateTime? _lastRefreshAt;

  Future<void> refreshCurrentUserData({bool force = false}) async {
    if (!SupabaseService.instance.onlineMode) {
      return;
    }

    final AppUser? user = SessionStore.instance.currentUser;
    if (user == null) {
      return;
    }

    final DateTime now = DateTime.now();
    if (!force &&
        _refreshingForUserId == user.id &&
        _lastRefreshAt != null &&
        now.difference(_lastRefreshAt!) < const Duration(seconds: 20)) {
      return;
    }

    _refreshingForUserId = user.id;
    _lastRefreshAt = now;

    try {
      await SupabaseConfigService.instance.loadForUser(user);
      await SupabaseShiftService.instance.refreshForUser(user);
      await SupabaseRoundService.instance.loadHistory(user);
    } catch (error, stackTrace) {
      debugPrint('No fue posible refrescar datos online: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
