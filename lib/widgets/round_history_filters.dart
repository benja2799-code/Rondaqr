import 'package:flutter/material.dart';
import 'package:rondaqr/round_history.dart';
import 'package:rondaqr/round_history_filters.dart';

const Color _darkBlue = Color(0xFF061B44);
const Color _mediumBlue = Color(0xFF073C85);
const Color _primaryBlue = Color(0xFF0866FF);
const Color _background = Color(0xFFF4F7FB);
const Color _textGray = Color(0xFF667085);

class RoundHistoryFilterPanel extends StatelessWidget {
  final TextEditingController searchController;
  final int resultCount;
  final int activeFilterCount;
  final bool hasActiveFilters;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onOpenFilters;
  final VoidCallback onClearFilters;

  const RoundHistoryFilterPanel({
    super.key,
    required this.searchController,
    required this.resultCount,
    required this.activeFilterCount,
    required this.hasActiveFilters,
    required this.onSearchChanged,
    required this.onOpenFilters,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar guardia, instalación o punto',
              prefixIcon: const Icon(Icons.search_rounded, color: _primaryBlue),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: _background,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$resultCount ${resultCount == 1 ? 'resultado encontrado' : 'resultados encontrados'}',
                  style: const TextStyle(
                    color: _textGray,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (hasActiveFilters)
                TextButton(
                  onPressed: onClearFilters,
                  child: const Text('Limpiar'),
                ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: onOpenFilters,
                style: FilledButton.styleFrom(
                  backgroundColor: _mediumBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                ),
                icon: const Icon(Icons.tune_rounded, size: 19),
                label: Text(
                  activeFilterCount == 0
                      ? 'Filtros'
                      : 'Filtros ($activeFilterCount)',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NoRoundFilterResults extends StatelessWidget {
  final VoidCallback onClearFilters;

  const NoRoundFilterResults({super.key, required this.onClearFilters});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.manage_search_rounded,
            color: _primaryBlue,
            size: 54,
          ),
          const SizedBox(height: 14),
          const Text(
            'No se encontraron coincidencias',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _darkBlue,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Prueba otra búsqueda o limpia los filtros seleccionados.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textGray, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onClearFilters,
            icon: const Icon(Icons.filter_alt_off_rounded),
            label: const Text('Limpiar todos los filtros'),
          ),
        ],
      ),
    );
  }
}

Future<RoundHistoryFilters?> showRoundHistoryFilters({
  required BuildContext context,
  required RoundHistoryFilters currentFilters,
  required List<RoundHistoryItem> rounds,
}) {
  return showModalBottomSheet<RoundHistoryFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return _RoundHistoryFiltersSheet(
        initialFilters: currentFilters.copy(),
        rounds: rounds,
      );
    },
  );
}

class _RoundHistoryFiltersSheet extends StatefulWidget {
  final RoundHistoryFilters initialFilters;
  final List<RoundHistoryItem> rounds;

  const _RoundHistoryFiltersSheet({
    required this.initialFilters,
    required this.rounds,
  });

  @override
  State<_RoundHistoryFiltersSheet> createState() =>
      _RoundHistoryFiltersSheetState();
}

class _RoundHistoryFiltersSheetState extends State<_RoundHistoryFiltersSheet> {
  late RoundHistoryFilters filters;
  late List<String> installations;
  late List<String> guards;

