import "package:flutter/material.dart";
import "atividade_agenda_item.dart";
import "demanda_detail_drawer.dart";
import "demanda_form_dialog.dart";
import "demanda_model.dart";
import "demanda_repository.dart";
import "demand_calendar.dart";
import "demand_day_view.dart";
import "demand_filters.dart";
import "demand_list_view.dart";
import "demand_week_view.dart";
import "month_navigator.dart";
import "planejamento_page.dart";
import "view_selector.dart";

class _DemandasData {
  final List<Demanda> demandas;
  final List<AtividadeAgendaItem> atividades;
  final List<Map<String, dynamic>> managers;
  const _DemandasData({
    required this.demandas,
    required this.atividades,
    required this.managers,
  });
}

/// Central de demandas: tarefas que qualquer gestor pode enviar para
/// qualquer outro gestor da agencia. Painel de organizacao (nao e uma tela
/// de metricas/dashboard). A mesma pagina troca apenas a forma de
/// visualizacao (Dia/Semana/Mes/Lista).
class DemandasPage extends StatefulWidget {
  const DemandasPage({super.key});

  @override
  State<DemandasPage> createState() => _DemandasPageState();
}

class _DemandasPageState extends State<DemandasPage> {
  static const _meses = [
    "Janeiro",
    "Fevereiro",
    "Marco",
    "Abril",
    "Maio",
    "Junho",
    "Julho",
    "Agosto",
    "Setembro",
    "Outubro",
    "Novembro",
    "Dezembro",
  ];
  static const _weekDaysFull = [
    "Domingo",
    "Segunda",
    "Terca",
    "Quarta",
    "Quinta",
    "Sexta",
    "Sabado",
  ];

