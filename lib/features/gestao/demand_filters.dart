import "package:flutter/material.dart";
import "demanda_model.dart";

enum DemandaFiltroStatus { todas, naoIniciadas, emAndamento, concluidas }

enum DemandaFiltroPrazo {
  todos,
  hoje,
  amanha,
  estaSemana,
  esteMes,
  semPrazo,
  atrasadas,
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Estado dos filtros do painel. Imutavel: cada alteracao gera uma nova
/// instancia via copyWith, igual ao padrao usado no restante do projeto.
class DemandFilterState {
  final DemandaFiltroStatus status;
  final Set<DemandaPrioridade> prioridades;
  final DemandaFiltroPrazo prazo;
  final Set<String> categorias;

  const DemandFilterState({
    this.status = DemandaFiltroStatus.todas,
    this.prioridades = const {},
    this.prazo = DemandaFiltroPrazo.todos,
    this.categorias = const {},
  });

  DemandFilterState copyWith({
    DemandaFiltroStatus? status,
    Set<DemandaPrioridade>? prioridades,
    DemandaFiltroPrazo? prazo,
    Set<String>? categorias,
  }) => DemandFilterState(
    status: status ?? this.status,
    prioridades: prioridades ?? this.prioridades,
    prazo: prazo ?? this.prazo,
    categorias: categorias ?? this.categorias,
  );

  int get activeCount {
    var count = 0;
    if (status != DemandaFiltroStatus.todas) count++;
    if (prioridades.isNotEmpty) count++;
    if (prazo != DemandaFiltroPrazo.todos) count++;
    if (categorias.isNotEmpty) count++;
    return count;
  }

  bool matches(Demanda d) {
    switch (status) {
      case DemandaFiltroStatus.todas:
        break;
      case DemandaFiltroStatus.naoIniciadas:
        if (d.status != DemandaStatus.naoIniciada) return false;
        break;
      case DemandaFiltroStatus.emAndamento:
        if (d.status != DemandaStatus.emAndamento) return false;
        break;
      case DemandaFiltroStatus.concluidas:
        if (d.status != DemandaStatus.concluida) return false;
        break;
    }

    if (prioridades.isNotEmpty && !prioridades.contains(d.prioridade))
      return false;
    if (categorias.isNotEmpty && !categorias.contains(d.categoria))
      return false;

    if (prazo != DemandaFiltroPrazo.todos) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final prazoData = d.prazo;

      switch (prazo) {
        case DemandaFiltroPrazo.todos:
          break;
        case DemandaFiltroPrazo.semPrazo:
          if (prazoData != null) return false;
          break;
        case DemandaFiltroPrazo.hoje:
          if (prazoData == null || !_isSameDay(prazoData, today)) return false;
          break;
        case DemandaFiltroPrazo.amanha:
          if (prazoData == null ||
              !_isSameDay(prazoData, today.add(const Duration(days: 1))))
            return false;
          break;
        case DemandaFiltroPrazo.estaSemana:
          if (prazoData == null) return false;
          final weekStart = today.subtract(Duration(days: today.weekday % 7));
          final weekEnd = weekStart.add(const Duration(days: 6));
          if (prazoData.isBefore(weekStart) || prazoData.isAfter(weekEnd))
            return false;
          break;
        case DemandaFiltroPrazo.esteMes:
          if (prazoData == null ||
              prazoData.year != today.year ||
              prazoData.month != today.month)
            return false;
          break;
        case DemandaFiltroPrazo.atrasadas:
          if (prazoData == null) return false;
          if (!prazoData.isBefore(today) || d.status == DemandaStatus.concluida)
            return false;
          break;
      }
    }

    return true;
  }
}

/// Painel lateral (drawer) de filtros. Nao e um modal: fica encostado na
/// borda direita e desliza sobre o conteudo.
class DemandFilters extends StatelessWidget {
  final DemandFilterState filters;
  final ValueChanged<DemandFilterState> onChanged;
  final VoidCallback onClose;
  final List<String> categorias;

