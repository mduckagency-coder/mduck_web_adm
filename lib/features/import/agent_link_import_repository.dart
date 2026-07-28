import "package:excel/excel.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class AgentLinkRowResult {
  final String tiktokId;
  final String nome;
  final String agentEmail;
  final String status; // "vinculado" | "streamer_nao_encontrado" | "agente_nao_encontrado" | "erro"
  final String? detail;

  AgentLinkRowResult({required this.tiktokId, required this.nome, required this.agentEmail, required this.status, this.detail});
}

class AgentLinkImportSummary {
  final List<AgentLinkRowResult> rows;
  final int totalRowsRead;
  AgentLinkImportSummary(this.rows, this.totalRowsRead);

  int get vinculados => rows.where((r) => r.status == "vinculado").length;
  int get streamerNaoEncontrado => rows.where((r) => r.status == "streamer_nao_encontrado").length;
  int get agenteNaoEncontrado => rows.where((r) => r.status == "agente_nao_encontrado").length;
  int get erros => rows.where((r) => r.status == "erro").length;
}

const _colId = 0;
const _colNomeCriador = 1;
const _colNomeAgente = 2;
const _colEmailAgente = 3;
const _colDataRelacionamento = 24;

class AgentLinkImportRepository {
  final _client = Supabase.instance.client;

  DateTime? _parseFlexibleDate(String value) {
    final v = value.trim();
    if (v.isEmpty || v == "-") return null;

    final isoMatch = RegExp(r"(\d{4})-(\d{2})-(\d{2})").firstMatch(v);
    if (isoMatch != null) {
      return DateTime.utc(int.parse(isoMatch.group(1)!), int.parse(isoMatch.group(2)!), int.parse(isoMatch.group(3)!));
    }
    final brMatch = RegExp(r"(\d{1,2})/(\d{1,2})/(\d{4})").firstMatch(v);
    if (brMatch != null) {
      return DateTime.utc(int.parse(brMatch.group(3)!), int.parse(brMatch.group(2)!), int.parse(brMatch.group(1)!));
    }
    return null;
  }

  Future<AgentLinkImportSummary> processFile(List<int> bytes) async {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables.values.first;
    final rowsData = sheet.rows;

    if (rowsData.length < 2) {
      return AgentLinkImportSummary([], rowsData.length);
    }

    final results = <AgentLinkRowResult>[];

    for (var i = 1; i < rowsData.length; i++) {
      final row = rowsData[i];
      String cell(int idx) {
        if (idx < 0 || idx >= row.length) return "";
        final value = row[idx]?.value;
        if (value == null) return "";
        final typeName = value.runtimeType.toString();
        try {
          if (typeName == "IntCellValue") {
            return (value as dynamic).value.toString();
          }
          if (typeName == "DoubleCellValue") {
            final d = (value as dynamic).value as double;
            return d.toStringAsFixed(0);
          }
        } catch (_) {}
        return value.toString().trim();
      }

      final tiktokId = cell(_colId).trim().replaceAll(RegExp(r"[^0-9]"), "");
      final nomeCriador = cell(_colNomeCriador).trim();
      final agentEmail = cell(_colEmailAgente).trim();
      final dataRelacionamento = cell(_colDataRelacionamento).trim();

      if (tiktokId.isEmpty) continue;

      try {
        final profile = await _client.from("profiles").select("id, joined_at").eq("tiktok_creator_id", tiktokId).maybeSingle();
        if (profile == null) {
          results.add(AgentLinkRowResult(tiktokId: tiktokId, nome: nomeCriador, agentEmail: agentEmail, status: "streamer_nao_encontrado"));
          continue;
        }

        if (agentEmail.isEmpty) {
          results.add(AgentLinkRowResult(tiktokId: tiktokId, nome: nomeCriador, agentEmail: agentEmail, status: "agente_nao_encontrado", detail: "E-mail do agente vazio na planilha"));
          continue;
        }

        final manager = await _client.from("managers").select("id").ilike("login_email", agentEmail).maybeSingle();

        // O e-mail do agente e sempre gravado (mesmo sem conta cadastrada) para que ele
        // conte nas metricas e no ranking por e-mail, mesmo sem login no sistema.
        final updateData = <String, dynamic>{
          "tiktok_agent_email": agentEmail,
        };
        if (manager != null) {
          updateData["recruited_by_manager_id"] = manager["id"];
        }

        final parsedDate = _parseFlexibleDate(dataRelacionamento);
        if (parsedDate != null) {
          updateData["agent_relationship_date"] = parsedDate.toIso8601String();
          if (profile["joined_at"] == null) updateData["joined_at"] = parsedDate.toIso8601String();
        }

        await _client.from("profiles").update(updateData).eq("id", profile["id"]);

        if (manager == null) {
          results.add(AgentLinkRowResult(tiktokId: tiktokId, nome: nomeCriador, agentEmail: agentEmail, status: "agente_nao_encontrado", detail: "Sem conta de gestor cadastrada, mas e-mail contabilizado nas metricas"));
          continue;
        }

        results.add(AgentLinkRowResult(tiktokId: tiktokId, nome: nomeCriador, agentEmail: agentEmail, status: "vinculado"));
      } catch (e) {
        results.add(AgentLinkRowResult(tiktokId: tiktokId, nome: nomeCriador, agentEmail: agentEmail, status: "erro", detail: e.toString()));
      }
    }

    return AgentLinkImportSummary(results, rowsData.length);
  }
}





