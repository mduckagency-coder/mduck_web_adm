import "package:flutter/material.dart";
import "demanda_model.dart";
import "demanda_repository.dart";

Color _prioridadeColor(DemandaPrioridade p) {
  switch (p) {
    case DemandaPrioridade.alta:
      return const Color(0xFFE5484D);
    case DemandaPrioridade.media:
      return const Color(0xFFF5A623);
    case DemandaPrioridade.baixa:
      return const Color(0xFF3DD68C);
  }
}

class _PlanejamentoData {
  final Map<String, dynamic> planejamento;
  final List<Map<String, dynamic>> atividades;
  _PlanejamentoData({required this.planejamento, required this.atividades});
}

/// Tela do planejamento vinculado a uma demanda. Mostra a demanda original
/// no topo, o cronograma de atividades e um calendario com apenas as
/// atividades que tem data (a demanda original nunca aparece no calendario).
class PlanejamentoPage extends StatefulWidget {
  final String demandaId;
  final String demandaTitulo;

  const PlanejamentoPage({
    super.key,
    required this.demandaId,
    required this.demandaTitulo,
  });

  @override
  State<PlanejamentoPage> createState() => _PlanejamentoPageState();
}

class _PlanejamentoPageState extends State<PlanejamentoPage> {
  final _repository = DemandaRepository();
  late Future<_PlanejamentoData> _future;
  DateTime _calendarMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PlanejamentoData> _load() async {
    final planejamento = await _repository.loadPlanejamento(widget.demandaId);
    if (planejamento == null)
      throw Exception("Planejamento nao encontrado para esta demanda.");
    final atividades = await _repository.loadAtividades(
      planejamento["id"] as String,
    );
    return _PlanejamentoData(
      planejamento: planejamento,
      atividades: atividades,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _novaAtividade(String planejamentoId) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _NovaAtividadeDialog(
        planejamentoId: planejamentoId,
        repository: _repository,
      ),
    );
    if (saved == true) _reload();
  }

  Future<void> _toggleAtividade(Map<String, dynamic> atividade) async {
    final novo = !(atividade["concluida"] as bool);
    await _repository.alternarConcluida(atividade["id"] as String, novo);
    _reload();
  }

  void _abrirObservacoes(Map<String, dynamic> atividade) {
    showDialog(
      context: context,
      builder: (context) => _AtividadeObservacoesDialog(
        atividade: atividade,
        repository: _repository,
      ),
    );
  }

  DateTime? _parseData(Map<String, dynamic> atividade) {
    final data = atividade["data"] as String?;
    if (data == null) return null;
    return DateTime.parse(data);
  }

  String _formatData(DateTime d) =>
      d.day.toString().padLeft(2, "0") +
      "/" +
      d.month.toString().padLeft(2, "0");

  String? _formatHora(Map<String, dynamic> atividade) {
    final hora = atividade["hora"] as String?;
    if (hora == null) return null;
    final parts = hora.split(":");
    return parts[0] + ":" + parts[1];
  }

