import "package:flutter/material.dart";
import "demanda_model.dart";
import "demanda_repository.dart";
import "planejamento_page.dart";

/// Painel lateral com os detalhes de uma demanda: dados principais,
/// observacoes (mural cronologico) e o botao para planejar a execucao.
class DemandaDetailDrawer extends StatefulWidget {
  final Demanda demanda;
  final VoidCallback onClose;
  final ValueChanged<DemandaStatus> onStatusChanged;

  const DemandaDetailDrawer({
    super.key,
    required this.demanda,
    required this.onClose,
    required this.onStatusChanged,
  });

  @override
  State<DemandaDetailDrawer> createState() => _DemandaDetailDrawerState();
}

class _DemandaDetailDrawerState extends State<DemandaDetailDrawer> {
  final _repository = DemandaRepository();
  final _observacaoController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _observacoesFuture;
  bool _sendingObservacao = false;
  bool _abrindoPlanejamento = false;

  @override
  void initState() {
    super.initState();
    _observacoesFuture = _repository.loadObservacoes(widget.demanda.id);
  }

  @override
  void didUpdateWidget(covariant DemandaDetailDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.demanda.id != widget.demanda.id) {
      _observacoesFuture = _repository.loadObservacoes(widget.demanda.id);
    }
  }

  @override
  void dispose() {
    _observacaoController.dispose();
    super.dispose();
  }

  String _managerLabel(dynamic autor) {
    if (autor is! Map) return "-";
    final fullName = autor["full_name"] as String?;
    if (fullName != null && fullName.isNotEmpty) return fullName;
    return (autor["login_email"] as String?) ?? "-";
  }

  Future<void> _addObservacao() async {
    final texto = _observacaoController.text.trim();
    if (texto.isEmpty) return;
    setState(() => _sendingObservacao = true);
    await _repository.adicionarObservacao(widget.demanda.id, texto);
    _observacaoController.clear();
    if (!mounted) return;
    setState(() {
      _sendingObservacao = false;
      _observacoesFuture = _repository.loadObservacoes(widget.demanda.id);
    });
  }

  Future<void> _planejarExecucao() async {
    setState(() => _abrindoPlanejamento = true);
    try {
      await _repository.criarOuAbrirPlanejamento(widget.demanda);
      if (widget.demanda.status == DemandaStatus.naoIniciada) {
        widget.onStatusChanged(DemandaStatus.emAndamento);
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlanejamentoPage(
            demandaId: widget.demanda.id,
            demandaTitulo: widget.demanda.titulo,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _abrindoPlanejamento = false);
    }
  }

  Widget _row(String label, Widget value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
        Expanded(child: value),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final d = widget.demanda;
    final color = demandaCor(d);

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
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      demandaIconFor(d.icone),
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      d.titulo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      if (d.descricao.isNotEmpty) ...[
                        Text(
                          d.descricao,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _row(
                        "Prioridade",
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
                              demandaCorLabel(d),
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _row(
                        "Categoria",
                        Text(
                          d.categoria,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      _row(
                        "Prazo",
                        Text(
                          d.prazo == null
                              ? "Sem prazo"
                              : d.prazo!.day.toString().padLeft(2, "0") +
                                    "/" +
                                    d.prazo!.month.toString().padLeft(2, "0") +
                                    "/" +
                                    d.prazo!.year.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      _row(
                        "Responsavel",
                        Text(
                          d.responsavelLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      _row(
                        "Criado por",
                        Text(
                          d.criadoPorLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      _row(
                        "Status",
                        Wrap(
                          spacing: 6,
                          children: DemandaStatus.values.map((s) {
                            final selected = d.status == s;
                            return ChoiceChip(
                              label: Text(
                                s.label,
                                style: const TextStyle(fontSize: 11),
                              ),
                              selected: selected,
                              selectedColor: const Color(0xFF7A0BD4),
                              backgroundColor: Colors.white.withOpacity(0.05),
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : Colors.white70,
                              ),
                              onSelected: (_) => widget.onStatusChanged(s),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _abrindoPlanejamento
                              ? null
                              : _planejarExecucao,
                          icon: const Icon(Icons.calendar_month),
                          label: Text(
                            _abrindoPlanejamento
                                ? "Abrindo..."
                                : "Planejar execucao",
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7A0BD4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Observacoes",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _observacoesFuture,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData)
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: LinearProgressIndicator(),
                            );
                          final observacoes = snapshot.data!;
                          if (observacoes.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text(
                                "Nenhuma observacao ainda.",
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: observacoes.map((o) {
                              final date = DateTime.parse(
                                o["created_at"] as String,
                              ).toLocal().toString().substring(0, 16);
                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 8),
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
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      o["texto"] as String,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _observacaoController,
                        maxLines: 2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: "Registrar uma observacao...",
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: _sendingObservacao ? null : _addObservacao,
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(
                            _sendingObservacao
                                ? "Salvando..."
                                : "Adicionar observacao",
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
