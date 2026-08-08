import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:file_picker/file_picker.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:url_launcher/url_launcher.dart";
import "../recruiter/lead_category_icons.dart";

/// Fases do acompanhamento do streamer (abas do Material Acompanhamento).
/// So a "onboarding_15" tem quadro proprio hoje (Onboarding 0-15 Dias); as
/// demais existem aqui para o gestor ja poder organizar material com
/// antecedencia, antes dos quadros correspondentes existirem.
const stageTabs = [
  ("onboarding_15", "Onboarding 15"),
  ("onboarding_30", "Onboarding 30 Dias"),
  ("novato_2m", "2 Meses (Novato)"),
  ("novato_3m", "3 Meses (Novato)"),
  ("veterano", "Veterano"),
  ("pro", "Pro"),
];

/// Dias da etapa "Onboarding 15" (mesmas colunas do Kanban de Onboarding
/// 0-15 Dias). O material de cada dia aparece sozinho pro gestor assim que
/// o card do streamer chega naquele dia -- sem nenhuma vinculacao manual.
const onboardingDayKeys = [
  ("dia_1", "Dia 1"),
  ("dia_2", "Dia 2"),
  ("dia_3", "Dia 3"),
  ("dia_4", "Dia 4"),
  ("dia_5", "Dia 5"),
  ("dia_6", "Dia 6"),
  ("dia_7", "Dia 7"),
  ("dia_8", "Dia 8"),
  ("dia_9", "Dia 9"),
  ("dia_10", "Dia 10"),
  ("dia_11", "Dia 11"),
  ("dia_12", "Dia 12"),
  ("dia_13", "Dia 13"),
  ("dia_14", "Dia 14"),
  ("dia_15", "Dia 15"),
];

/// Dias da etapa "Onboarding 30 Dias" (mesmas colunas do Kanban de
/// Onboarding 16-31 Dias -- o rotulo da aba ja existia antes do quadro,
/// so ganhou os filtros de dia agora que o board existe).
const onboardingDayKeysModule2 = [
  ("dia_16", "Dia 16"),
  ("dia_17", "Dia 17"),
  ("dia_18", "Dia 18"),
  ("dia_19", "Dia 19"),
  ("dia_20", "Dia 20"),
  ("dia_21", "Dia 21"),
  ("dia_22", "Dia 22"),
  ("dia_23", "Dia 23"),
  ("dia_24", "Dia 24"),
  ("dia_25", "Dia 25"),
  ("dia_26", "Dia 26"),
  ("dia_27", "Dia 27"),
  ("dia_28", "Dia 28"),
  ("dia_29", "Dia 29"),
  ("dia_30", "Dia 30"),
  ("dia_31", "Dia 31"),
];

/// Qual fase tem filtro/dropdown de dia, e com quais opcoes -- generaliza
/// o que antes era so pra "onboarding_15" (isOnboarding15 hardcoded).
const _dayKeysByStage = {
  "onboarding_15": onboardingDayKeys,
  "onboarding_30": onboardingDayKeysModule2,
};

const _allDayKeys = [...onboardingDayKeys, ...onboardingDayKeysModule2];

const _nicheFilterOptions = [
  (null, "Todas"),
  ("gamer", "Gamers"),
  ("batalha", "Batalha"),
  ("musico", "Musica"),
];

const _authorPalette = [
  Color(0xFF7A0BD4),
  Color(0xFF00BCD4),
  Color(0xFFFF9800),
  Color(0xFF4CAF50),
  Color(0xFFE91E63),
  Color(0xFF3F51B5),
  Color(0xFFFFC107),
];

Color _colorForAuthor(String? email) {
  if (email == null || email.isEmpty) return _authorPalette[0];
  final index =
      email.codeUnits.fold<int>(0, (sum, c) => sum + c) % _authorPalette.length;
  return _authorPalette[index];
}

/// Um material do Onboarding 0-15 e visivel para um gestor quando: e
/// oficial (autor coordenador/admin, obrigatorio pra todos) ou foi criado
/// pelo proprio gestor logado (material privado -- nao aparece pra
/// colegas). Usado tanto na lista geral quanto no board do Onboarding.
bool isMaterialVisibleTo(Map<String, dynamic> material, String myUserId) {
  if (material["author_id"] == myUserId) return true;
  final authorData = material["managers"];
  final role = authorData is Map ? authorData["role"] as String? : null;
  return role == "coordenador" || role == "admin";
}

