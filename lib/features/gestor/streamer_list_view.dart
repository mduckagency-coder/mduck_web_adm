import "package:flutter/material.dart";
import "gestor_streamer_service.dart";
import "streamer_alerts.dart";
import "streamer_side_panel.dart";

/// Um filtro rapido (chip) da lista -- so um rotulo e um predicado sobre a
/// linha. Definido fora do widget pra Novatos/Streamers/etc reusarem o
/// mesmo `StreamerListView` com conjuntos de chips diferentes.
class StreamerQuickFilter {
  final String label;
  final bool Function(GestorStreamerRow row) predicate;
  const StreamerQuickFilter({required this.label, required this.predicate});
}

/// Lista generica de streamers em formato de tabela/CRM -- usada pela tela
/// de Novatos, e reaproveitada (com outros filtros/colunas) quando a tela
/// de Streamers for construida, em vez de duas telas quase identicas.
/// Clicar numa linha sempre abre o mesmo painel lateral (openStreamerSidePanel).
class StreamerListView extends StatefulWidget {
  final List<GestorStreamerRow> rows;
  final List<StreamerQuickFilter> quickFilters;
  final Widget Function(BuildContext context)? extraFilters;

  /// Alertas por linha (🔴🟡🟢) -- opcional, so a tela Streamers passa isso
  /// (Novatos continua sem alertas, sem mudar nada la).
  final List<StreamerAlert> Function(GestorStreamerRow row)? alertsFor;

  const StreamerListView({
    super.key,
    required this.rows,
    this.quickFilters = const [],
    this.extraFilters,
    this.alertsFor,
  });

  @override
  State<StreamerListView> createState() => _StreamerListViewState();
}

enum _SortKey { nome, dias, diamantes, ultimaLive, crescimento }

class _StreamerListViewState extends State<StreamerListView> {
  String _search = "";
  int _quickFilterIndex = 0;
  _SortKey _sortKey = _SortKey.diamantes;
  bool _ascending = false;

  List<GestorStreamerRow> get _filtered {
    var list = widget.rows.where((r) {
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!r.displayName.toLowerCase().contains(q) &&
            !r.nick.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (widget.quickFilters.isNotEmpty) {
        return widget.quickFilters[_quickFilterIndex].predicate(r);
      }
      return true;
    }).toList();

    int cmp(GestorStreamerRow a, GestorStreamerRow b) {
      switch (_sortKey) {
        case _SortKey.nome:
          return a.displayName.compareTo(b.displayName);
        case _SortKey.dias:
          return a.daysInAgency.compareTo(b.daysInAgency);
        case _SortKey.diamantes:
          return a.diamonds.compareTo(b.diamonds);
        case _SortKey.ultimaLive:
          final aTime = a.lastLiveAt ?? DateTime(2000);
          final bTime = b.lastLiveAt ?? DateTime(2000);
          return aTime.compareTo(bTime);
        case _SortKey.crescimento:
          return a.growth.compareTo(b.growth);
      }
    }

    list.sort(_ascending ? cmp : (a, b) => cmp(b, a));
    return list;
  }

  Widget _sortHeader(String label, _SortKey key, {int flex = 1}) {
    final active = _sortKey == key;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => setState(() {
          if (active) {
            _ascending = !_ascending;
          } else {
            _sortKey = key;
            _ascending = false;
          }
        }),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white54,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 2),
              Icon(
                _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.white54,
                    size: 18,
                  ),
                  hintText: "Buscar por nick ou nome",
                  hintStyle: TextStyle(color: Colors.white38),
                ),
                onChanged: (v) => setState(() => _search = v.trim()),
              ),
            ),
            if (widget.extraFilters != null) ...[
              const SizedBox(width: 12),
              widget.extraFilters!(context),
            ],
          ],
        ),
        if (widget.quickFilters.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: widget.quickFilters.asMap().entries.map((entry) {
              final selected = _quickFilterIndex == entry.key;
              return ChoiceChip(
                label: Text(
                  entry.value.label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 12,
                  ),
                ),
                selected: selected,
                selectedColor: const Color(0xFF7A0BD4),
                backgroundColor: Colors.white.withOpacity(0.05),
                onSelected: (_) =>
                    setState(() => _quickFilterIndex = entry.key),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          filtered.length.toString() + " streamer(s)",
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white24)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 44),
              _sortHeader("Nick / Nome", _SortKey.nome, flex: 3),
              _sortHeader("Dias", _SortKey.dias),
              _sortHeader("Diamantes (mês)", _SortKey.diamantes, flex: 2),
              _sortHeader("Crescimento", _SortKey.crescimento, flex: 2),
              const Expanded(
                flex: 2,
                child: Text(
                  "Potencial",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              _sortHeader("Última live", _SortKey.ultimaLive, flex: 2),
              const Expanded(
                flex: 2,
                child: Text(
                  "Último acompanhamento",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              const Expanded(
                flex: 2,
                child: Text(
                  "Próxima ação",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              const Expanded(
                flex: 2,
                child: Text(
                  "Gestor",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              const Expanded(
                flex: 2,
                child: Text(
                  "Status",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    "Nenhum streamer encontrado.",
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final row = filtered[index];
                    final status = row.status;
                    final alerts = widget.alertsFor?.call(row) ?? const [];
                    return InkWell(
                      onTap: () =>
                          openStreamerSidePanel(context, streamerId: row.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.white12),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 44,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.white24,
                                    backgroundImage: row.avatarUrl != null
                                        ? NetworkImage(row.avatarUrl!)
                                        : null,
                                    child: row.avatarUrl == null
                                        ? const Icon(
                                            Icons.person,
                                            color: Colors.white54,
                                            size: 16,
                                          )
                                        : null,
                                  ),
                                  if (alerts.isNotEmpty)
                                    Positioned(
                                      right: -2,
                                      top: -2,
                                      child: Tooltip(
                                        message: alerts
                                            .map((a) => a.emoji + " " + a.label)
                                            .join("\n"),
                                        child: Text(
                                          alerts.first.emoji,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "@" + row.nick,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    row.displayName,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Text(
                                row.daysInAgency.toString(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                row.diamonds.toString(),
                                style: const TextStyle(
                                  color: Color(0xFF7A0BD4),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                row.diamondsLastMonth == null
                                    ? "-"
                                    : (row.growth >= 0 ? "+" : "") +
                                          row.growth.toString(),
                                style: TextStyle(
                                  color: row.growth >= 0
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: potentialColor(
                                    row.potentialLevel,
                                  ).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  potentialLabel(row.potentialLevel),
                                  style: TextStyle(
                                    color: potentialColor(row.potentialLevel),
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                row.lastLiveAt != null
                                    ? row.lastLiveAt!
                                          .toLocal()
                                          .toString()
                                          .substring(0, 10)
                                    : "Nunca",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                row.lastContactAt != null
                                    ? row.lastContactAt!
                                          .toLocal()
                                          .toString()
                                          .substring(0, 10)
                                    : "-",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                row.nextAction?.title ?? "-",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                row.assignedManagerEmail ?? "-",
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: status.$2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  status.$1,
                                  style: TextStyle(
                                    color: status.$2,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
