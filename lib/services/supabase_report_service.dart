import '../auth_models.dart';
import '../round_history.dart';
import 'supabase_round_service.dart';

class SupabaseReportService {
  const SupabaseReportService();

  Future<List<RoundHistoryItem>> loadReportRounds(AppUser user) {
    return SupabaseRoundService.instance.loadHistory(user);
  }
}
