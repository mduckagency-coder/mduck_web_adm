import "package:supabase_flutter/supabase_flutter.dart";
import "atividade_agenda_item.dart";
import "demanda_model.dart";
import "demanda_notifications.dart";

const _demandaSelect =
    "*, "
    "criado_por_manager:managers!demandas_criado_por_fkey(login_email, full_name, photo_url), "
    "responsavel_manager:managers!demandas_responsavel_id_fkey(login_email, full_name, photo_url)";

const _observacaoSelect =
    "id, texto, created_at, autor:managers!demanda_observacoes_autor_id_fkey(login_email, full_name)";

const _atividadeObservacaoSelect =
    "id, texto, created_at, autor:managers!planejamento_atividade_observacoes_autor_id_fkey(login_email, full_name)";

/// Quantidade de ocorrencias geradas de uma vez para uma demanda com
/// "repetir todo mes" marcado (a original + as proximas 11, um ano fechado).
const _ocorrenciasRecorrencia = 12;

/// Mesmo dia do mes, um mes a frente; quando o mes seguinte for mais curto
/// (ex.: dia 31 -> fevereiro), cai para o ultimo dia daquele mes.
DateTime _addMonthsClamped(DateTime date, int months) {
  final totalMonths = (date.month - 1) + months;
  final year = date.year + totalMonths ~/ 12;
  final month = totalMonths % 12 + 1;
  final lastDayOfMonth = DateTime(year, month + 1, 0).day;
  final day = date.day > lastDayOfMonth ? lastDayOfMonth : date.day;
  return DateTime(year, month, day, date.hour, date.minute, date.second);
}

/// Acesso a dados de Demandas e Planejamento. Toda a agencia e escopada por
/// RLS no banco (agency_id do gestor logado) -- aqui so montamos as queries.
class DemandaRepository {
  final _client = Supabase.instance.client;

  String get _userId => _client.auth.currentUser!.id;

  Future<String> _myAgencyId() async {
    final row = await _client
        .from("managers")
        .select("agency_id")
        .eq("id", _userId)
        .single();
    return row["agency_id"] as String;
  }

  /// Demandas que o gestor logado criou ou das quais e responsavel.
  Future<List<Demanda>> loadMinhasDemandas() async {
    final userId = _userId;
    final rows = await _client
        .from("demandas")
        .select(_demandaSelect)
        .or("criado_por.eq.$userId,responsavel_id.eq.$userId")
        .order("created_at", ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Demanda.fromRow)
        .toList();
  }

