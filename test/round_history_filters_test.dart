import 'package:flutter_test/flutter_test.dart';
import 'package:rondaqr/round_history.dart';
import 'package:rondaqr/round_history_filters.dart';

void main() {
  final List<RoundHistoryItem> rounds = [
    RoundHistoryItem(
      id: 'round_1',
      guardName: 'Gabriel Guardia',
      installation: 'Instalación de prueba',
      startedAt: DateTime(2026, 7, 5, 8),
      finishedAt: DateTime(2026, 7, 5, 8, 20),
      totalPoints: 2,
      completedPoints: 2,
      noveltyCount: 1,
      points: [
        RoundHistoryPoint(
          name: 'Portón trasero',
          completed: true,
          hasNovelty: true,
          observation: 'Cerradura dañada',
          completedAt: DateTime(2026, 7, 5, 8, 10),
        ),
      ],
    ),
    RoundHistoryItem(
      id: 'round_2',
      guardName: 'Andrea Administradora',
      installation: 'Edificio Central',
      startedAt: DateTime(2026, 7, 6, 9),
      finishedAt: DateTime(2026, 7, 6, 9, 15),
      totalPoints: 1,
      completedPoints: 1,
      noveltyCount: 0,
      points: [
        RoundHistoryPoint(
          name: 'Acceso principal',
          completed: true,
          hasNovelty: false,
          observation: '',
          completedAt: DateTime(2026, 7, 6, 9, 10),
        ),
      ],
    ),
  ];

  test('Busca por punto sin distinguir mayúsculas ni acentos', () {
    final RoundHistoryFilters filters = RoundHistoryFilters(
      searchText: 'porton',
    );

    expect(filters.apply(rounds).map((round) => round.id), ['round_1']);
  });

  test('Filtra correctamente solo rondas con novedades', () {
    final RoundHistoryFilters filters = RoundHistoryFilters(
      noveltyFilter: RoundNoveltyFilter.withNovelty,
    );

    expect(filters.apply(rounds).map((round) => round.id), ['round_1']);
  });

  test('El rango de fechas incluye el día hasta completo', () {
    final RoundHistoryFilters filters = RoundHistoryFilters(
      dateFrom: DateTime(2026, 7, 6),
      dateTo: DateTime(2026, 7, 6),
    );

    expect(filters.apply(rounds).map((round) => round.id), ['round_2']);
  });
}