  final _repository = DemandaRepository();
  late Future<_DemandasData> _future;
  DemandasViewMode _viewMode = DemandasViewMode.lista;
  DateTime _focusedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime _focusedDay = DateTime.now();
  DemandFilterState _filters = const DemandFilterState();
  DemandaOrdenacao _ordenacao = DemandaOrdenacao.prazo;
  bool _filtersOpen = false;
  Demanda? _selectedDemanda;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DemandasData> _load() async {
    final results = await Future.wait([
      _repository.loadMinhasDemandas(),
      _repository.loadAtividadesDaAgencia(),
      _repository.loadManagersDaAgencia(),
    ]);
    return _DemandasData(
      demandas: results[0] as List<Demanda>,
      atividades: results[1] as List<AtividadeAgendaItem>,
      managers: results[2] as List<Map<String, dynamic>>,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _onTapAtividade(AtividadeAgendaItem a) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlanejamentoPage(
          demandaId: a.demandaId,
          demandaTitulo: a.demandaTitulo,
        ),
      ),
    );
    _reload();
  }

  DateTime _weekStartFor(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday % 7));

  String _headerLabel() {
    switch (_viewMode) {
      case DemandasViewMode.mes:
        return _meses[_focusedMonth.month - 1] +
            " de " +
            _focusedMonth.year.toString();
      case DemandasViewMode.semana:
        final start = _weekStartFor(_focusedDay);
        final end = start.add(const Duration(days: 6));
        final sameMonth = start.month == end.month;
        final startLabel =
            start.day.toString() +
            (sameMonth ? "" : " de " + _meses[start.month - 1]);
        return startLabel +
            " - " +
            end.day.toString() +
            " de " +
            _meses[end.month - 1] +
            " de " +
            end.year.toString();
      case DemandasViewMode.dia:
        return _weekDaysFull[_focusedDay.weekday % 7] +
            ", " +
            _focusedDay.day.toString() +
            " de " +
            _meses[_focusedDay.month - 1] +
            " de " +
            _focusedDay.year.toString();
      case DemandasViewMode.lista:
        return "";
    }
  }

  void _goPrevious() {
    setState(() {
      switch (_viewMode) {
        case DemandasViewMode.mes:
          _focusedMonth = DateTime(
            _focusedMonth.year,
            _focusedMonth.month - 1,
            1,
          );
          break;
        case DemandasViewMode.semana:
          _focusedDay = _focusedDay.subtract(const Duration(days: 7));
          break;
        case DemandasViewMode.dia:
          _focusedDay = _focusedDay.subtract(const Duration(days: 1));
          break;
        case DemandasViewMode.lista:
          break;
      }
    });
  }

  void _goNext() {
    setState(() {
      switch (_viewMode) {
        case DemandasViewMode.mes:
          _focusedMonth = DateTime(
            _focusedMonth.year,
            _focusedMonth.month + 1,
            1,
          );
          break;
        case DemandasViewMode.semana:
          _focusedDay = _focusedDay.add(const Duration(days: 7));
          break;
        case DemandasViewMode.dia:
          _focusedDay = _focusedDay.add(const Duration(days: 1));
          break;
        case DemandasViewMode.lista:
          break;
      }
    });
  }

  void _toggleFilters() => setState(() {
    _filtersOpen = !_filtersOpen;
    if (_filtersOpen) _selectedDemanda = null;
  });

  void _onTapDemand(Demanda d) => setState(() {
    _selectedDemanda = d;
    _filtersOpen = false;
  });

  void _closeDetail() => setState(() => _selectedDemanda = null);

  void _onTapDay(DateTime day) => setState(() {
    _focusedDay = day;
    _viewMode = DemandasViewMode.dia;
  });

  Future<void> _onStatusChanged(Demanda d, DemandaStatus status) async {
    await _repository.atualizarStatus(d.id, status);
    setState(() => _selectedDemanda = d.copyWith(status: status));
    _reload();
  }

  Future<void> _onToggleConcluida(Demanda d, bool value) async {
    await _repository.atualizarStatus(
      d.id,
      value ? DemandaStatus.concluida : DemandaStatus.naoIniciada,
    );
    _reload();
  }

  Future<void> _novaDemanda() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => const DemandaFormDialog(),
    );
    if (created == true) _reload();
  }

  Future<void> _onDemandaEdited() async {
    final data = await _load();
    if (!mounted) return;
    final editedId = _selectedDemanda?.id;
    setState(() {
      _future = Future.value(data);
      _selectedDemanda = editedId == null
          ? null
          : data.demandas.where((d) => d.id == editedId).firstOrNull;
    });
  }

  Widget _buildBody(List<Demanda> filtered, List<AtividadeAgendaItem> atividades) {
    switch (_viewMode) {
      case DemandasViewMode.mes:
        return DemandCalendar(
          month: _focusedMonth,
          demandas: filtered,
          atividades: atividades,
          onTapDemand: _onTapDemand,
          onTapAtividade: _onTapAtividade,
          onTapDay: _onTapDay,
        );
      case DemandasViewMode.semana:
        return DemandWeekView(
          weekStart: _weekStartFor(_focusedDay),
          demandas: filtered,
          atividades: atividades,
          onTapDemand: _onTapDemand,
          onTapAtividade: _onTapAtividade,
          onTapDay: _onTapDay,
        );
      case DemandasViewMode.dia:
        return DemandDayView(
          day: _focusedDay,
          demandas: filtered,
          atividades: atividades,
          onTapDemand: _onTapDemand,
          onTapAtividade: _onTapAtividade,
        );
      case DemandasViewMode.lista:
        return DemandListView(
          demandas: filtered,
          ordenacao: _ordenacao,
          onOrdenacaoChanged: (o) => setState(() => _ordenacao = o),
          onTapDemand: _onTapDemand,
          onToggleConcluida: _onToggleConcluida,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DemandasData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                "Erro ao carregar demandas: " + snapshot.error.toString(),
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final all = snapshot.data!.demandas;
        final atividades = snapshot.data!.atividades;
        final managers = snapshot.data!.managers;
        final filtered = all.where(_filters.matches).toList();
        final categorias = {for (final d in all) d.categoria}.toList()..sort();

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Demandas",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Tarefas e solicitacoes entre gestores.",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white70,
                            ),
                            onPressed: _reload,
                          ),
                          OutlinedButton.icon(
                            key: const Key("demandas_filtros_button"),
                            onPressed: _toggleFilters,
                            icon: const Icon(
                              Icons.filter_list,
                              size: 18,
                              color: Colors.white70,
                            ),
                            label: Text(
                              _filters.activeCount > 0
                                  ? "Filtros (" +
                                        _filters.activeCount.toString() +
                                        ")"
                                  : "Filtros",
                              style: const TextStyle(color: Colors.white70),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _novaDemanda,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text("Nova Demanda"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7A0BD4),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_viewMode != DemandasViewMode.lista) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: MonthNavigator(
                        label: _headerLabel(),
                        onPrevious: _goPrevious,
                        onNext: _goNext,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ViewSelector(
                    selected: _viewMode,
                    onChanged: (m) => setState(() => _viewMode = m),
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildBody(filtered, atividades)),
                ],
              ),
            ),
            if (_filtersOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _toggleFilters,
                  child: Container(color: Colors.black.withOpacity(0.45)),
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              top: 0,
              bottom: 0,
              right: _filtersOpen ? 0 : -380,
              width: 360,
              child: DemandFilters(
                filters: _filters,
                onChanged: (f) => setState(() => _filters = f),
                onClose: _toggleFilters,
                categorias: categorias,
                managers: managers,
              ),
            ),
            if (_selectedDemanda != null)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeDetail,
                  child: Container(color: Colors.black.withOpacity(0.45)),
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              top: 0,
              bottom: 0,
              right: _selectedDemanda != null ? 0 : -420,
              width: 400,
              child: _selectedDemanda == null
                  ? const SizedBox.shrink()
                  : DemandaDetailDrawer(
                      demanda: _selectedDemanda!,
                      onClose: _closeDetail,
                      onStatusChanged: (status) =>
                          _onStatusChanged(_selectedDemanda!, status),
                      onEdited: _onDemandaEdited,
                      onDeleted: () {
                        setState(() => _selectedDemanda = null);
                        _reload();
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