  Future<List<Map<String, dynamic>>> loadManagersDaAgencia() async {
    final agencyId = await _myAgencyId();
    final rows = await _client
        .from("managers")
        .select("id, login_email, full_name, photo_url")
        .eq("agency_id", agencyId)
        .order("full_name");
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> criarDemanda({
    required String titulo,
    required String descricao,
    required DemandaPrioridade prioridade,
    required String categoria,
    required String icone,
    required DateTime? prazo,
    required String responsavelId,
    required String criadoPorLabel,
    bool repeteMensalmente = false,
  }) async {
    final agencyId = await _myAgencyId();

    final inserted = await _client
        .from("demandas")
        .insert({
          "agency_id": agencyId,
          "titulo": titulo,
          "descricao": descricao,
          "prioridade": prioridade.value,
          "categoria": categoria,
          "icone": icone,
          "prazo": prazo?.toIso8601String(),
          "responsavel_id": responsavelId,
          "criado_por": _userId,
          "repete_mensalmente": repeteMensalmente && prazo != null,
        })
        .select("id")
        .single();
    final firstId = inserted["id"] as String;

    if (repeteMensalmente && prazo != null) {
      await _client
          .from("demandas")
          .update({"serie_id": firstId})
          .eq("id", firstId);

      final futuras = List.generate(_ocorrenciasRecorrencia - 1, (i) {
        final ocorrenciaPrazo = _addMonthsClamped(prazo, i + 1);
        return {
          "agency_id": agencyId,
          "titulo": titulo,
          "descricao": descricao,
          "prioridade": prioridade.value,
          "categoria": categoria,
          "icone": icone,
          "prazo": ocorrenciaPrazo.toIso8601String(),
          "responsavel_id": responsavelId,
          "criado_por": _userId,
          "repete_mensalmente": true,
          "serie_id": firstId,
        };
      });
      await _client.from("demandas").insert(futuras);
    }

    if (responsavelId != _userId) {
      await notifyNewDemanda(
        responsavelId: responsavelId,
        demandaTitulo: titulo,
        criadoPorLabel: criadoPorLabel,
      );
    }
  }

  Future<void> atualizarDemanda({
    required String demandaId,
    required String titulo,
    required String descricao,
    required DemandaPrioridade prioridade,
    required String categoria,
    required String icone,
    required DateTime? prazo,
    required String responsavelId,
  }) async {
    await _client
        .from("demandas")
        .update({
          "titulo": titulo,
          "descricao": descricao,
          "prioridade": prioridade.value,
          "categoria": categoria,
          "icone": icone,
          "prazo": prazo?.toIso8601String(),
          "responsavel_id": responsavelId,
          "updated_at": DateTime.now().toIso8601String(),
        })
        .eq("id", demandaId);
  }

  /// Apaga a demanda e, em cascata (FKs on delete cascade), seu planejamento,
  /// atividades e observacoes.
  Future<void> excluirDemanda(String demandaId) async {
    await _client.from("demandas").delete().eq("id", demandaId);
  }

  Future<void> atualizarStatus(String demandaId, DemandaStatus status) async {
    await _client
        .from("demandas")
        .update({
          "status": status.value,
          "updated_at": DateTime.now().toIso8601String(),
        })
        .eq("id", demandaId);
  }

  Future<List<Map<String, dynamic>>> loadObservacoes(String demandaId) async {
    final rows = await _client
        .from("demanda_observacoes")
        .select(_observacaoSelect)
        .eq("demanda_id", demandaId)
        .order("created_at");
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> adicionarObservacao(String demandaId, String texto) async {
    await _client.from("demanda_observacoes").insert({
      "demanda_id": demandaId,
      "autor_id": _userId,
      "texto": texto,
    });
  }

  Future<Map<String, dynamic>?> loadPlanejamento(String demandaId) async {
    return await _client
        .from("planejamentos")
        .select()
        .eq("demanda_id", demandaId)
        .maybeSingle();
  }

  /// Cria o planejamento da demanda (copiando titulo/descricao/prioridade/
  /// categoria) se ainda nao existir, ou apenas retorna o ja existente.
  Future<Map<String, dynamic>> criarOuAbrirPlanejamento(Demanda demanda) async {
    final existing = await loadPlanejamento(demanda.id);
    if (existing != null) return existing;

    final inserted = await _client
        .from("planejamentos")
        .insert({
          "demanda_id": demanda.id,
          "titulo": demanda.titulo,
          "descricao": demanda.descricao,
          "prioridade": demanda.prioridade.value,
          "categoria": demanda.categoria,
          "created_by": _userId,
        })
        .select()
        .single();

    if (demanda.status == DemandaStatus.naoIniciada) {
      await atualizarStatus(demanda.id, DemandaStatus.emAndamento);
    }

    return inserted;
  }

  Future<List<Map<String, dynamic>>> loadAtividades(
    String planejamentoId,
  ) async {
    final rows = await _client
        .from("planejamento_atividades")
        .select()
        .eq("planejamento_id", planejamentoId)
        .order("data")
        .order("hora");
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// [horaHHmm] ja formatado como "HH:mm:00" (ou null se sem horario).
  Future<void> adicionarAtividade({
    required String planejamentoId,
    required String descricao,
    required DateTime data,
    String? horaHHmm,
    required DemandaPrioridade prioridade,
  }) async {
    await _client.from("planejamento_atividades").insert({
      "planejamento_id": planejamentoId,
      "descricao": descricao,
      "data": data.toIso8601String().substring(0, 10),
      "hora": horaHHmm,
      "prioridade": prioridade.value,
      "created_by": _userId,
    });
  }

  /// Todas as atividades de cronograma da agencia (de qualquer planejamento),
  /// com o titulo/id da demanda de origem -- usado para plotar as atividades
  /// junto com as demandas na visao Mes/Semana/Dia da pagina de Demandas.
  Future<List<AtividadeAgendaItem>> loadAtividadesDaAgencia() async {
    final rows = await _client
        .from("planejamento_atividades")
        .select(
          "*, planejamento:planejamentos(id, demanda_id, demanda:demandas(id, titulo))",
        )
        .order("data");
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(AtividadeAgendaItem.fromRow)
        .toList();
  }

  Future<void> alternarConcluida(String atividadeId, bool concluida) async {
    await _client
        .from("planejamento_atividades")
        .update({
          "concluida": concluida,
          "updated_at": DateTime.now().toIso8601String(),
        })
        .eq("id", atividadeId);
  }

  Future<List<Map<String, dynamic>>> loadAtividadeObservacoes(
    String atividadeId,
  ) async {
    final rows = await _client
        .from("planejamento_atividade_observacoes")
        .select(_atividadeObservacaoSelect)
        .eq("atividade_id", atividadeId)
        .order("created_at");
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> adicionarAtividadeObservacao(
    String atividadeId,
    String texto,
  ) async {
    await _client.from("planejamento_atividade_observacoes").insert({
      "atividade_id": atividadeId,
      "autor_id": _userId,
      "texto": texto,
    });
  }
}
