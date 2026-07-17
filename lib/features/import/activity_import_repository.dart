import "package:excel/excel.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class ActivityImportSummary {
  final int totalRowsRead;
  final int applied;
  final int notFound;
  ActivityImportSummary({required this.totalRowsRead, required this.applied, required this.notFound});
}

class ActivityImportRepository {
  final _client = Supabase.instance.client;

  Future<String> _needsAgencyId() async {
    final managerId = _client.auth.currentUser!.id;
    final manager = await _client.from("managers").select("agency_id").eq("id", managerId).single();
    return manager["agency_id"] as String;
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
      final firstCell = rowsData[i].isNotEmpty ? (rowsData[i][0]?.value?.toString() ?? "") : "";
      if (firstCell.startsWith("ID do criador")) {
        headerIndex = i;
        break;
      }
    }
    if (headerIndex == -1) {
      return ActivityImportSummary(totalRowsRead: 0, applied: 0, notFound: 0);
    }

    const colId = 0;
    const colUltimaLive = 14;

    var applied = 0;
    var notFound = 0;
    var total = 0;

    for (var i = headerIndex + 1; i < rowsData.length; i++) {
      final row = rowsData[i];
      String cell(int idx) => idx >= 0 && idx < row.length ? (row[idx]?.value?.toString() ?? "") : "";

      final tiktokId = cell(colId).trim();
      if (tiktokId.isEmpty) continue;
      total++;

      final lastLiveText = cell(colUltimaLive).trim();
      final lastLive = _parseLastLive(lastLiveText);
      if (lastLive == null) continue;

      final profile = await _client
          .from("profiles")
          .select("id")
          .eq("tiktok_creator_id", tiktokId)
          .maybeSingle();

      if (profile == null) {
        notFound++;
        continue;
      }

      await _client.from("profiles").update({
        "last_live_at": lastLive.toIso8601String(),
      }).eq("id", profile["id"]);
      applied++;
    }

    return ActivityImportSummary(totalRowsRead: total, applied: applied, notFound: notFound);
  }
}

