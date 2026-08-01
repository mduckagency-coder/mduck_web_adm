import "package:excel/excel.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class ImportRowResult {
  final String tiktokId;
  final String nick;
  final String status; // "aplicado" | "criado" | "nao_encontrado" | "erro"
  final String? detail;

  ImportRowResult({
    required this.tiktokId,
    required this.nick,
    required this.status,
    this.detail,
  });
}

class ImportSummary {
  final List<ImportRowResult> rows;
  final int totalRowsRead;
  ImportSummary(this.rows, this.totalRowsRead);

  int get applied =>
      rows.where((r) => r.status == "aplicado" || r.status == "criado").length;
  int get created => rows.where((r) => r.status == "criado").length;
  int get notFound => rows.where((r) => r.status == "nao_encontrado").length;
  int get errors => rows.where((r) => r.status == "erro").length;
}

const _colPeriodo = 0;
const _colId = 1;
const _colNick = 2;
const _colGrupo = 3;
const _colHorarioIngresso = 5;
const _colDiamantes = 7;
const _colDuracao = 8;
const _colDiasValidos = 9;
const _colDiamantesMesPassado = 12;
const _colDuracaoMesPassado = 13;
const _colDiasMesPassado = 14;
const _colStatus = 40;
const _colBatalhas = 27;

class TikTokImportRepository {
  final _client = Supabase.instance.client;

  double _parseDuration(String value) {
    if (value.trim().isEmpty || value.trim() == "-") return 0;
    final hMatch = RegExp(r"(\d+)h").firstMatch(value);
    final mMatch = RegExp(r"(\d+)m").firstMatch(value);
    final sMatch = RegExp(r"(\d+)s").firstMatch(value);
    final h = hMatch != null ? int.parse(hMatch.group(1)!) : 0;
    final m = mMatch != null ? int.parse(mMatch.group(1)!) : 0;
    final s = sMatch != null ? int.parse(sMatch.group(1)!) : 0;
    return h + (m / 60) + (s / 3600);
  }

  int _parseInt(String value) {
    final clean = value.trim().replaceAll(".", "").replaceAll(",", "");
    if (clean.isEmpty || clean == "-") return 0;
    return int.tryParse(clean) ?? 0;
  }