/// "Material Acompanhamento": biblioteca de material do Gestor, organizada
/// por fase do acompanhamento (Onboarding 15/30, 2/3 meses novato,
/// veterano, pro) -- dentro do Onboarding 15, por dia da etapa -- e
/// filtravel por nicho do streamer. Dois tipos: Material Oficial
/// (coordenador/admin, obrigatorio, todos veem, ninguem alem do autor
/// edita) e Material do Gestor (privado, so o proprio autor ve e edita).
/// Reaproveita a tabela training_materials com scope = 'acompanhamento'.
class OnboardingMaterialsPage extends StatefulWidget {
  const OnboardingMaterialsPage({super.key});

  @override
  State<OnboardingMaterialsPage> createState() =>
      _OnboardingMaterialsPageState();
}

class _OnboardingMaterialsPageState extends State<OnboardingMaterialsPage> {
  List<Map<String, dynamic>> _materials = [];
  bool _loading = true;
  String? _error;
  String _stage = stageTabs.first.$1;
  String? _dayFilter;
  String? _nicheFilter;
  String? _myUserId;
  List<Map<String, dynamic>> _pendingRequests = [];

  @override
  void initState() {
    super.initState();
    _myUserId = Supabase.instance.client.auth.currentUser!.id;
    _load();
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    final rows = await fetchPendingMaterialRequestsForMe();
    if (mounted) setState(() => _pendingRequests = rows);
  }