  Widget _cronogramaSection(
    List<Map<String, dynamic>> atividades,
    String planejamentoId,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Cronograma",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _novaAtividade(planejamentoId),
                icon: const Icon(Icons.add, size: 16),
                label: const Text("Adicionar atividade"),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (atividades.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                "Nenhuma atividade ainda. Comece adicionando a primeira.",
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            )
          else
            ...atividades.map((a) {
              final concluida = a["concluida"] as bool;
              final data = _parseData(a);
              final hora = _formatHora(a);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: concluida,
                      activeColor: const Color(0xFF7A0BD4),
                      onChanged: (_) => _toggleAtividade(a),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a["descricao"] as String,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                decoration: concluida
                                    ? TextDecoration.lineThrough
                                    : null,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (data != null) ...[
                                  const Icon(
                                    Icons.event,
                                    size: 12,
                                    color: Colors.white38,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatData(data),
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                                if (hora != null) ...[
                                  const SizedBox(width: 10),
                                  const Icon(
                                    Icons.access_time,
                                    size: 12,
                                    color: Colors.white38,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    hora,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _abrirObservacoes(a),
                      icon: const Icon(Icons.comment_outlined, size: 14),
                      label: const Text(
                        "Observacao",
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _calendarSection(List<Map<String, dynamic>> atividades) {
    final firstDayOfMonth = DateTime(
      _calendarMonth.year,
      _calendarMonth.month,
      1,
    );
    final daysInMonth = DateTime(
      _calendarMonth.year,
      _calendarMonth.month + 1,
      0,
    ).day;
    final leadingEmpty = firstDayOfMonth.weekday % 7;
    final totalCells = ((leadingEmpty + daysInMonth) / 7).ceil() * 7;
    final today = DateTime.now();

    final byDay = <int, List<Map<String, dynamic>>>{};
    for (final a in atividades) {
      final data = _parseData(a);
      if (data == null ||
          data.year != _calendarMonth.year ||
          data.month != _calendarMonth.month)
        continue;
      byDay.putIfAbsent(data.day, () => []).add(a);
    }

    const meses = [
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
    const weekDays = ["D", "S", "T", "Q", "Q", "S", "S"];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.chevron_left,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: () => setState(
                  () => _calendarMonth = DateTime(
                    _calendarMonth.year,
                    _calendarMonth.month - 1,
                    1,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  meses[_calendarMonth.month - 1] +
                      " " +
                      _calendarMonth.year.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.chevron_right,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: () => setState(
                  () => _calendarMonth = DateTime(
                    _calendarMonth.year,
                    _calendarMonth.month + 1,
                    1,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: weekDays
                .map(
                  (w) => Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),
          ...List.generate((totalCells / 7).ceil(), (rowIndex) {
            return Row(
              children: List.generate(7, (colIndex) {
                final cellIndex = rowIndex * 7 + colIndex;
                final dayNumber = cellIndex - leadingEmpty + 1;
                final isCurrentMonth =
                    dayNumber >= 1 && dayNumber <= daysInMonth;
                final isToday =
                    isCurrentMonth &&
                    today.year == _calendarMonth.year &&
                    today.month == _calendarMonth.month &&
                    today.day == dayNumber;
                final dayAtividades = isCurrentMonth
                    ? (byDay[dayNumber] ?? const [])
                    : const [];
                return Expanded(
                  child: Container(
                    height: 34,
                    margin: const EdgeInsets.all(1.5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday
                          ? const Color(0xFF7A0BD4).withOpacity(0.25)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: !isCurrentMonth
                        ? null
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                dayNumber.toString(),
                                style: TextStyle(
                                  color: isToday
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 11,
                                  fontWeight: isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              if (dayAtividades.isNotEmpty)
                                Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.only(top: 2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF7A0BD4),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        title: const Text("Planejamento"),
      ),
      body: FutureBuilder<_PlanejamentoData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Erro: " + snapshot.error.toString(),
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!;
          final planejamento = data.planejamento;
          final atividades = data.atividades;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7A0BD4).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF7A0BD4).withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.link,
                        color: Color(0xFF7A0BD4),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Demanda original",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              widget.demandaTitulo,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  planejamento["titulo"] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if ((planejamento["descricao"] as String).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    planejamento["descricao"] as String,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 10),
                Builder(
                  builder: (context) {
                    final prioridade = DemandaPrioridadeX.fromValue(
                      planejamento["prioridade"] as String,
                    );
                    final color = _prioridadeColor(prioridade);
                    return Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              prioridade.label,
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.label_outline,
                              size: 14,
                              color: Colors.white38,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              planejamento["categoria"] as String,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: SingleChildScrollView(
                          child: _cronogramaSection(
                            atividades,
                            planejamento["id"] as String,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      SizedBox(width: 320, child: _calendarSection(atividades)),
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
}

class _NovaAtividadeDialog extends StatefulWidget {
  final String planejamentoId;
  final DemandaRepository repository;
  const _NovaAtividadeDialog({
    required this.planejamentoId,
    required this.repository,
  });

  @override
  State<_NovaAtividadeDialog> createState() => _NovaAtividadeDialogState();
}

class _NovaAtividadeDialogState extends State<_NovaAtividadeDialog> {
  final _descricaoController = TextEditingController();
  DateTime _data = DateTime.now();
  TimeOfDay? _hora;
  bool _saving = false;

  @override
  void dispose() {
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _pickData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(_data.year - 1),
      lastDate: DateTime(_data.year + 3),
    );
    if (picked != null) setState(() => _data = picked);
  }

  Future<void> _pickHora() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _hora ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _hora = picked);
  }

  Future<void> _save() async {
    final descricao = _descricaoController.text.trim();
    if (descricao.isEmpty) return;
    setState(() => _saving = true);
    final horaHHmm = _hora != null
        ? _hora!.hour.toString().padLeft(2, "0") +
              ":" +
              _hora!.minute.toString().padLeft(2, "0") +
              ":00"
        : null;
    await widget.repository.adicionarAtividade(
      planejamentoId: widget.planejamentoId,
      descricao: descricao,
      data: _data,
      horaHHmm: horaHHmm,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Nova Atividade",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descricaoController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Descricao",
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickData,
                      icon: const Icon(Icons.event, size: 16),
                      label: Text(
                        _data.day.toString().padLeft(2, "0") +
                            "/" +
                            _data.month.toString().padLeft(2, "0") +
                            "/" +
                            _data.year.toString(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickHora,
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text(
                        _hora == null
                            ? "Sem horario"
                            : _hora!.hour.toString().padLeft(2, "0") +
                                  ":" +
                                  _hora!.minute.toString().padLeft(2, "0"),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text("Cancelar"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A0BD4),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_saving ? "Salvando..." : "Adicionar"),
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

class _AtividadeObservacoesDialog extends StatefulWidget {
  final Map<String, dynamic> atividade;
  final DemandaRepository repository;
  const _AtividadeObservacoesDialog({
    required this.atividade,
    required this.repository,
  });

  @override
  State<_AtividadeObservacoesDialog> createState() =>
      _AtividadeObservacoesDialogState();
}

class _AtividadeObservacoesDialogState
    extends State<_AtividadeObservacoesDialog> {
  final _textoController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadAtividadeObservacoes(
      widget.atividade["id"] as String,
    );
  }

  @override
  void dispose() {
    _textoController.dispose();
    super.dispose();
  }

  String _managerLabel(dynamic autor) {
    if (autor is! Map) return "-";
    final fullName = autor["full_name"] as String?;
    if (fullName != null && fullName.isNotEmpty) return fullName;
    return (autor["login_email"] as String?) ?? "-";
  }

  Future<void> _save() async {
    final texto = _textoController.text.trim();
    if (texto.isEmpty) return;
    setState(() => _saving = true);
    await widget.repository.adicionarAtividadeObservacao(
      widget.atividade["id"] as String,
      texto,
    );
    _textoController.clear();
    setState(() {
      _saving = false;
      _future = widget.repository.loadAtividadeObservacoes(
        widget.atividade["id"] as String,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Observacoes - " + (widget.atividade["descricao"] as String),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    if (snapshot.data!.isEmpty)
                      return const Center(
                        child: Text(
                          "Nenhuma observacao ainda.",
                          style: TextStyle(color: Colors.white54),
                        ),
                      );
                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final o = snapshot.data![index];
                        final date = DateTime.parse(
                          o["created_at"] as String,
                        ).toLocal().toString().substring(0, 16);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _managerLabel(o["autor"]) + " - " + date,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                o["texto"] as String,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _textoController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Ex: Explicar sobre a meta semanal.",
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Fechar"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A0BD4),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_saving ? "Salvando..." : "Adicionar"),
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
