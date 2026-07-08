import 'package:rondaqr/round_history.dart';

enum RoundNoveltyFilter { all, withNovelty, withoutNovelty }

class RoundHistoryFilters {
  String searchText;
  DateTime? dateFrom;
  DateTime? dateTo;
  RoundNoveltyFilter noveltyFilter;
  bool completedOnly;
  String? installation;
  String? guardName;

  RoundHistoryFilters({
    this.searchText = '',
    this.dateFrom,
    this.dateTo,
    this.noveltyFilter = RoundNoveltyFilter.all,
    this.completedOnly = false,
    this.installation,
    this.guardName,
  });

  bool get isActive {
    return searchText.trim().isNotEmpty ||
        dateFrom != null ||
        dateTo != null ||
        noveltyFilter != RoundNoveltyFilter.all ||
        completedOnly ||
        installation != null ||
        guardName != null;
  }

  int get activeCount {
    int count = 0;

    if (searchText.trim().isNotEmpty) {
      count++;
    }
    if (dateFrom != null || dateTo != null) {
      count++;
    }
    if (noveltyFilter != RoundNoveltyFilter.all) {
      count++;
    }
    if (completedOnly) {
      count++;
    }
    if (installation != null) {
      count++;
    }
    if (guardName != null) {
      count++;
    }

    return count;
  }

  RoundHistoryFilters copy() {
    return RoundHistoryFilters(
      searchText: searchText,
      dateFrom: dateFrom,
      dateTo: dateTo,
      noveltyFilter: noveltyFilter,
      completedOnly: completedOnly,
      installation: installation,
      guardName: guardName,
    );
  }

  void clear() {
    searchText = '';
    dateFrom = null;
    dateTo = null;
    noveltyFilter = RoundNoveltyFilter.all;
    completedOnly = false;
    installation = null;
    guardName = null;
  }

  List<RoundHistoryItem> apply(Iterable<RoundHistoryItem> rounds) {
    final String query = _normalize(searchText.trim());
    final DateTime? firstDate = dateFrom == null
        ? null
        : DateTime(dateFrom!.year, dateFrom!.month, dateFrom!.day);
    final DateTime? lastDateExclusive = dateTo == null
        ? null
        : DateTime(
            dateTo!.year,
            dateTo!.month,
            dateTo!.day,
          ).add(const Duration(days: 1));

    return rounds
        .where((round) {
          if (query.isNotEmpty) {
            final bool matchesGuard = _normalize(
              round.guardName,
            ).contains(query);
            final bool matchesInstallation = _normalize(
              round.installation,
            ).contains(query);
            final bool matchesPoint = round.points.any(
              (point) => _normalize(point.name).contains(query),
            );

            if (!matchesGuard && !matchesInstallation && !matchesPoint) {
              return false;
            }
          }

          if (firstDate != null && round.finishedAt.isBefore(firstDate)) {
            return false;
          }

          if (lastDateExclusive != null &&
              !round.finishedAt.isBefore(lastDateExclusive)) {
            return false;
          }

          if (noveltyFilter == RoundNoveltyFilter.withNovelty &&
              !round.hasNovelty) {
            return false;
          }

          if (noveltyFilter == RoundNoveltyFilter.withoutNovelty &&
              round.hasNovelty) {
            return false;
          }

          if (completedOnly && !round.completed) {
            return false;
          }

          if (installation != null && round.installation != installation) {
            return false;
          }

          if (guardName != null && round.guardName != guardName) {
            return false;
          }

          return true;
        })
        .toList(growable: false);
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }
}