  Future<void> _openRequestMaterial() async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => const MaterialRequestFormDialog(),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pedido enviado.")),
      );
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final rows = await client
          .from("training_materials")
          .select("*, managers(login_email, role)")
          .eq("scope", "acompanhamento")
          .eq("is_archived", false)
          .order("stage")
          .order("onboarding_stage_key")
          .order("order_index");
      final visible = (rows as List)
          .cast<Map<String, dynamic>>()
          .where((m) => isMaterialVisibleTo(m, _myUserId!))
          .toList();
      if (mounted) {
        setState(() {
          _materials = visible;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _reload() => _load();

  void _openDetail(Map<String, dynamic> material) {
    showDialog(
      context: context,
      builder: (context) =>
          _MaterialDetailDialog(material: material, myUserId: _myUserId!),
    ).then((_) => _reload());
  }

  void _openCreate() {
    showDialog(
      context: context,
      builder: (context) => OnboardingMaterialFormDialog(
        defaultStage: _stage,
        defaultDayKey: _dayFilter,
        defaultNiche: _nicheFilter,
      ),
    ).then((saved) {
      if (saved == true) _reload();
    });
  }

  /// Reordena/move um material dentro do Material Acompanhamento: recalcula
  /// order_index de todos os materiais do mesmo par (fase, dia) com o item
  /// arrastado na posicao indicada (antes de "beforeItem", ou no final se
  /// null). Arrastar sobre um chip de dia (so existe na fase Onboarding 15)
  /// move para aquele dia; arrastar sobre outro material reordena e, se o
  /// alvo for de outro dia, move junto.
  Future<void> _moveMaterial(
    Map<String, dynamic> dragged, {
    String? newDayKey,
    Map<String, dynamic>? beforeItem,
  }) async {
    if (beforeItem != null && beforeItem["id"] == dragged["id"]) return;
    final stage = dragged["stage"] as String;
    final targetDayKey =
        newDayKey ??
        (beforeItem != null
            ? beforeItem["onboarding_stage_key"] as String?
            : dragged["onboarding_stage_key"] as String?);

    final siblings =
        _materials
            .where(
              (m) =>
                  m["id"] != dragged["id"] &&
                  m["stage"] == stage &&
                  m["onboarding_stage_key"] == targetDayKey,
            )
            .toList()
          ..sort(
            (a, b) => ((a["order_index"] as num?) ?? 0).compareTo(
              (b["order_index"] as num?) ?? 0,
            ),
          );

    final insertIndex = beforeItem == null
        ? siblings.length
        : siblings.indexWhere((m) => m["id"] == beforeItem["id"]);
    siblings.insert(insertIndex == -1 ? siblings.length : insertIndex, dragged);

    setState(() {
      dragged["onboarding_stage_key"] = targetDayKey;
      for (var i = 0; i < siblings.length; i++) {
        siblings[i]["order_index"] = i;
      }
    });

    try {
      final client = Supabase.instance.client;
      for (var i = 0; i < siblings.length; i++) {
        await client
            .from("training_materials")
            .update({
              "onboarding_stage_key": siblings[i]["onboarding_stage_key"],
              "order_index": i,
            })
            .eq("id", siblings[i]["id"]);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao mover: " + e.toString())),
        );
      _reload();
    }
  }

  Widget _buildTile(Map<String, dynamic> m) {
    final authorData = m["managers"];
    final authorEmail = authorData is Map
        ? authorData["login_email"] as String?
        : null;
    final authorRole = authorData is Map ? authorData["role"] as String? : null;
    final isMine = m["author_id"] == _myUserId;
    final isOfficial =
        !isMine && (authorRole == "coordenador" || authorRole == "admin");
    final createdDate = m["created_at"] != null
        ? DateTime.parse(m["created_at"]).toLocal().toString().substring(0, 10)
        : "-";
    final authorColor = _colorForAuthor(authorEmail);
    final niche = m["niche"] as String?;
    final dayKey = m["onboarding_stage_key"] as String?;
    final dayLabel = dayKey != null
        ? _allDayKeys
              .firstWhere((d) => d.$1 == dayKey, orElse: () => (dayKey, dayKey))
              .$2
        : null;

    return InkWell(
      onTap: () => _openDetail(m),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isOfficial
              ? authorColor.withOpacity(0.1)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: isOfficial
              ? Border.all(color: authorColor.withOpacity(0.6), width: 1.5)
              : (isMine ? Border.all(color: Colors.white24) : null),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.drag_indicator,
                  color: Colors.white24,
                  size: 18,
                ),
                const SizedBox(width: 4),
                if (niche != null) ...[
                  Icon(
                    categoryIcon(niche),
                    size: 14,
                    color: categoryColor(niche),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    m["title"] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (dayLabel != null)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      dayLabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (isOfficial)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "OFICIAL",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (isMine)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "MEU MATERIAL",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if ((m["description"] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                m["description"],
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            Text(
              "Criado por: " +
                  (authorEmail ?? "sistema") +
                  "  -  " +
                  createdDate,
              style: TextStyle(
                color: isOfficial ? authorColor : Colors.white38,
                fontSize: 11,
                fontStyle: FontStyle.italic,
                fontWeight: isOfficial ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayKeys = _dayKeysByStage[_stage];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Material Acompanhamento",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: _reload,
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _openRequestMaterial,
                icon: const Icon(Icons.forward_to_inbox, size: 18),
                label: const Text("Solicitar Material"),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _openCreate,
                icon: const Icon(Icons.add),
                label: const Text("Meu Material"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A0BD4),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Material automatico por etapa -- aparece sozinho pro gestor quando o streamer chega no dia/fase correspondente. Material Oficial (coordenador/admin) pode ser editado, excluido e arrastado por qualquer gestor; o seu proprio continua privado, so voce ve.",
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (_pendingRequests.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              "Pedidos de material pra você",
              style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._pendingRequests.map(
              (r) => PendingMaterialRequestCard(
                request: r,
                onFulfilled: _loadPendingRequests,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: stageTabs.map((s) {
                final selected = _stage == s.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      s.$2,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selected: selected,
                    selectedColor: const Color(0xFF7A0BD4),
                    backgroundColor: Colors.white.withOpacity(0.05),
                    onSelected: (_) => setState(() {
                      _stage = s.$1;
                      _dayFilter = null;
                    }),
                  ),
                );
              }).toList(),
            ),
          ),
          if (dayKeys != null) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        "Todos os dias",
                        style: TextStyle(
                          color: _dayFilter == null
                              ? Colors.white
                              : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      selected: _dayFilter == null,
                      selectedColor: const Color(0xFF7A0BD4),
                      backgroundColor: Colors.white.withOpacity(0.05),
                      onSelected: (_) => setState(() => _dayFilter = null),
                    ),
                  ),
                  ...dayKeys.map((d) {
                    final selected = _dayFilter == d.$1;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: DragTarget<Map<String, dynamic>>(
                        onWillAcceptWithDetails: (details) =>
                            details.data["onboarding_stage_key"] != d.$1,
                        onAcceptWithDetails: (details) =>
                            _moveMaterial(details.data, newDayKey: d.$1),
                        builder: (context, candidateData, rejectedData) {
                          final highlighting = candidateData.isNotEmpty;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: highlighting
                                  ? Border.all(
                                      color: const Color(0xFF7A0BD4),
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: ChoiceChip(
                              label: Text(
                                d.$2,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              selected: selected,
                              selectedColor: const Color(0xFF7A0BD4),
                              backgroundColor: Colors.white.withOpacity(0.05),
                              onSelected: (_) =>
                                  setState(() => _dayFilter = d.$1),
                            ),
                          );
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: _nicheFilterOptions.map((opt) {
              final selected = _nicheFilter == opt.$1;
              return FilterChip(
                avatar: opt.$1 != null
                    ? Icon(
                        categoryIcon(opt.$1),
                        size: 14,
                        color: selected ? Colors.white : categoryColor(opt.$1),
                      )
                    : null,
                label: Text(
                  opt.$2,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 12,
                  ),
                ),
                selected: selected,
                selectedColor: opt.$1 != null
                    ? categoryColor(opt.$1)
                    : const Color(0xFF7A0BD4),
                backgroundColor: Colors.white.withOpacity(0.05),
                onSelected: (_) => setState(() => _nicheFilter = opt.$1),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        "Erro ao carregar: " + _error!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : Builder(
                    builder: (context) {
                      final list = _materials.where((m) {
                        if (m["stage"] != _stage) return false;
                        if (dayKeys != null &&
                            _dayFilter != null &&
                            m["onboarding_stage_key"] != _dayFilter)
                          return false;
                        if (_nicheFilter != null &&
                            m["niche"] != _nicheFilter)
                          return false;
                        return true;
                      }).toList();
                      if (list.isEmpty)
                        return const Center(
                          child: Text(
                            "Nenhum material cadastrado nesta fase ainda.",
                            style: TextStyle(color: Colors.white54),
                          ),
                        );
                      return ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final m = list[index];
                          final tile = _buildTile(m);
                          return DragTarget<Map<String, dynamic>>(
                            onWillAcceptWithDetails: (details) =>
                                details.data["id"] != m["id"],
                            onAcceptWithDetails: (details) =>
                                _moveMaterial(details.data, beforeItem: m),
                            builder: (context, candidateData, rejectedData) {
                              final highlighting = candidateData.isNotEmpty;
                              return Container(
                                decoration: highlighting
                                    ? BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFF7A0BD4),
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      )
                                    : null,
                                child: Draggable<Map<String, dynamic>>(
                                  data: m,
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: SizedBox(width: 320, child: tile),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.3,
                                    child: tile,
                                  ),
                                  child: tile,
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Nao foi possivel abrir: " + e.toString())),
      );
  }
}

Future<void> _copyToClipboard(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted)
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Link copiado.")));
}

/// Mostra as informacoes do material (titulo, texto, link/arquivo) num
/// dialog -- nao abre o link sozinho, so deixa ele visivel e com botao de
/// copiar, pra quem esta atendendo o streamer colar onde precisar (grupo,
/// WhatsApp, etc). Compartilhado com o board do Onboarding 0-15 Dias
/// (materiais mostrados automaticamente na etapa do streamer).
Future<void> openMaterialLinkOrText(
  BuildContext context,
  Map<String, dynamic> material,
) async {
  final linkUrl = material["link_url"] as String?;
  final fileUrl = material["file_url"] as String?;
  final imageUrl = material["image_url"] as String?;
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: Text(
        material["title"] as String? ?? "-",
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((material["description"] as String?)?.isNotEmpty == true) ...[
              const Text(
                "Texto",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SelectableText(
                      material["description"] as String,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.copy,
                      size: 16,
                      color: Colors.white54,
                    ),
                    tooltip: "Copiar texto",
                    onPressed: () => _copyToClipboard(
                      context,
                      material["description"] as String,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (linkUrl != null && linkUrl.trim().isNotEmpty) ...[
              const Text(
                "Link",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      linkUrl,
                      style: const TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.copy,
                      size: 16,
                      color: Colors.white54,
                    ),
                    tooltip: "Copiar link",
                    onPressed: () => _copyToClipboard(context, linkUrl),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (fileUrl != null && fileUrl.trim().isNotEmpty) ...[
              const Text(
                "Arquivo",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      fileUrl,
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.copy,
                      size: 16,
                      color: Colors.white54,
                    ),
                    tooltip: "Copiar link",
                    onPressed: () => _copyToClipboard(context, fileUrl),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (imageUrl != null && imageUrl.trim().isNotEmpty) ...[
              const Text(
                "Imagem",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(imageUrl, height: 140, fit: BoxFit.cover),
              ),
            ],
            if ((material["description"] as String?)?.isNotEmpty != true &&
                linkUrl == null &&
                fileUrl == null &&
                imageUrl == null)
              const Text(
                "Sem conteudo adicional.",
                style: TextStyle(color: Colors.white38),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Fechar"),
        ),
      ],
    ),
  );
}

class _MaterialDetailDialog extends StatefulWidget {
  final Map<String, dynamic> material;
  final String myUserId;
  const _MaterialDetailDialog({required this.material, required this.myUserId});

  @override
  State<_MaterialDetailDialog> createState() => _MaterialDetailDialogState();
}

class _MaterialDetailDialogState extends State<_MaterialDetailDialog> {
  Future<void> _delete() async {
    final authorData = widget.material["managers"];
    final authorRole = authorData is Map ? authorData["role"] as String? : null;
    final isOfficial = authorRole == "coordenador" || authorRole == "admin";
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          isOfficial ? "Excluir documento oficial?" : "Excluir material?",
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          isOfficial
              ? "Voce esta excluindo um documento oficial. Deseja continuar?"
              : "Nao pode ser desfeito.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text("Excluir"),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await Supabase.instance.client
          .from("training_materials")
          .delete()
          .eq("id", widget.material["id"]);
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _edit() {
    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (context) => OnboardingMaterialFormDialog(
        existing: widget.material,
        defaultStage: widget.material["stage"] as String,
        defaultDayKey: widget.material["onboarding_stage_key"] as String?,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.material;
    final authorData = m["managers"];
    final authorEmail = authorData is Map
        ? authorData["login_email"] as String?
        : null;
    final authorRole = authorData is Map ? authorData["role"] as String? : null;
    final isMine = m["author_id"] == widget.myUserId;
    final isOfficial =
        !isMine && (authorRole == "coordenador" || authorRole == "admin");
    final createdDate = m["created_at"] != null
        ? DateTime.parse(m["created_at"]).toLocal().toString().substring(0, 16)
        : "-";
    final authorColor = _colorForAuthor(authorEmail);
    final stageName = stageTabs
        .firstWhere(
          (s) => s.$1 == m["stage"],
          orElse: () =>
              (m["stage"] as String? ?? "-", m["stage"] as String? ?? "-"),
        )
        .$2;
    final niche = m["niche"] as String?;
    final dayKey = m["onboarding_stage_key"] as String?;
    final dayLabel = dayKey != null
        ? _allDayKeys
              .firstWhere((d) => d.$1 == dayKey, orElse: () => (dayKey, dayKey))
              .$2
        : null;

    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        m["title"] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isOfficial)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "OFICIAL",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.white54,
                        size: 18,
                      ),
                      onPressed: _edit,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                      onPressed: _delete,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      "Fase: " +
                          stageName +
                          (dayLabel != null ? " - " + dayLabel : ""),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    if (niche != null) ...[
                      const SizedBox(width: 10),
                      Icon(
                        categoryIcon(niche),
                        size: 14,
                        color: categoryColor(niche),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _nicheFilterOptions
                            .firstWhere(
                              (o) => o.$1 == niche,
                              orElse: () => (niche, niche),
                            )
                            .$2,
                        style: TextStyle(
                          color: categoryColor(niche),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  "Criado por: " +
                      (authorEmail ?? "sistema") +
                      " em " +
                      createdDate,
                  style: TextStyle(
                    color: isOfficial ? authorColor : Colors.white54,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                if ((m["description"] as String?)?.isNotEmpty == true) ...[
                  const Text(
                    "Texto",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    m["description"],
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                ],
                if ((m["link_url"] as String?)?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _openLink(context, m["link_url"] as String),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text("Abrir link"),
                    ),
                  ),
                if ((m["file_url"] as String?)?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _openLink(context, m["file_url"] as String),
                      icon: const Icon(Icons.attach_file, size: 16),
                      label: const Text("Abrir arquivo"),
                    ),
                  ),
                if ((m["image_url"] as String?)?.isNotEmpty == true) ...[
                  const Text(
                    "Imagem",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      m["image_url"],
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Fechar"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingMaterialFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final String defaultStage;
  final String? defaultDayKey;
  final String? defaultNiche;

  /// Quando aberto a partir de um pedido de material pendente (ver
  /// MaterialRequestFormDialog/_PendingRequestCard): pre-preenche a
  /// descricao com o que foi pedido e, ao salvar, marca o pedido como
  /// concluido e avisa quem pediu.
  final String? fulfillingRequestId;
  final String? initialDescription;

  const OnboardingMaterialFormDialog({
    super.key,
    this.existing,
    required this.defaultStage,
    this.defaultDayKey,
    this.defaultNiche,
    this.fulfillingRequestId,
    this.initialDescription,
  });

  @override
  State<OnboardingMaterialFormDialog> createState() =>
      _OnboardingMaterialFormDialogState();
}

class _OnboardingMaterialFormDialogState
    extends State<OnboardingMaterialFormDialog> {
  final _titleController = TextEditingController();
  final _textController = TextEditingController();
  final _linkController = TextEditingController();
  late String _stage;
  String? _dayKey;
  String? _niche;
  String? _fileUrl;
  String? _imageUrl;
  String? _fileName;
  String? _imageName;
  bool _saving = false;
  bool _uploadingFile = false;
  bool _uploadingImage = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _stage = widget.defaultStage;
    _dayKey = widget.defaultDayKey;
    _niche = widget.defaultNiche;
    if (widget.fulfillingRequestId != null && widget.initialDescription != null) {
      _textController.text = widget.initialDescription!;
    }
    final e = widget.existing;
    if (e != null) {
      _titleController.text = e["title"] ?? "";
      _textController.text = e["description"] ?? "";
      _linkController.text = e["link_url"] ?? "";
      _stage = e["stage"] as String? ?? _stage;
      _dayKey = e["onboarding_stage_key"] as String?;
      _niche = e["niche"] as String?;
      _fileUrl = e["file_url"];
      _imageUrl = e["image_url"];
    }
  }

  Future<void> _pickFile({required bool isImage}) async {
    setState(() {
      if (isImage) {
        _uploadingImage = true;
      } else {
        _uploadingFile = true;
      }
    });
    final result = await FilePicker.platform.pickFiles(
      type: isImage ? FileType.image : FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      setState(() {
        if (isImage) {
          _uploadingImage = false;
        } else {
          _uploadingFile = false;
        }
      });
      return;
    }
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() {
        if (isImage) {
          _uploadingImage = false;
        } else {
          _uploadingFile = false;
        }
      });
      return;
    }
    final client = Supabase.instance.client;
    final path =
        DateTime.now().millisecondsSinceEpoch.toString() + "_" + file.name;
    try {
      await client.storage
          .from("material_attachments")
          .uploadBinary(path, bytes);
      final publicUrl = client.storage
          .from("material_attachments")
          .getPublicUrl(path);
      setState(() {
        if (isImage) {
          _imageUrl = publicUrl;
          _imageName = file.name;
          _uploadingImage = false;
        } else {
          _fileUrl = publicUrl;
          _fileName = file.name;
          _uploadingFile = false;
        }
      });
    } catch (e) {
      setState(() {
        if (isImage) {
          _uploadingImage = false;
        } else {
          _uploadingFile = false;
        }
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao enviar: " + e.toString())),
        );
    }
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    if (_stage == "onboarding_15" && _dayKey == null) {
      setState(() => _errorMessage = "Selecione o dia da etapa.");
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    try {
      final manager = await client
          .from("managers")
          .select("agency_id")
          .eq("id", userId)
          .single();

      final data = {
        "agency_id": manager["agency_id"],
        "scope": "acompanhamento",
        "stage": _stage,
        "onboarding_stage_key": _stage == "onboarding_15" ? _dayKey : null,
        "niche": _niche,
        "category": _stage,
        "title": _titleController.text.trim(),
        "description": _textController.text.trim(),
        "link_url": _linkController.text.trim(),
        "file_url": _fileUrl,
        "image_url": _imageUrl,
        "author_id": userId,
        "updated_at": DateTime.now().toIso8601String(),
      };

      if (widget.existing != null) {
        await client
            .from("training_materials")
            .update(data)
            .eq("id", widget.existing!["id"]);
      } else {
        final inserted = await client
            .from("training_materials")
            .insert(data)
            .select("id")
            .single();
        if (widget.fulfillingRequestId != null) {
          await completeMaterialRequest(
            requestId: widget.fulfillingRequestId!,
            materialId: inserted["id"] as String,
          );
        }
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _errorMessage = "Erro ao salvar: " + e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existing != null ? "Editar material" : "Novo material",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Fase",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                DropdownButton<String>(
                  value: _stage,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  items: stageTabs
                      .map(
                        (s) => DropdownMenuItem(value: s.$1, child: Text(s.$2)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    _stage = v ?? _stage;
                    if (_dayKeysByStage[_stage] == null) _dayKey = null;
                  }),
                ),
                if (_dayKeysByStage[_stage] != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    "Dia da etapa",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const Text(
                    "O material aparece automaticamente quando o streamer estiver neste dia.",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 4),
                  DropdownButton<String>(
                    value: _dayKey,
                    isExpanded: true,
                    hint: const Text(
                      "Selecione o dia",
                      style: TextStyle(color: Colors.white38),
                    ),
                    dropdownColor: const Color(0xFF1A1A1A),
                    style: const TextStyle(color: Colors.white),
                    items: _dayKeysByStage[_stage]!
                        .map(
                          (d) =>
                              DropdownMenuItem(value: d.$1, child: Text(d.$2)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _dayKey = v),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  "Nicho (opcional -- sem nicho só aparece no filtro \"Todas\")",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                DropdownButton<String?>(
                  value: _niche,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  items: _nicheFilterOptions
                      .map(
                        (o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _niche = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Titulo",
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _textController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Texto",
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _linkController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Link (opcional)",
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploadingFile
                            ? null
                            : () => _pickFile(isImage: false),
                        icon: const Icon(Icons.attach_file, size: 16),
                        label: Text(
                          _uploadingFile
                              ? "Enviando..."
                              : (_fileName ?? "Anexar arquivo"),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploadingImage
                            ? null
                            : () => _pickFile(isImage: true),
                        icon: const Icon(Icons.image, size: 16),
                        label: Text(
                          _uploadingImage
                              ? "Enviando..."
                              : (_imageName ?? "Anexar imagem"),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_fileUrl != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      "Arquivo pronto.",
                      style: TextStyle(color: Colors.greenAccent, fontSize: 11),
                    ),
                  ),
                if (_imageUrl != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      "Imagem pronta.",
                      style: TextStyle(color: Colors.greenAccent, fontSize: 11),
                    ),
                  ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text("Cancelar"),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7A0BD4),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_saving ? "Salvando..." : "Salvar"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Solicitacao de material: em vez de criar direto, um gestor pode pedir
// pra outro colega criar um material (descreve o que precisa + prazo). Fica
// pendente pro colega ate ele criar o material vinculado; ao criar, quem
// pediu recebe uma notificacao confirmando que foi feito.
// ============================================================================

const _materialRequestSelect =
    "*, requester:managers!training_material_requests_requested_by_fkey(login_email, full_name), "
    "assignee:managers!training_material_requests_assigned_to_fkey(login_email, full_name)";

String _managerLabel(Map<String, dynamic>? m) {
  if (m == null) return "-";
  final name = m["full_name"] as String?;
  if (name != null && name.isNotEmpty) return name;
  return (m["login_email"] as String?) ?? "-";
}

String _formatDate(DateTime d) =>
    d.day.toString().padLeft(2, "0") + "/" + d.month.toString().padLeft(2, "0") + "/" + d.year.toString();

Future<void> createMaterialRequest({
  required String assignedTo,
  required String stage,
  String? dayKey,
  String? niche,
  required String description,
  DateTime? dueDate,
}) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser!.id;
  final manager = await client
      .from("managers")
      .select("agency_id, full_name, login_email")
      .eq("id", userId)
      .single();
  final requesterLabel = _managerLabel(manager);

  await client.from("training_material_requests").insert({
    "agency_id": manager["agency_id"],
    "requested_by": userId,
    "assigned_to": assignedTo,
    "stage": stage,
    "onboarding_stage_key": dayKey,
    "niche": niche,
    "description": description,
    "due_date": dueDate != null
        ? dueDate.toIso8601String().substring(0, 10)
        : null,
  });

  var message = requesterLabel + " pediu um material: \"" + description + "\".";
  if (dueDate != null) message = message + " Prazo: " + _formatDate(dueDate) + ".";
  await client.from("manager_notifications").insert({
    "manager_id": assignedTo,
    "subject": "Novo material solicitado",
    "message": message,
  });
}

Future<List<Map<String, dynamic>>> fetchPendingMaterialRequestsForMe() async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser!.id;
  final rows = await client
      .from("training_material_requests")
      .select(_materialRequestSelect)
      .eq("assigned_to", userId)
      .eq("status", "pendente")
      .order("due_date", ascending: true);
  return (rows as List).cast<Map<String, dynamic>>();
}

Future<List<Map<String, dynamic>>> fetchMyMaterialRequests() async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser!.id;
  final rows = await client
      .from("training_material_requests")
      .select(_materialRequestSelect)
      .eq("requested_by", userId)
      .order("created_at", ascending: false)
      .limit(20);
  return (rows as List).cast<Map<String, dynamic>>();
}

Future<void> completeMaterialRequest({
  required String requestId,
  required String materialId,
}) async {
  final client = Supabase.instance.client;
  final req = await client
      .from("training_material_requests")
      .select("requested_by, description")
      .eq("id", requestId)
      .single();
  await client.from("training_material_requests").update({
    "status": "concluido",
    "created_material_id": materialId,
    "completed_at": DateTime.now().toIso8601String(),
  }).eq("id", requestId);

  await client.from("manager_notifications").insert({
    "manager_id": req["requested_by"],
    "subject": "Material concluído",
    "message": "O material que você pediu (\"" + (req["description"] as String) + "\") foi criado.",
  });
}

/// Card de um pedido pendente pra mim, com atalho direto pra criar o
/// material ja vinculado (preenche descricao/fase/dia automaticamente).
class PendingMaterialRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onFulfilled;
  const PendingMaterialRequestCard({
    super.key,
    required this.request,
    required this.onFulfilled,
  });

  @override
  Widget build(BuildContext context) {
    final dueDate = request["due_date"] != null
        ? DateTime.parse(request["due_date"] as String)
        : null;
    final stageName = stageTabs
        .firstWhere(
          (s) => s.$1 == request["stage"],
          orElse: () => (request["stage"] as String, request["stage"] as String),
        )
        .$2;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.pending_actions, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Pedido de " + _managerLabel(request["requester"] as Map<String, dynamic>?) + " -- " + stageName,
                  style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  request["description"] as String,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                if (dueDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Prazo: " + _formatDate(dueDate),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              final saved = await showDialog<bool>(
                context: context,
                builder: (_) => OnboardingMaterialFormDialog(
                  defaultStage: request["stage"] as String,
                  defaultDayKey: request["onboarding_stage_key"] as String?,
                  defaultNiche: request["niche"] as String?,
                  fulfillingRequestId: request["id"] as String,
                  initialDescription: request["description"] as String,
                ),
              );
              if (saved == true) onFulfilled();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7A0BD4),
              foregroundColor: Colors.white,
            ),
            child: const Text("Criar material"),
          ),
        ],
      ),
    );
  }
}

/// Dialogo pra pedir material a outro gestor -- mesma categorizacao
/// (fase/dia/nicho) do material em si, pra ele ja nascer no lugar certo
/// quando for criado.
class MaterialRequestFormDialog extends StatefulWidget {
  const MaterialRequestFormDialog({super.key});

  @override
  State<MaterialRequestFormDialog> createState() => _MaterialRequestFormDialogState();
}

class _MaterialRequestFormDialogState extends State<MaterialRequestFormDialog> {
  final _descriptionController = TextEditingController();
  List<Map<String, dynamic>> _managers = [];
  String? _assignedTo;
  String _stage = stageTabs.first.$1;
  String? _dayKey;
  String? _niche;
  DateTime? _dueDate;
  bool _loadingManagers = true;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadManagers();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadManagers() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final me = await client.from("managers").select("agency_id").eq("id", userId).single();
    final rows = await client
        .from("managers")
        .select("id, login_email, full_name")
        .eq("agency_id", me["agency_id"])
        .neq("id", userId)
        .order("login_email");
    if (mounted) {
      setState(() {
        _managers = (rows as List).cast<Map<String, dynamic>>();
        _loadingManagers = false;
      });
    }
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (_assignedTo == null) {
      setState(() => _errorMessage = "Selecione pra quem pedir.");
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Descreva o que precisa.");
      return;
    }
    if (_stage == "onboarding_15" && _dayKey == null) {
      setState(() => _errorMessage = "Selecione o dia da etapa.");
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await createMaterialRequest(
        assignedTo: _assignedTo!,
        stage: _stage,
        dayKey: _stage == "onboarding_15" ? _dayKey : null,
        niche: _niche,
        description: _descriptionController.text.trim(),
        dueDate: _dueDate,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _errorMessage = "Erro ao solicitar: " + e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayKeys = _dayKeysByStage[_stage];
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Solicitar material",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                "Peça pra outro gestor criar um material -- ele fica com o pedido pendente até criar.",
                style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Pedir para", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 4),
                      _loadingManagers
                          ? const LinearProgressIndicator()
                          : DropdownButton<String>(
                              value: _assignedTo,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF1A1A1A),
                              style: const TextStyle(color: Colors.white),
                              hint: const Text("Selecione um gestor", style: TextStyle(color: Colors.white38)),
                              items: _managers
                                  .map((m) => DropdownMenuItem(value: m["id"] as String, child: Text(_managerLabel(m))))
                                  .toList(),
                              onChanged: (v) => setState(() => _assignedTo = v),
                            ),
                      const SizedBox(height: 12),
                      const Text("Fase", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 4),
                      DropdownButton<String>(
                        value: _stage,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1A1A1A),
                        style: const TextStyle(color: Colors.white),
                        items: stageTabs
                            .map((s) => DropdownMenuItem(value: s.$1, child: Text(s.$2)))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _stage = v ?? _stage;
                          if (_dayKeysByStage[_stage] == null) _dayKey = null;
                        }),
                      ),
                      if (dayKeys != null) ...[
                        const SizedBox(height: 12),
                        const Text("Dia", style: TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(height: 4),
                        DropdownButton<String>(
                          value: _dayKey,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1A1A1A),
                          style: const TextStyle(color: Colors.white),
                          hint: const Text("Selecione o dia", style: TextStyle(color: Colors.white38)),
                          items: dayKeys
                              .map((d) => DropdownMenuItem(value: d.$1, child: Text(d.$2)))
                              .toList(),
                          onChanged: (v) => setState(() => _dayKey = v),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Text("Nicho (opcional)", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 4),
                      DropdownButton<String?>(
                        value: _niche,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1A1A1A),
                        style: const TextStyle(color: Colors.white),
                        items: _nicheFilterOptions
                            .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)))
                            .toList(),
                        onChanged: (v) => setState(() => _niche = v),
                      ),
                      const SizedBox(height: 12),
                      const Text("O que você precisa", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "Descreva o material que precisa (tema, formato, pontos que deve cobrir...)",
                          hintStyle: TextStyle(color: Colors.white38),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text("Prazo de entrega (opcional)", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 4),
                      OutlinedButton.icon(
                        onPressed: _pickDueDate,
                        icon: const Icon(Icons.calendar_month, size: 16),
                        label: Text(_dueDate == null ? "Definir prazo" : _formatDate(_dueDate!)),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                    child: Text(_saving ? "Enviando..." : "Solicitar"),
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