  const DemandFilters({
    super.key,
    required this.filters,
    required this.onChanged,
    required this.onClose,
    required this.categorias,
  });

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    ),
  );

  Widget _choice(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFF7A0BD4),
      backgroundColor: Colors.white.withOpacity(0.05),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white70,
        fontSize: 12,
      ),
      side: BorderSide(
        color: selected ? const Color(0xFF7A0BD4) : Colors.white12,
      ),
      onSelected: (_) => onTap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A1A),
      elevation: 8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Filtros",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: onClose,
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle("Status"),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _choice(
                            "Todas",
                            filters.status == DemandaFiltroStatus.todas,
                            () => onChanged(
                              filters.copyWith(
                                status: DemandaFiltroStatus.todas,
                              ),
                            ),
                          ),
                          _choice(
                            "Nao iniciadas",
                            filters.status == DemandaFiltroStatus.naoIniciadas,
                            () => onChanged(
                              filters.copyWith(
                                status: DemandaFiltroStatus.naoIniciadas,
                              ),
                            ),
                          ),
                          _choice(
                            "Em andamento",
                            filters.status == DemandaFiltroStatus.emAndamento,
                            () => onChanged(
                              filters.copyWith(
                                status: DemandaFiltroStatus.emAndamento,
                              ),
                            ),
                          ),
                          _choice(
                            "Concluidas",
                            filters.status == DemandaFiltroStatus.concluidas,
                            () => onChanged(
                              filters.copyWith(
                                status: DemandaFiltroStatus.concluidas,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _sectionTitle("Prioridade"),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: DemandaPrioridade.values.map((p) {
                          final selected = filters.prioridades.contains(p);
                          return _choice(p.label, selected, () {
                            final next = {...filters.prioridades};
                            if (selected) {
                              next.remove(p);
                            } else {
                              next.add(p);
                            }
                            onChanged(filters.copyWith(prioridades: next));
                          });
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      _sectionTitle("Prazo"),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _choice(
                            "Todos",
                            filters.prazo == DemandaFiltroPrazo.todos,
                            () => onChanged(
                              filters.copyWith(prazo: DemandaFiltroPrazo.todos),
                            ),
                          ),
                          _choice(
                            "Hoje",
                            filters.prazo == DemandaFiltroPrazo.hoje,
                            () => onChanged(
                              filters.copyWith(prazo: DemandaFiltroPrazo.hoje),
                            ),
                          ),
                          _choice(
                            "Amanha",
                            filters.prazo == DemandaFiltroPrazo.amanha,
                            () => onChanged(
                              filters.copyWith(
                                prazo: DemandaFiltroPrazo.amanha,
                              ),
                            ),
                          ),
                          _choice(
                            "Esta semana",
                            filters.prazo == DemandaFiltroPrazo.estaSemana,
                            () => onChanged(
                              filters.copyWith(
                                prazo: DemandaFiltroPrazo.estaSemana,
                              ),
                            ),
                          ),
                          _choice(
                            "Este mes",
                            filters.prazo == DemandaFiltroPrazo.esteMes,
                            () => onChanged(
                              filters.copyWith(
                                prazo: DemandaFiltroPrazo.esteMes,
                              ),
                            ),
                          ),
                          _choice(
                            "Sem prazo",
                            filters.prazo == DemandaFiltroPrazo.semPrazo,
                            () => onChanged(
                              filters.copyWith(
                                prazo: DemandaFiltroPrazo.semPrazo,
                              ),
                            ),
                          ),
                          _choice(
                            "Atrasadas",
                            filters.prazo == DemandaFiltroPrazo.atrasadas,
                            () => onChanged(
                              filters.copyWith(
                                prazo: DemandaFiltroPrazo.atrasadas,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _sectionTitle("Categoria"),
                      categorias.isEmpty
                          ? const Text(
                              "Nenhuma categoria cadastrada ainda.",
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: categorias.map((c) {
                                final selected = filters.categorias.contains(c);
                                return _choice(c, selected, () {
                                  final next = {...filters.categorias};
                                  if (selected) {
                                    next.remove(c);
                                  } else {
                                    next.add(c);
                                  }
                                  onChanged(filters.copyWith(categorias: next));
                                });
                              }).toList(),
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onChanged(const DemandFilterState()),
                      child: const Text("Limpar filtros"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7A0BD4),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onClose,
                      child: const Text("Aplicar"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