  @override
  void initState() {
    super.initState();
    filters = widget.initialFilters;
    installations =
        widget.rounds
            .map((round) => round.installation.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort(_compareText);
    guards =
        widget.rounds
            .map((round) => round.guardName.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort(_compareText);
  }

  int _compareText(String first, String second) {
    return first.toLowerCase().compareTo(second.toLowerCase());
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Seleccionar';
    }

    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  Future<void> _selectDate({required bool isStart}) async {
    final DateTime now = DateTime.now();
    final DateTime initialDate =
        (isStart ? filters.dateFrom : filters.dateTo) ?? now;
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10, 12, 31),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      if (isStart) {
        filters.dateFrom = selected;

        if (filters.dateTo != null && filters.dateTo!.isBefore(selected)) {
          filters.dateTo = null;
        }
      } else {
        filters.dateTo = selected;

        if (filters.dateFrom != null && filters.dateFrom!.isAfter(selected)) {
          filters.dateFrom = null;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.86,
        minChildSize: 0.58,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0D5DD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    children: [
                      const Text(
                        'Filtrar rondas',
                        style: TextStyle(
                          color: _darkBlue,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Combina uno o varios criterios.',
                        style: TextStyle(color: _textGray, fontSize: 13),
                      ),
                      const SizedBox(height: 22),
                      const _FilterLabel('Fecha de finalización'),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Expanded(
                            child: _DateFilterButton(
                              label: 'Desde',
                              value: _formatDate(filters.dateFrom),
                              selected: filters.dateFrom != null,
                              onPressed: () => _selectDate(isStart: true),
                              onClear: filters.dateFrom == null
                                  ? null
                                  : () {
                                      setState(() {
                                        filters.dateFrom = null;
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DateFilterButton(
                              label: 'Hasta',
                              value: _formatDate(filters.dateTo),
                              selected: filters.dateTo != null,
                              onPressed: () => _selectDate(isStart: false),
                              onClear: filters.dateTo == null
                                  ? null
                                  : () {
                                      setState(() {
                                        filters.dateTo = null;
                                      });
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const _FilterLabel('Novedades'),
                      const SizedBox(height: 9),
                      SegmentedButton<RoundNoveltyFilter>(
                        segments: const [
                          ButtonSegment(
                            value: RoundNoveltyFilter.all,
                            label: Text('Todas'),
                          ),
                          ButtonSegment(
                            value: RoundNoveltyFilter.withNovelty,
                            label: Text('Con'),
                          ),
                          ButtonSegment(
                            value: RoundNoveltyFilter.withoutNovelty,
                            label: Text('Sin'),
                          ),
                        ],
                        selected: {filters.noveltyFilter},
                        onSelectionChanged: (selection) {
                          setState(() {
                            filters.noveltyFilter = selection.first;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile.adaptive(
                        value: filters.completedOnly,
                        onChanged: (value) {
                          setState(() {
                            filters.completedOnly = value;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                        activeTrackColor: _primaryBlue,
                        title: const Text(
                          'Solo rondas completadas',
                          style: TextStyle(
                            color: _darkBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const _FilterLabel('Instalación'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'installation-${filters.installation ?? ''}',
                        ),
                        initialValue: filters.installation ?? '',
                        decoration: _dropdownDecoration(
                          Icons.apartment_rounded,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Todas las instalaciones'),
                          ),
                          ...installations.map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            filters.installation =
                                value == null || value.isEmpty ? null : value;
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      const _FilterLabel('Guardia'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: ValueKey('guard-${filters.guardName ?? ''}'),
                        initialValue: filters.guardName ?? '',
                        decoration: _dropdownDecoration(
                          Icons.person_outline_rounded,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Todos los guardias'),
                          ),
                          ...guards.map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            filters.guardName = value == null || value.isEmpty
                                ? null
                                : value;
                          });
                        },
                      ),
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(filters.clear);
                              },
                              icon: const Icon(Icons.filter_alt_off_rounded),
                              label: const Text('Limpiar todos'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.pop(context, filters);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: _primaryBlue,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Aplicar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  InputDecoration _dropdownDecoration(IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: _primaryBlue),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  final String text;

  const _FilterLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _darkBlue,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _DateFilterButton extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback? onClear;

  const _DateFilterButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.onPressed,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 11, 7, 11),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                color: _primaryBlue,
                size: 21,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(color: _textGray, fontSize: 10),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        color: selected ? _darkBlue : _textGray,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  tooltip: 'Quitar fecha',
                  visualDensity: VisualDensity.compact,
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