  DateTime? _parseJoinDate(String value) {
    final match = RegExp(
      r"(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})",
    ).firstMatch(value);
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

  (String current, String previous) _periods(String periodoTexto) {
    final firstDate = periodoTexto.split("~").first.trim();
    final year = int.parse(firstDate.substring(0, 4));
    final month = int.parse(firstDate.substring(5, 7));
    final currentKey = year.toString() + "-" + month.toString().padLeft(2, "0");
    final prevMonth = month == 1 ? 12 : month - 1;
    final prevYear = month == 1 ? year - 1 : year;
    final previousKey =
        prevYear.toString() + "-" + prevMonth.toString().padLeft(2, "0");
    return (currentKey, previousKey);
  }

  Future<ImportSummary> processFile(
    List<int> bytes, {
    required String agencyId,
  }) async {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables.values.first;
    final rowsData = sheet.rows;

    if (rowsData.length < 2) {
      return ImportSummary([], rowsData.length);
    }

    final results = <ImportRowResult>[];

    final importRecord = await _client
        .from("tiktok_imports")
        .insert({
          "agency_id": agencyId,
          "uploaded_by": _client.auth.currentUser!.id,
          "file_url": "upload_direto",
          "status": "processando",
          "import_type": "metricas",
        })
        .select()
        .single();
    final importId = importRecord["id"];

    for (var i = 1; i < rowsData.length; i++) {
      final row = rowsData[i];
      String cell(int idx) => idx >= 0 && idx < row.length
          ? (row[idx]?.value?.toString() ?? "")
          : "";

      final periodoTexto = cell(_colPeriodo).trim();
      if (periodoTexto.isEmpty) continue;

      final periods = _periods(periodoTexto);
      final previousPeriod = periods.$2;

      final tiktokId = cell(_colId).trim();
      final nick = cell(_colNick).trim();
      final statusTexto = cell(_colStatus).trim();
      final idContainsSaiu = tiktokId.toLowerCase().contains("deixou");
      final saiu = statusTexto == "Saiu" || idContainsSaiu;
      final isNumericId = RegExp(r"^\d+$").hasMatch(tiktokId);

      try {
        Map<String, dynamic>? profile;
        if (isNumericId) {
          profile = await _client
              .from("profiles")
              .select("id")
              .eq("tiktok_creator_id", tiktokId)
              .maybeSingle();
        }
        profile ??= await _client
            .from("profiles")
            .select("id")
            .eq("tiktok_username", nick)
            .maybeSingle();
        // Streamers cadastrados manualmente (dialog "Novo Agenciado") tem o @
        // digitado a mao guardado em tiktok_creator_id (campo pensado pro ID
        // numerico do TikTok, nao pro @) -- sem esse fallback, a planilha
        // nunca encontra esse cadastro e acaba criando um duplicado com o ID
        // numerico certo, deixando o original parado em zero pra sempre.
        if (nick.isNotEmpty) {
          profile ??= await _client
              .from("profiles")
              .select("id")
              .eq("tiktok_creator_id", nick)
              .maybeSingle();
        }

        var wasCreated = false;

        if (profile == null) {
          if (!isNumericId) {
            // sem ID valido e sem cadastro previo: nao da pra criar com seguranca
            results.add(
              ImportRowResult(
                tiktokId: tiktokId,
                nick: nick,
                status: "nao_encontrado",
              ),
            );
            await _client.from("tiktok_import_rows").insert({
              "import_id": importId,
              "streamer_identifier": nick,
              "raw_data": {"tiktok_id": tiktokId},
              "status": "nao_encontrado",
            });
            continue;
          }

          // cria automaticamente o cadastro do streamer a partir da planilha
          final joinDate = _parseJoinDate(cell(_colHorarioIngresso));
          final newProfile = await _client
              .from("profiles")
              .insert({
                "agency_id": agencyId,
                "display_name": nick,
                "tiktok_username": nick,
                "tiktok_creator_id": tiktokId,
                "tiktok_group_name": cell(_colGrupo).trim(),
                if (joinDate != null) "joined_at": joinDate.toIso8601String(),
              })
              .select()
              .single();
          profile = newProfile;
          wasCreated = true;
        }

        final streamerId = profile["id"];

        if (saiu) {
          await _client
              .from("profiles")
              .update({"is_active": false})
              .eq("id", streamerId);
        } else {
          final joinDateUpdate = _parseJoinDate(cell(_colHorarioIngresso));
          final profileUpdate = <String, dynamic>{};
          if (isNumericId && !wasCreated)
            profileUpdate["tiktok_creator_id"] = tiktokId;
          if (joinDateUpdate != null)
            profileUpdate["joined_at"] = joinDateUpdate.toIso8601String();
          profileUpdate["tiktok_group_name"] = cell(_colGrupo).trim();
          if (profileUpdate.isNotEmpty) {
            await _client
                .from("profiles")
                .update(profileUpdate)
                .eq("id", streamerId);
          }

          final diamonds = _parseInt(cell(_colDiamantes));
          final hours = _parseDuration(cell(_colDuracao));
          final days = _parseInt(cell(_colDiasValidos));

          await _client.from("streamer_stats").upsert({
            "streamer_id": streamerId,
            "days_live": days,
            "hours_live": hours,
            "diamonds": diamonds,
            "battles": _parseInt(cell(_colBatalhas)),
            "updated_at": DateTime.now().toIso8601String(),
          });

          final prevDiamonds = _parseInt(cell(_colDiamantesMesPassado));
          final prevHours = _parseDuration(cell(_colDuracaoMesPassado));
          final prevDays = _parseInt(cell(_colDiasMesPassado));

          await _client.from("monthly_stats").upsert({
            "streamer_id": streamerId,
            "period_key": previousPeriod,
            "diamonds": prevDiamonds,
            "hours_live": prevHours,
            "days_live": prevDays,
            "closed_at": DateTime.now().toIso8601String(),
            "source_import_id": importId,
          }, onConflict: "streamer_id,period_key");
        }

        results.add(
          ImportRowResult(
            tiktokId: tiktokId,
            nick: nick,
            status: wasCreated ? "criado" : "aplicado",
          ),
        );
        await _client.from("tiktok_import_rows").insert({
          "import_id": importId,
          "streamer_identifier": nick,
          "raw_data": {"tiktok_id": tiktokId},
          "matched_streamer_id": streamerId,
          "status": "aplicado",
        });
      } catch (e) {
        results.add(
          ImportRowResult(
            tiktokId: tiktokId,
            nick: nick,
            status: "erro",
            detail: e.toString(),
          ),
        );
      }
    }

    await _client
        .from("tiktok_imports")
        .update({
          "status": "concluido",
          "rows_processed": results.length,
          "processed_at": DateTime.now().toIso8601String(),
        })
        .eq("id", importId);

    return ImportSummary(results, rowsData.length);
  }
}
