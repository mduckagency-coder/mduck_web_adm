import "package:excel/excel.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class ActivityImportSummary {
  final int totalRowsRead;
  final int applied;
  final int notFound;
  final int agentsLinked;
  final int agentsNotFound;
  ActivityImportSummary({
    required this.totalRowsRead,
    required this.applied,
    required this.notFound,
    this.agentsLinked = 0,
    this.agentsNotFound = 0,
  });
}

class ActivityImportRepository {
  final _client = Supabase.instance.client;

  Future<String> _needsAgencyId() async {
    final managerId = _client.auth.currentUser!.id;
    final manager = await _client.from("managers").select("agency_id").eq("id", managerId).single();
    return manager["agency_id"] as String;
  }

  String _cellText(dynamic value) {
    if (value == null) return "";
    final typeName = value.runtimeType.toString();
    try {
      if (typeName == "IntCellValue") return (value as dynamic).value.toString();
      if (typeName == "DoubleCellValue") return ((value as dynamic).value as double).toStringAsFixed(0);
    } catch (_) {}
    return value.toString().trim();
  }

  DateTime? _parseLastLive(String value) {
    // formato: "2026:07:14 23:18:07 (UTC+0)"
    final match = RegExp(r"(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})").firstMatch(value);
    if (match == null) return null;
    return DateTime.utc(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  }

  DateTime? _parseFlexibleDate(String value) {
    final v = value.trim();
    if (v.isEmpty || v == "-") return null;
    final colonMatch = RegExp(r"(\d{4}):(\d{2}):(\d{2})").firstMatch(v);
    if (colonMatch != null) {
      return DateTime.utc(int.parse(colonMatch.group(1)!), int.parse(colonMatch.group(2)!), int.parse(colonMatch.group(3)!));
    }
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

  Future<ActivityImportSummary> processFile(List<int> bytes) async {
    final agencyId = await _needsAgencyId();
    await _client.from("tiktok_imports").insert({
      "agency_id": agencyId,
      "uploaded_by": _client.auth.currentUser!.id,
      "file_url": "upload_direto",
      "status": "concluido",
      "import_type": "atividade",
      "processed_at": DateTime.now().toIso8601String(),
    });
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables.values.first;
    final rowsData = sheet.rows;

    // acha a linha de cabecalho (comeca com "ID do criador")
    int headerIndex = -1;
    for (var i = 0; i < rowsData.length; i++) {
      final firstCell = rowsData[i].isNotEmpty ? _cellText(rowsData[i][0]?.value) : "";
      if (firstCell.startsWith("ID do criador")) {
        headerIndex = i;
        break;
      }
    }
    if (headerIndex == -1) {
      return ActivityImportSummary(totalRowsRead: 0, applied: 0, notFound: 0);
    }

    const colId = 0;
    const colNomeCriador = 1;
    const colNomeAgente = 2;
    const colEmailAgente = 3;
    const colUltimaLive = 14;
    const colDataRelacionamento = 24;

    var applied = 0;
    var notFound = 0;
    var total = 0;
    var agentsLinked = 0;
    var agentsNotFound = 0;

    for (var i = headerIndex + 1; i < rowsData.length; i++) {
      final row = rowsData[i];
      String cell(int idx) => idx >= 0 && idx < row.length ? _cellText(row[idx]?.value) : "";

      final tiktokId = cell(colId).trim().replaceAll(RegExp(r"[^0-9]"), "");
      if (tiktokId.isEmpty) continue;
      total++;

      final profile = await _client
          .from("profiles")
          .select("id, joined_at")
          .eq("tiktok_creator_id", tiktokId)
          .maybeSingle();

      if (profile == null) {
        notFound++;
        continue;
      }

      // Ultima live
      final lastLiveText = cell(colUltimaLive).trim();
      final lastLive = _parseLastLive(lastLiveText);
      final profileUpdate = <String, dynamic>{};
      if (lastLive != null) {
        profileUpdate["last_live_at"] = lastLive.toIso8601String();
      }

      // Vinculo com agente (nome + e-mail)
      final agentEmail = cell(colEmailAgente).trim();
      if (agentEmail.isNotEmpty) {
        final manager = await _client.from("managers").select("id").ilike("login_email", agentEmail).maybeSingle();
        profileUpdate["tiktok_agent_email"] = agentEmail;
        final relDate = _parseFlexibleDate(cell(colDataRelacionamento).trim());
        if (relDate != null) {
          profileUpdate["agent_relationship_date"] = relDate.toIso8601String();
          if (profile["joined_at"] == null) profileUpdate["joined_at"] = relDate.toIso8601String();
        }
        if (manager != null) {
          profileUpdate["recruited_by_manager_id"] = manager["id"];
          agentsLinked++;
        } else {
          agentsNotFound++;
        }
      }

      if (profileUpdate.isNotEmpty) {
        await _client.from("profiles").update(profileUpdate).eq("id", profile["id"]);
      }
      if (lastLive != null) applied++;
    }

    return ActivityImportSummary(
      totalRowsRead: total,
      applied: applied,
      notFound: notFound,
      agentsLinked: agentsLinked,
      agentsNotFound: agentsNotFound,
    );
  }
}
