import "package:excel/excel.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class ImportRowResult {
  final String tiktokId;
  final String nick;
  final String status; // "aplicado" | "criado" | "nao_encontrado" | "erro" | "desativado"
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
  int get deactivated => rows.where((r) => r.status == "desativado").length;
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

  /// Ultima data do periodo da planilha ("2026-10-01 ~ 2026-10-02" -> 02/10).
  /// Com uma data so, usa ela.
  DateTime? _dataUntil(String periodoTexto) {
    final dates = RegExp(r"(\d{4})[-/.](\d{2})[-/.](\d{2})").allMatches(periodoTexto).toList();
    if (dates.isEmpty) return null;
    final m = dates.last;
    return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  }

  String _isoDate(DateTime d) =>
      "${d.year.toString().padLeft(4, "0")}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}";

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
    // Perfis que vieram na planilha (inclusive os "Saiu") e o mes dela.
    final seenIds = <String>{};
    String? sheetPeriod;

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
      final currentPeriod = periods.$1;
      sheetPeriod ??= currentPeriod;
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
              .select("id, tiktok_username, display_name")
              .eq("tiktok_creator_id", tiktokId)
              .maybeSingle();
        }
        profile ??= await _client
            .from("profiles")
            .select("id, tiktok_username, display_name, tiktok_creator_id")
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
              .select("id, tiktok_username, display_name, tiktok_creator_id")
              .eq("tiktok_creator_id", nick)
              .maybeSingle();
        }
        // Achou pelo nick, mas esse cadastro ja pertence a OUTRO ID do TikTok:
        // e outra pessoa usando um nick que alguem largou. Nao mistura.
        final linkedId = (profile?["tiktok_creator_id"] ?? "").toString().trim();
        if (profile != null && isNumericId && RegExp(r"^\d+$").hasMatch(linkedId) && linkedId != tiktokId) {
          profile = null;
        }
        // Linha sem ID valido (ex.: "deixou a agencia") com um @ antigo:
        // procura no historico de trocas de nick (migration 0093).
        if (profile == null && !isNumericId && nick.isNotEmpty) {
          try {
            final hist = await _client
                .from("tiktok_nick_history")
                .select("streamer_id")
                // "_" e "%" sao curingas no ilike (e "_" e comum em nick)
                .ilike("old_nick", nick.replaceAll(r"\", r"\\").replaceAll("%", r"\%").replaceAll("_", r"\_"))
                .order("changed_at", ascending: false)
                .limit(1);
            if ((hist as List).isNotEmpty) {
              profile = {"id": hist.first["streamer_id"]};
            }
          } catch (_) {}
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
        seenIds.add(streamerId as String);

        if (saiu) {
          await _client
              .from("profiles")
              .update({
                "is_active": false,
                "left_at": DateTime.now().toIso8601String(),
                "left_reason": "Saiu da agência (planilha do TikTok)",
              })
              .eq("id", streamerId)
              .eq("is_active", true);
        } else {
          final joinDateUpdate = _parseJoinDate(cell(_colHorarioIngresso));
          final profileUpdate = <String, dynamic>{};
          if (isNumericId && !wasCreated)
            profileUpdate["tiktok_creator_id"] = tiktokId;
          if (joinDateUpdate != null)
            profileUpdate["joined_at"] = joinDateUpdate.toIso8601String();
          profileUpdate["tiktok_group_name"] = cell(_colGrupo).trim();
          // Troca de nick: o ID do TikTok nunca muda, o @ sim. Achou pelo ID
          // e o nick da planilha e outro -> atualiza o cadastro (o historico
          // fica em tiktok_nick_history, via trigger da migration 0093). O
          // nome de exibicao acompanha so se era o proprio nick antigo.
          final oldNick = (profile["tiktok_username"] as String?)?.trim();
          if (isNumericId && !wasCreated && nick.isNotEmpty && oldNick != null && oldNick != nick) {
            profileUpdate["tiktok_username"] = nick;
            final oldDisplay = (profile["display_name"] as String?)?.trim();
            if (oldDisplay == null || oldDisplay.isEmpty || oldDisplay == oldNick) {
              profileUpdate["display_name"] = nick;
            }
          } else if (isNumericId && !wasCreated && nick.isNotEmpty && (oldNick == null || oldNick.isEmpty)) {
            profileUpdate["tiktok_username"] = nick;
          }
          // Planilha confirmou esse cadastro (criado agora ou ja existente,
          // manual ou nao) -- a partir daqui conta como agenciamento oficial
          // nos dashboards de "novos agenciados".
          profileUpdate["created_manually"] = false;
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
            "period_key": currentPeriod,
            "updated_at": DateTime.now().toIso8601String(),
          });

          final prevDiamonds = _parseInt(cell(_colDiamantesMesPassado));
          final prevHours = _parseDuration(cell(_colDuracaoMesPassado));
          final prevDays = _parseInt(cell(_colDiasMesPassado));

          // Foto dos totais "ate o dia X" (fim do periodo da planilha), para o
          // ranking poder contar a partir de um dia no mes (migracao 0105).
          // Falha aqui nunca atrapalha a importacao.
          final until = _dataUntil(periodoTexto);
          if (until != null) {
            try {
              await _client.from("metric_snapshots").upsert({
                "agency_id": agencyId,
                "streamer_id": streamerId,
                "period_key": currentPeriod,
                "data_until": _isoDate(until),
                "diamonds": diamonds,
                "hours_live": hours,
                "days_live": days,
                "battles": _parseInt(cell(_colBatalhas)),
              }, onConflict: "streamer_id,period_key,data_until");
              // mes passado completo (colunas "mes passado" da planilha)
              final prevEnd = DateTime(until.year, until.month, 0);
              await _client.from("metric_snapshots").upsert({
                "agency_id": agencyId,
                "streamer_id": streamerId,
                "period_key": previousPeriod,
                "data_until": _isoDate(prevEnd),
                "diamonds": prevDiamonds,
                "hours_live": prevHours,
                "days_live": prevDays,
              }, onConflict: "streamer_id,period_key,data_until");
            } catch (_) {}
          }

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

    results.addAll(await _deactivateMissing(agencyId: agencyId, seenIds: seenIds, sheetPeriod: sheetPeriod));

    // Quem nao veio na planilha do mes novo nao pode ficar com os numeros do
    // mes passado como se fossem deste mes (migration 0092).
    try {
      await _client.rpc("virar_mes_streamer_stats");
    } catch (_) {}

    return ImportSummary(results, rowsData.length);
  }

  /// Saida automatica: a planilha do TikTok lista todo mundo que esta na
  /// agencia. Quem estava ativo aqui e NAO veio na planilha do mes atual saiu
  /// da agencia -> fica inativo (some do app/rankings), igual ao "Encerrar
  /// participacao" manual do CRM.
  ///
  /// Travas de seguranca:
  ///   * so vale para planilha do mes atual (planilha antiga nao tira ninguem);
  ///   * so se a planilha cobrir pelo menos metade dos ativos (planilha
  ///     cortada/filtrada nao derruba todo mundo);
  ///   * cadastros manuais que a planilha nunca confirmou (created_manually,
  ///     ex.: agenciado novo ainda entrando) nao sao tocados.
  Future<List<ImportRowResult>> _deactivateMissing({
    required String agencyId,
    required Set<String> seenIds,
    required String? sheetPeriod,
  }) async {
    try {
      final now = DateTime.now();
      final currentKey = "${now.year}-${now.month.toString().padLeft(2, "0")}";
      if (sheetPeriod != currentKey || seenIds.isEmpty) return [];

      final rows = await _client
          .from("profiles")
          .select("id, display_name, tiktok_username, tiktok_creator_id, created_manually")
          .eq("agency_id", agencyId)
          .eq("is_active", true);
      final active = [
        for (final r in rows as List)
          if (r["created_manually"] != true) r as Map<String, dynamic>,
      ];
      if (active.isEmpty) return [];

      final covered = active.where((r) => seenIds.contains(r["id"])).length;
      if (covered < active.length / 2) return [];

      final missing = active.where((r) => !seenIds.contains(r["id"])).toList();
      final results = <ImportRowResult>[];
      for (final r in missing) {
        await _client
            .from("profiles")
            .update({
              "is_active": false,
              "left_at": now.toIso8601String(),
              "left_reason": "Saiu da agência (não veio na planilha do TikTok de $sheetPeriod)",
            })
            .eq("id", r["id"])
            .eq("is_active", true);
        results.add(ImportRowResult(
          tiktokId: (r["tiktok_creator_id"] ?? "").toString(),
          nick: (r["tiktok_username"] ?? r["display_name"] ?? "").toString(),
          status: "desativado",
          detail: "Não veio na planilha: marcado como saiu da agência. Para desfazer, use o CRM.",
        ));
      }
      return results;
    } catch (_) {
      return [];
    }
  }
}
