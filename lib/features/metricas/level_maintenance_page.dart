import "package:flutter/material.dart";
import "package:fl_chart/fl_chart.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "streamer_detail_panel.dart";

const levelThresholds = [0, 40000, 80000, 150000, 250000, 350000, 500000, 800000, 1200000, 1600000];
const levelActivityDays = [8, 14, 17, 20, 22, 22, 22, 22, 22, 22];
const levelActivityHours = [25, 40, 60, 80, 100, 100, 100, 100, 100, 100];

int levelForDiamonds(num diamonds) {
  var level = 1;
  for (var i = 0; i < levelThresholds.length; i++) {
    if (diamonds >= levelThresholds[i]) level = i + 1;
  }
  return level;
}

class LevelMaintenancePage extends StatefulWidget {
  const LevelMaintenancePage({super.key});

  @override
  State<LevelMaintenancePage> createState() => _LevelMaintenancePageState();
}

class _LevelMaintenancePageState extends State<LevelMaintenancePage> {
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _agencyGoal;
  bool _loading = true;
  String? _error;
  String _tab = "prioridade";

  String? _filterPriority;
  String? _filterStatus;
  int? _filterNextTier;
  String? _filterProbability;
  String? _filterDiamondsGap;
  String? _filterDaysGap;
  String? _filterHoursGap;
  String _filterResponsavelType = "grupo";
  String? _filterResponsavelValue;
  String _sortBy = "prioridade_desc";

  int? _pmNextTier;
  String? _pmProbability;
  String _pmSortBy = "proximo";
  bool _pmSortAscending = true;
  bool _pmFirstTimeOnly = false;
  bool _pmDiasHorasPending = false;
  String _pmSearch = "";
  String? _pmPriority;
  String? _pmManutencaoFilter;
  bool _pmSubidaOnly = false;
  String _dhSearch = "";
  int? _dhDayMilestone;
  int? _dhHourMilestone;
  String _dhSortBy = "proximo";
  bool _dhSortAscending = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;
      final manager = await client.from("managers").select("agency_id").eq("id", userId).single();
      final agencyId = manager["agency_id"];

      var goal = await client.from("agency_level_goals").select().eq("agency_id", agencyId).maybeSingle();
      goal ??= await client.from("agency_level_goals").insert({"agency_id": agencyId}).select().single();

      final profiles = await client
          .from("profiles")
          .select("id, display_name, avatar_url, is_active, recruited_by_manager_id, tiktok_group_name, tiktok_agent_email, managers!profiles_assigned_manager_id_fkey(login_email)")
          .eq("is_active", true);
      final profilesList = (profiles as List).cast<Map<String, dynamic>>();
      final profileIds = profilesList.map((p) => p["id"] as String).toList();

      if (profileIds.isEmpty) {
        setState(() {
          _items = [];
          _agencyGoal = goal;
          _loading = false;
        });
        return;
      }

      final currentStats = await client.from("streamer_stats").select().inFilter("streamer_id", profileIds);
      final currentStatsMap = {for (final s in (currentStats as List)) s["streamer_id"] as String: s};

      final history = await client
          .from("monthly_stats")
          .select("streamer_id, period_key, diamonds, days_live, hours_live, closed_at")
          .inFilter("streamer_id", profileIds)
          .order("period_key", ascending: false);
      final historyList = (history as List).cast<Map<String, dynamic>>();
      final historyByStreamer = <String, List<Map<String, dynamic>>>{};
      for (final h in historyList) {
        historyByStreamer.putIfAbsent(h["streamer_id"] as String, () => []).add(h);
      }

      final now = DateTime.now();
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final daysRemaining = daysInMonth - now.day;

      final items = <Map<String, dynamic>>[];
      for (final p in profilesList) {
        final id = p["id"] as String;
        final streamerHistory = historyByStreamer[id] ?? [];
        final lastClosed = streamerHistory.isNotEmpty ? streamerHistory.first : null;
        final previousDiamonds = (lastClosed?["diamonds"] as num?) ?? 0;
        final previousLevel = levelForDiamonds(previousDiamonds);

        var bestEverLevel = previousLevel;
        for (final h in streamerHistory) {
          final lv = levelForDiamonds((h["diamonds"] as num?) ?? 0);
          if (lv > bestEverLevel) bestEverLevel = lv;
        }

        final current = currentStatsMap[id];
        final currentDiamonds = (current?["diamonds"] as num?) ?? 0;
        final currentDays = (current?["days_live"] as num?) ?? 0;
        final currentHours = (current?["hours_live"] as num?) ?? 0;

        // Requisitos para MANTER o tier conquistado no mes anterior (status independente)
        final requiredThreshold = levelThresholds[previousLevel - 1];
        final requiredDays = levelActivityDays[previousLevel - 1];
        final requiredHours = levelActivityHours[previousLevel - 1];
        final meetsMaintDiamonds = currentDiamonds >= requiredThreshold;
        final meetsMaintActivity = currentDays >= requiredDays && currentHours >= requiredHours;
        final maintained = meetsMaintDiamonds && meetsMaintActivity;

        // Proximo objetivo: SEMPRE baseado no tier do MES ATUAL (nunca no mes passado).
        final currentLevelNow = levelForDiamonds(currentDiamonds);
        final currentTierThreshold = levelThresholds[currentLevelNow - 1];
        final atMaxLevel = currentLevelNow >= 10;
        final nextLevel = atMaxLevel ? null : currentLevelNow + 1;
        final nextThreshold = nextLevel != null ? levelThresholds[nextLevel - 1] : null;
        final nextReqDays = nextLevel != null ? levelActivityDays[nextLevel - 1] : null;
        final nextReqHours = nextLevel != null ? levelActivityHours[nextLevel - 1] : null;

        final upgradeCount = (currentLevelNow - previousLevel).clamp(0, 10);
        final wouldBeFirstTimeAtNext = nextLevel != null && nextLevel > bestEverLevel;
        final showManutencao = previousLevel >= 2 && currentLevelNow == previousLevel;
        final subidaCount = (previousLevel >= 2 && currentLevelNow > previousLevel) ? (currentLevelNow - previousLevel) : 0;
        final maintProximityFraction = requiredThreshold == 0 ? 1.0 : (currentDiamonds / requiredThreshold).clamp(0.0, 2.0);

        // Proximo marco de dias/horas, seguindo a sequencia fixa ate 22 dias / 100 horas
        final dayMilestones = levelActivityDays.take(5).toList();
        final hourMilestones = levelActivityHours.take(5).toList();
        final nextDayMilestone = dayMilestones.firstWhere((d) => d > currentDays, orElse: () => dayMilestones.last);
        final nextHourMilestone = hourMilestones.firstWhere((h) => h > currentHours, orElse: () => hourMilestones.last);
        final dayGapToMilestone = (nextDayMilestone - currentDays).clamp(0, nextDayMilestone).toDouble();
        final hourGapToMilestone = (nextHourMilestone - currentHours).clamp(0, nextHourMilestone).toDouble();
        final allDaysDone = currentDays >= dayMilestones.last;
        final allHoursDone = currentHours >= hourMilestones.last;

        final diamondGapNext = nextThreshold != null ? (nextThreshold - currentDiamonds).clamp(0, nextThreshold).toDouble() : 0.0;
        final dayGapNext = nextReqDays != null ? (nextReqDays - currentDays).clamp(0, nextReqDays).toDouble() : 0.0;
        final hourGapNext = nextReqHours != null ? (nextReqHours - currentHours).clamp(0, nextReqHours).toDouble() : 0.0;

        final canUpgradeDiamonds = nextThreshold != null && currentDiamonds >= nextThreshold;
        final canUpgradeActivity = nextReqDays != null && currentDays >= nextReqDays && currentHours >= (nextReqHours ?? 0);
        final upgraded = canUpgradeDiamonds && canUpgradeActivity;

        final isRecovering = bestEverLevel > previousLevel;

        final firstTimeAtLevel = streamerHistory.length < 2 || levelForDiamonds((streamerHistory[1]["diamonds"] as num?) ?? 0) < previousLevel;

        String historicoEmoji;
        String historicoLabel;
        if (!maintained) {
          historicoEmoji = "\u26a0\ufe0f";
          historicoLabel = "Perdeu a manutencao";
        } else if (isRecovering) {
          historicoEmoji = "\ud83d\udd04";
          historicoLabel = "Tentando recuperar o nivel";
        } else if (firstTimeAtLevel) {
          historicoEmoji = "\ud83d\ude80";
          historicoLabel = "Alcancando este nivel pela primeira vez";
        } else {
          historicoEmoji = "\u2705";
          historicoLabel = "Manteve o nivel conquistado";
        }

        // Probabilidade de atingir o proximo tier, baseada no percentual que falta
        final percentRemaining = nextThreshold != null && nextThreshold > 0 ? (diamondGapNext / nextThreshold) : 0.0;

        String proximityEmoji;
        String proximityLabel;
        if (atMaxLevel || percentRemaining <= 0.10) {
          proximityEmoji = "\ud83d\udfe2";
          proximityLabel = "Muito proximo";
        } else if (percentRemaining <= 0.25) {
          proximityEmoji = "\ud83d\udfe1";
          proximityLabel = "Proximo";
        } else if (percentRemaining <= 0.45) {
          proximityEmoji = "\ud83d\udfe0";
          proximityLabel = "Atencao";
        } else {
          proximityEmoji = "\ud83d\udd34";
          proximityLabel = "Distante";
        }

        final dayFractionNext = (nextReqDays != null && nextReqDays > 0) ? (currentDays / nextReqDays).clamp(0.0, 1.0) : 1.0;
        final hourFractionNext = (nextReqHours != null && nextReqHours > 0) ? (currentHours / nextReqHours).clamp(0.0, 1.0) : 1.0;
        final activityGapScore = (1 - dayFractionNext) + (1 - hourFractionNext);
        String probability;
        if (atMaxLevel || canUpgradeDiamonds) {
          probability = "Alta";
        } else if (percentRemaining <= 0.20) {
          probability = "Alta";
        } else if (percentRemaining <= 0.35) {
          probability = "Media";
        } else {
          probability = "Baixa";
        }

        final score = 1000.0 - (diamondGapNext / 500.0) - (dayGapNext * 15.0) - (hourGapNext * 6.0) + (maintained ? 50.0 : 0.0);

        String recommendation;
        if (atMaxLevel) {
          recommendation = "Ja atingiu o Tier maximo (10). Foco total em manter " + requiredThreshold.toString() + " diamantes.";
        } else if (upgraded) {
          recommendation = "Ja garantiu upgrade para o Tier " + nextLevel.toString() + " este mes.";
        } else if (isRecovering && !maintained) {
          recommendation = "Perdeu a manutencao do Tier " + bestEverLevel.toString() + ". Recomenda-se iniciar recuperacao para o proximo ciclo.";
        } else if (!maintained) {
          recommendation = "Ainda nao garantiu a manutencao do Tier " + previousLevel.toString() + " deste mes. Priorizar isso antes de mirar o Tier " + (nextLevel?.toString() ?? "-") + ".";
        } else if (diamondGapNext <= 15000) {
          recommendation = "Manutencao garantida. Faltam apenas " + diamondGapNext.toStringAsFixed(0) + " diamantes para o Tier " + (nextLevel?.toString() ?? "-") + ".";
        } else {
          recommendation = "Manutencao do Tier " + previousLevel.toString() + " garantida. Faltam " + diamondGapNext.toStringAsFixed(0) + " diamantes para o Tier " + (nextLevel?.toString() ?? "-") + " (probabilidade " + probability + ").";
        }

        final managerData = p["managers"];

        items.add({
          "id": id,
          "display_name": p["display_name"],
          "avatar_url": p["avatar_url"],
          "manager_email": managerData is Map ? managerData["login_email"] : null,
          "recruited_by_manager_id": p["recruited_by_manager_id"],
          "previousLevel": previousLevel,
          "bestEverLevel": bestEverLevel,
          "nextLevel": nextLevel,
          "atMaxLevel": atMaxLevel,
          "currentDiamonds": currentDiamonds,
          "currentDays": currentDays,
          "currentHours": currentHours,
          "requiredThreshold": requiredThreshold,
          "requiredDays": requiredDays,
          "requiredHours": requiredHours,
          "nextThreshold": nextThreshold,
          "nextReqDays": nextReqDays,
          "nextReqHours": nextReqHours,
          "meetsMaintDiamonds": meetsMaintDiamonds,
          "meetsMaintActivity": meetsMaintActivity,
          "maintained": maintained,
          "canUpgradeDiamonds": canUpgradeDiamonds,
          "upgraded": upgraded,
          "isRecovering": isRecovering,
          "effDiamondGap": diamondGapNext,
          "effDayGap": dayGapNext,
          "effHourGap": hourGapNext,
          "probability": probability,
          "score": score,
          "recommendation": recommendation,
          "firstTimeAtLevel": firstTimeAtLevel,
          "historicoEmoji": historicoEmoji,
          "historicoLabel": historicoLabel,
          "percentRemaining": percentRemaining,
          "proximityEmoji": proximityEmoji,
          "proximityLabel": proximityLabel,
          "activityGapScore": activityGapScore,
          "previousDiamonds": previousDiamonds,
          "dayFractionNext": dayFractionNext,
          "hourFractionNext": hourFractionNext,
          "groupName": p["tiktok_group_name"],
          "agentEmail": p["tiktok_agent_email"],
          "financialImpact": (nextThreshold ?? requiredThreshold) - requiredThreshold,
          "currentLevelNow": currentLevelNow,
          "currentTierThreshold": currentTierThreshold,
          "showManutencao": showManutencao,
          "subidaCount": subidaCount,
          "maintProximityFraction": maintProximityFraction,
          "nextDayMilestone": nextDayMilestone,
          "nextHourMilestone": nextHourMilestone,
          "dayGapToMilestone": dayGapToMilestone,
          "hourGapToMilestone": hourGapToMilestone,
          "allDaysDone": allDaysDone,
          "allHoursDone": allHoursDone,
          "upgradeCount": upgradeCount,
          "wouldBeFirstTimeAtNext": wouldBeFirstTimeAtNext,
        });
      }

      items.sort((a, b) => (b["score"] as double).compareTo(a["score"] as double));

      setState(() {
        _items = items;
        _agencyGoal = goal;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openDetail(Map<String, dynamic> item) {
    showDialog(context: context, builder: (context) => StreamerDetailPanel(item: item));
  }

  List<Map<String, dynamic>> get _filteredItems {
    var list = List<Map<String, dynamic>>.from(_items);

    if (_filterPriority != null) {
      list = list.where((i) => _priority(i["score"] as double).$1 == _filterPriority).toList();
    }
    if (_filterStatus != null) {
      switch (_filterStatus) {
        case "maintaining":
          list = list.where((i) => i["maintained"] == true).toList();
          break;
        case "upgrading":
          list = list.where((i) => i["canUpgradeDiamonds"] == true).toList();
          break;
        case "first_time":
          list = list.where((i) => i["firstTimeAtLevel"] == true).toList();
          break;
        case "recovering":
          list = list.where((i) => i["isRecovering"] == true).toList();
          break;
        case "at_risk":
          list = list.where((i) => i["maintained"] != true).toList();
          break;
      }
    }
    if (_filterNextTier != null) {
      list = list.where((i) => i["nextThreshold"] == _filterNextTier).toList();
    }
    if (_filterProbability != null) {
      list = list.where((i) => i["probability"] == _filterProbability).toList();
    }
    if (_filterDiamondsGap != null) {
      list = list.where((i) {
        final gap = i["effDiamondGap"] as double;
        switch (_filterDiamondsGap) {
          case "5000":
            return gap <= 5000;
          case "10000":
            return gap <= 10000;
          case "20000":
            return gap <= 20000;
          case "50000":
            return gap <= 50000;
          case "above50000":
            return gap > 50000;
        }
        return true;
      }).toList();
    }
    if (_filterDaysGap != null) {
      list = list.where((i) {
        final gap = i["effDayGap"] as double;
        switch (_filterDaysGap) {
          case "0":
            return gap <= 0;
          case "1":
            return gap == 1;
          case "2":
            return gap == 2;
          case "3+":
            return gap >= 3;
        }
        return true;
      }).toList();
    }
    if (_filterHoursGap != null) {
      list = list.where((i) {
        final gap = i["effHourGap"] as double;
        switch (_filterHoursGap) {
          case "0":
            return gap <= 0;
          case "5":
            return gap <= 5;
          case "10":
            return gap <= 10;
          case "above10":
            return gap > 10;
        }
        return true;
      }).toList();
    }
    if (_filterResponsavelValue != null) {
      list = list.where((i) {
        if (_filterResponsavelType == "grupo") return i["groupName"] == _filterResponsavelValue;
        if (_filterResponsavelType == "agente") return i["agentEmail"] == _filterResponsavelValue;
        return i["manager_email"] == _filterResponsavelValue;
      }).toList();
    }

    switch (_sortBy) {
      case "prioridade_desc":
        list.sort((a, b) => (b["score"] as double).compareTo(a["score"] as double));
        break;
      case "prioridade_asc":
        list.sort((a, b) => (a["score"] as double).compareTo(b["score"] as double));
        break;
      case "proximo_tier":
        list.sort((a, b) => (a["percentRemaining"] as double).compareTo(b["percentRemaining"] as double));
        break;
      case "menos_diamantes":
        list.sort((a, b) => (a["effDiamondGap"] as double).compareTo(b["effDiamondGap"] as double));
        break;
      case "menos_dias":
        list.sort((a, b) => (a["effDayGap"] as double).compareTo(b["effDayGap"] as double));
        break;
      case "menos_horas":
        list.sort((a, b) => (a["effHourGap"] as double).compareTo(b["effHourGap"] as double));
        break;
      case "impacto_financeiro":
        list.sort((a, b) => (b["financialImpact"] as int).compareTo(a["financialImpact"] as int));
        break;
      case "probabilidade":
        const order = {"Alta": 0, "Media": 1, "Baixa": 2};
        list.sort((a, b) => (order[a["probability"]] ?? 3).compareTo(order[b["probability"]] ?? 3));
        break;
    }

    return list;
  }

  List<Map<String, dynamic>> get _prioridadeItems {
    var list = List<Map<String, dynamic>>.from(_items);

    if (_pmSearch.trim().isNotEmpty) {
      final q = _pmSearch.trim().toLowerCase();
      list = list.where((i) {
        final name = (i["display_name"] as String).toLowerCase();
        final id = (i["id"] as String).toLowerCase();
        return name.contains(q) || id.contains(q);
      }).toList();
    }
    if (_pmNextTier != null) {
      list = list.where((i) => i["nextThreshold"] == _pmNextTier).toList();
    }
    if (_pmProbability != null) {
      if (_pmProbability == "Muito Alta") {
        list = list.where((i) => i["probability"] == "Alta" && (i["percentRemaining"] as double) <= 0.10).toList();
      } else {
        list = list.where((i) => i["probability"] == _pmProbability).toList();
      }
    }
    if (_pmFirstTimeOnly) {
      list = list.where((i) => i["wouldBeFirstTimeAtNext"] == true).toList();
    }
    if (_pmDiasHorasPending) {
      list = list.where((i) => (i["currentDiamonds"] as num) >= ((i["nextThreshold"] as int?) ?? 0) && ((i["dayFractionNext"] as double) < 1 || (i["hourFractionNext"] as double) < 1)).toList();
    }

    int Function(Map<String, dynamic>, Map<String, dynamic>) comparator;
    switch (_pmSortBy) {
      case "diamantes":
        comparator = (a, b) => (a["effDiamondGap"] as double).compareTo(b["effDiamondGap"] as double);
        break;
      case "progresso":
        comparator = (a, b) {
          final pa = (a["currentDiamonds"] as num) / ((a["nextThreshold"] as int?) ?? 1);
          final pb = (b["currentDiamonds"] as num) / ((b["nextThreshold"] as int?) ?? 1);
          return pa.compareTo(pb);
        };
        break;
      case "impacto":
        comparator = (a, b) => (a["financialImpact"] as int).compareTo(b["financialImpact"] as int);
        break;
      case "alfabetica":
        comparator = (a, b) => (a["display_name"] as String).toLowerCase().compareTo((b["display_name"] as String).toLowerCase());
        break;
      default:
        comparator = (a, b) => (a["percentRemaining"] as double).compareTo(b["percentRemaining"] as double);
    }

    list.sort((a, b) => _pmSortAscending ? comparator(a, b) : comparator(b, a));
    return list;
  }

  List<Map<String, dynamic>> get _diasHorasItems {
    var list = List<Map<String, dynamic>>.from(_items.where((i) => i["allDaysDone"] != true || i["allHoursDone"] != true));

    if (_dhSearch.trim().isNotEmpty) {
      final q = _dhSearch.trim().toLowerCase();
      list = list.where((i) {
        final name = (i["display_name"] as String).toLowerCase();
        final id = (i["id"] as String).toLowerCase();
        return name.contains(q) || id.contains(q);
      }).toList();
    }
    if (_dhDayMilestone != null) {
      list = list.where((i) => i["nextDayMilestone"] == _dhDayMilestone).toList();
    }
    if (_dhHourMilestone != null) {
      list = list.where((i) => i["nextHourMilestone"] == _dhHourMilestone).toList();
    }

    int Function(Map<String, dynamic>, Map<String, dynamic>) comparator;
    switch (_dhSortBy) {
      case "dias":
        comparator = (a, b) => (a["dayGapToMilestone"] as double).compareTo(b["dayGapToMilestone"] as double);
        break;
      case "horas":
        comparator = (a, b) => (a["hourGapToMilestone"] as double).compareTo(b["hourGapToMilestone"] as double);
        break;
      case "alfabetica":
        comparator = (a, b) => (a["display_name"] as String).toLowerCase().compareTo((b["display_name"] as String).toLowerCase());
        break;
      default:
        comparator = (a, b) {
          final ga = (a["dayGapToMilestone"] as double) + (a["hourGapToMilestone"] as double);
          final gb = (b["dayGapToMilestone"] as double) + (b["hourGapToMilestone"] as double);
          return ga.compareTo(gb);
        };
    }
    list.sort((a, b) => _dhSortAscending ? comparator(a, b) : comparator(b, a));
    return list;
  }

  void _clearFilters() {
    setState(() {
      _filterPriority = null;
      _filterStatus = null;
      _filterNextTier = null;
      _filterProbability = null;
      _filterDiamondsGap = null;
      _filterDaysGap = null;
      _filterHoursGap = null;
      _filterResponsavelValue = null;
      _sortBy = "prioridade_desc";
    });
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withOpacity(0.18), Colors.white.withOpacity(0.03)]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.45)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold, height: 1)),
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, Color, String) _priority(double score) {
    if (score >= 700) return ("Muito Alta", Colors.redAccent, "\ud83d\udd34");
    if (score >= 400) return ("Alta", Colors.orangeAccent, "\ud83d\udfe0");
    if (score >= 100) return ("Media", Colors.amber, "\ud83d\udfe1");
    return ("Baixa", Colors.white38, "\u26aa");
  }

  Future<void> _editGoal() async {
    final countController = TextEditingController(text: _agencyGoal?["target_count"]?.toString() ?? "30");
    final diamondsController = TextEditingController(text: _agencyGoal?["target_diamonds"]?.toString() ?? "80000");
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Meta da Agencia", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: countController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Quantidade de streamers", labelStyle: TextStyle(color: Colors.white54))),
            const SizedBox(height: 8),
            TextField(controller: diamondsController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Acima de quantos diamantes", labelStyle: TextStyle(color: Colors.white54))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
            onPressed: () async {
              final client = Supabase.instance.client;
              final userId = client.auth.currentUser!.id;
              await client.from("agency_level_goals").update({
                "target_count": int.tryParse(countController.text) ?? 30,
                "target_diamonds": int.tryParse(diamondsController.text) ?? 80000,
                "updated_at": DateTime.now().toIso8601String(),
                "updated_by": userId,
              }).eq("id", _agencyGoal!["id"]);
              if (context.mounted) Navigator.of(context).pop();
              _load();
            },
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
  }

  (String, String, Color) _situacao(Map<String, dynamic> i) {
    final nextThreshold = i["nextThreshold"] as int?;
    if (i["canUpgradeDiamonds"] == true && nextThreshold != null) {
      return ("\ud83d\udfe2", "Proximo de subir para " + (nextThreshold ~/ 1000).toString() + "k", Colors.greenAccent);
    }
    if (i["maintained"] == true) {
      return ("\ud83d\udfe2", "Mantendo o nivel", Colors.greenAccent);
    }
    if (i["isRecovering"] == true) {
      return ("\ud83d\udfe0", "Precisa recuperar o nivel", Colors.orangeAccent);
    }
    if (i["meetsMaintDiamonds"] == true && i["meetsMaintActivity"] != true) {
      return ("\ud83d\udfe1", "Em evolucao (falta atividade)", Colors.amber);
    }
    final gap = i["effDiamondGap"] as double;
    final target = (i["usesUpgradeGap"] == true ? i["nextThreshold"] : i["requiredThreshold"]) as int? ?? 1;
    if (gap / target < 0.3) {
      return ("\ud83d\udfe1", "Em evolucao", Colors.amber);
    }
    return ("\ud83d\udd34", "Risco de perder manutencao", Colors.redAccent);
  }

  Widget _levelContextBar(Map<String, dynamic> i, {double height = 8}) {
    final currentTierThreshold = (i["currentTierThreshold"] as int).toDouble();
    final currentTier = i["currentLevelNow"] as int;
    final atMax = i["atMaxLevel"] == true;
    final current = (i["currentDiamonds"] as num).toDouble();

    if (atMax) {
      return Text("Tier maximo (10) ja atingido - " + currentTierThreshold.toStringAsFixed(0) + " diamantes", style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold));
    }

    final targetThreshold = (i["nextThreshold"] as int).toDouble();
    final targetTier = i["nextLevel"] as int;
    final span = (targetThreshold - currentTierThreshold).clamp(1, double.infinity);
    final fraction = ((current - currentTierThreshold) / span).clamp(0.0, 1.0);
    final probability = i["probability"] as String;
    final probColor = probability == "Alta" ? Colors.greenAccent : probability == "Media" ? Colors.amber : Colors.orangeAccent;

    return Tooltip(
      message: "Este streamer esta no Tier " + currentTier.toString() + " (" + currentTierThreshold.toStringAsFixed(0) + " diamantes) neste mes. O proximo objetivo e o Tier " + targetTier.toString() + " (" + targetThreshold.toStringAsFixed(0) + " diamantes).",
      textStyle: const TextStyle(color: Colors.white, fontSize: 11),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Tier atual: Tier " + currentTier.toString() + " (" + currentTierThreshold.toStringAsFixed(0) + ")", style: const TextStyle(color: Colors.white38, fontSize: 10)),
              Text("Proximo: Tier " + targetTier.toString() + " (" + targetThreshold.toStringAsFixed(0) + ")", style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: LinearProgressIndicator(value: fraction, minHeight: height, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation(fraction >= 1 ? Colors.greenAccent : const Color(0xFF7A0BD4))),
          ),
          const SizedBox(height: 3),
          Row(children: [
            Expanded(child: Text("Atual: " + current.toStringAsFixed(0) + " (" + (fraction * 100).toStringAsFixed(0) + "%)", style: const TextStyle(color: Colors.white54, fontSize: 10))),
            Text("Prob: " + probability, style: TextStyle(color: probColor, fontSize: 10, fontWeight: FontWeight.bold)),
          ]),
        ],
      ),
    );
  }

  Widget _filterBar() {
    final groups = _items.map((i) => i["groupName"] as String?).whereType<String>().where((g) => g.isNotEmpty).toSet().toList()..sort();
    final agents = _items.map((i) => i["agentEmail"] as String?).whereType<String>().where((a) => a.isNotEmpty).toSet().toList()..sort();
    final gestores = _items.map((i) => i["manager_email"] as String?).whereType<String>().toSet().toList()..sort();
    final responsavelOptions = _filterResponsavelType == "grupo" ? groups : _filterResponsavelType == "agente" ? agents : gestores;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(14)),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownButton<String?>(
            value: _filterPriority,
            hint: const Text("Prioridade", style: TextStyle(color: Colors.white54, fontSize: 12)),
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: const [
              DropdownMenuItem(value: null, child: Text("Prioridade: Todas")),
              DropdownMenuItem(value: "Muito Alta", child: Text("\ud83d\udd34 Muito Alta")),
              DropdownMenuItem(value: "Alta", child: Text("\ud83d\udfe0 Alta")),
              DropdownMenuItem(value: "Media", child: Text("\ud83d\udfe1 Media")),
              DropdownMenuItem(value: "Baixa", child: Text("\u26aa Baixa")),
            ],
            onChanged: (v) => setState(() => _filterPriority = v),
          ),
          DropdownButton<String?>(
            value: _filterStatus,
            hint: const Text("Status", style: TextStyle(color: Colors.white54, fontSize: 12)),
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: const [
              DropdownMenuItem(value: null, child: Text("Status: Todos")),
              DropdownMenuItem(value: "maintaining", child: Text("Mantendo nivel")),
              DropdownMenuItem(value: "upgrading", child: Text("Proximo de subir")),
              DropdownMenuItem(value: "first_time", child: Text("Alcancando pela 1a vez")),
              DropdownMenuItem(value: "recovering", child: Text("Recuperando manutencao")),
              DropdownMenuItem(value: "at_risk", child: Text("Em risco")),
            ],
            onChanged: (v) => setState(() => _filterStatus = v),
          ),
          DropdownButton<int?>(
            value: _filterNextTier,
            hint: const Text("Proximo Tier", style: TextStyle(color: Colors.white54, fontSize: 12)),
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text("Tier: Todos")),
              ...levelThresholds.skip(1).map((t) => DropdownMenuItem<int?>(value: t, child: Text(t >= 1000000 ? (t / 1000000).toStringAsFixed(1) + "M" : (t / 1000).toStringAsFixed(0) + "k"))),
            ],
            onChanged: (v) => setState(() => _filterNextTier = v),
          ),
          DropdownButton<String?>(
            value: _filterProbability,
            hint: const Text("Probabilidade", style: TextStyle(color: Colors.white54, fontSize: 12)),
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: const [
              DropdownMenuItem(value: null, child: Text("Probabilidade: Todas")),
              DropdownMenuItem(value: "Alta", child: Text("Alta")),
              DropdownMenuItem(value: "Media", child: Text("Media")),
              DropdownMenuItem(value: "Baixa", child: Text("Baixa")),
            ],
            onChanged: (v) => setState(() => _filterProbability = v),
          ),
          DropdownButton<String?>(
            value: _filterDiamondsGap,
            hint: const Text("Diamantes faltantes", style: TextStyle(color: Colors.white54, fontSize: 12)),
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: const [
              DropdownMenuItem(value: null, child: Text("Diamantes: Todos")),
              DropdownMenuItem(value: "5000", child: Text("Ate 5.000")),
              DropdownMenuItem(value: "10000", child: Text("Ate 10.000")),
              DropdownMenuItem(value: "20000", child: Text("Ate 20.000")),
              DropdownMenuItem(value: "50000", child: Text("Ate 50.000")),
              DropdownMenuItem(value: "above50000", child: Text("Acima de 50.000")),
            ],
            onChanged: (v) => setState(() => _filterDiamondsGap = v),
          ),
          DropdownButton<String?>(
            value: _filterDaysGap,
            hint: const Text("Dias faltantes", style: TextStyle(color: Colors.white54, fontSize: 12)),
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: const [
              DropdownMenuItem(value: null, child: Text("Dias: Todos")),
              DropdownMenuItem(value: "0", child: Text("0 dias")),
              DropdownMenuItem(value: "1", child: Text("Falta 1 dia")),
              DropdownMenuItem(value: "2", child: Text("Faltam 2 dias")),
              DropdownMenuItem(value: "3+", child: Text("Faltam 3+ dias")),
            ],
            onChanged: (v) => setState(() => _filterDaysGap = v),
          ),
          DropdownButton<String?>(
            value: _filterHoursGap,
            hint: const Text("Horas faltantes", style: TextStyle(color: Colors.white54, fontSize: 12)),
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: const [
              DropdownMenuItem(value: null, child: Text("Horas: Todas")),
              DropdownMenuItem(value: "0", child: Text("0 horas")),
              DropdownMenuItem(value: "5", child: Text("Ate 5 horas")),
              DropdownMenuItem(value: "10", child: Text("Ate 10 horas")),
              DropdownMenuItem(value: "above10", child: Text("Acima de 10 horas")),
            ],
            onChanged: (v) => setState(() => _filterHoursGap = v),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            DropdownButton<String>(
              value: _filterResponsavelType,
              dropdownColor: const Color(0xFF1A1A1A),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              items: const [
                DropdownMenuItem(value: "grupo", child: Text("Grupo")),
                DropdownMenuItem(value: "agente", child: Text("Agente")),
                DropdownMenuItem(value: "gestor", child: Text("Gestor")),
              ],
              onChanged: (v) => setState(() {
                _filterResponsavelType = v!;
                _filterResponsavelValue = null;
              }),
            ),
            const SizedBox(width: 6),
            DropdownButton<String?>(
              value: _filterResponsavelValue,
              hint: const Text("Todos", style: TextStyle(color: Colors.white54, fontSize: 12)),
              dropdownColor: const Color(0xFF1A1A1A),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              items: [const DropdownMenuItem<String?>(value: null, child: Text("Todos")), ...responsavelOptions.map((o) => DropdownMenuItem<String?>(value: o, child: Text(o, style: const TextStyle(fontSize: 12))))],
              onChanged: (v) => setState(() => _filterResponsavelValue = v),
            ),
          ]),
          DropdownButton<String>(
            value: _sortBy,
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: const [
              DropdownMenuItem(value: "prioridade_desc", child: Text("Ordenar: Maior prioridade")),
              DropdownMenuItem(value: "prioridade_asc", child: Text("Ordenar: Menor prioridade")),
              DropdownMenuItem(value: "proximo_tier", child: Text("Ordenar: Mais perto do Tier")),
              DropdownMenuItem(value: "menos_diamantes", child: Text("Ordenar: Menos diamantes faltando")),
              DropdownMenuItem(value: "menos_dias", child: Text("Ordenar: Menos dias faltando")),
              DropdownMenuItem(value: "menos_horas", child: Text("Ordenar: Menos horas faltando")),
              DropdownMenuItem(value: "impacto_financeiro", child: Text("Ordenar: Maior impacto financeiro")),
              DropdownMenuItem(value: "probabilidade", child: Text("Ordenar: Maior probabilidade")),
            ],
            onChanged: (v) => setState(() => _sortBy = v!),
          ),
          TextButton.icon(onPressed: _clearFilters, icon: const Icon(Icons.filter_alt_off, size: 14), label: const Text("Limpar filtros", style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _prioridadeFilterBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(14)),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 220,
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, color: Colors.white54, size: 18),
                hintText: "Buscar por nome ou ID",
                hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _pmSearch = v),
            ),
          ),
          DropdownButton<int?>(
            value: _pmNextTier,
            hint: const Text("Proximo Tier: Todos", style: TextStyle(color: Colors.white54, fontSize: 12)),
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text("Proximo Tier: Todos")),
              ...levelThresholds.skip(1).map((t) => DropdownMenuItem<int?>(value: t, child: Text(t >= 1000000 ? (t / 1000000).toStringAsFixed(1) + "M" : (t / 1000).toStringAsFixed(0) + "k"))),
            ],
            onChanged: (v) => setState(() => _pmNextTier = v),
          ),
          DropdownButton<String?>(
            value: _pmProbability,
            hint: const Text("Probabilidade: Todas", style: TextStyle(color: Colors.white54, fontSize: 12)),
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: const [
              DropdownMenuItem(value: null, child: Text("Probabilidade: Todas")),
              DropdownMenuItem(value: "Muito Alta", child: Text("Muito Alta")),
              DropdownMenuItem(value: "Alta", child: Text("Alta")),
              DropdownMenuItem(value: "Media", child: Text("Media")),
              DropdownMenuItem(value: "Baixa", child: Text("Baixa")),
            ],
            onChanged: (v) => setState(() => _pmProbability = v),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            DropdownButton<String>(
              value: _pmSortBy,
              dropdownColor: const Color(0xFF1A1A1A),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              items: const [
                DropdownMenuItem(value: "proximo", child: Text("Mais proximo do objetivo")),
                DropdownMenuItem(value: "diamantes", child: Text("Menos diamantes faltando")),
                DropdownMenuItem(value: "progresso", child: Text("Maior progresso")),
                DropdownMenuItem(value: "impacto", child: Text("Maior impacto financeiro")),
                DropdownMenuItem(value: "alfabetica", child: Text("Ordem alfabetica")),
              ],
              onChanged: (v) => setState(() {
                _pmSortBy = v!;
                _pmSortAscending = v == "progresso" || v == "impacto" ? false : true;
              }),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => setState(() => _pmSortAscending = !_pmSortAscending),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0xFF7A0BD4).withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                child: Icon(_pmSortAscending ? Icons.arrow_upward : Icons.arrow_downward, color: const Color(0xFF7A0BD4), size: 16),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _diasHorasFilterBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(14)),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 220,
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, color: Colors.white54, size: 18),
                hintText: "Buscar por nome ou ID",
                hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _dhSearch = v),
            ),
          ),
          DropdownButton<int?>(
            value: _dhDayMilestone,
            hint: const Text("Marco de dias: Todos", style: TextStyle(color: Colors.white54, fontSize: 12)),
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text("Marco de dias: Todos")),
              ...levelActivityDays.take(5).map((d) => DropdownMenuItem<int?>(value: d, child: Text(d.toString() + " dias"))),
            ],
            onChanged: (v) => setState(() => _dhDayMilestone = v),
          ),
          DropdownButton<int?>(
            value: _dhHourMilestone,
            hint: const Text("Marco de horas: Todos", style: TextStyle(color: Colors.white54, fontSize: 12)),
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text("Marco de horas: Todos")),
              ...levelActivityHours.take(5).map((h) => DropdownMenuItem<int?>(value: h, child: Text(h.toString() + " horas"))),
            ],
            onChanged: (v) => setState(() => _dhHourMilestone = v),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            DropdownButton<String>(
              value: _dhSortBy,
              dropdownColor: const Color(0xFF1A1A1A),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              items: const [
                DropdownMenuItem(value: "proximo", child: Text("Mais perto de completar")),
                DropdownMenuItem(value: "dias", child: Text("Menos dias faltando")),
                DropdownMenuItem(value: "horas", child: Text("Menos horas faltando")),
                DropdownMenuItem(value: "alfabetica", child: Text("Ordem alfabetica")),
              ],
              onChanged: (v) => setState(() => _dhSortBy = v!),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => setState(() => _dhSortAscending = !_dhSortAscending),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0xFF7A0BD4).withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                child: Icon(_dhSortAscending ? Icons.arrow_upward : Icons.arrow_downward, color: const Color(0xFF7A0BD4), size: 16),
              ),
            ),
          ]),
          TextButton.icon(
            onPressed: () => setState(() {
              _dhSearch = "";
              _dhDayMilestone = null;
              _dhHourMilestone = null;
              _dhSortBy = "proximo";
              _dhSortAscending = true;
            }),
            icon: const Icon(Icons.filter_alt_off, size: 14),
            label: const Text("Limpar filtros", style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _milestoneBar(List<num> milestones, List<String> labels, double current, int highlightIndex) {
    return Row(
      children: milestones.asMap().entries.map((e) {
        final idx = e.key;
        final val = e.value;
        final reached = current >= val;
        final isHighlight = idx == highlightIndex;
        return Expanded(
          child: Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: reached ? (isHighlight ? Colors.amber : Colors.greenAccent) : Colors.white12,
                  border: isHighlight ? Border.all(color: Colors.amber, width: 2) : Border.all(color: Colors.white24, width: 1),
                ),
              ),
              const SizedBox(height: 2),
              Text(labels[idx], style: TextStyle(fontSize: 8, color: reached ? Colors.white70 : Colors.white24)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(children: [
      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(width: 8),
      InkWell(
        onTap: () => setState(() => _pmSortAscending = !_pmSortAscending),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: const Color(0xFF7A0BD4).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
          child: Icon(_pmSortAscending ? Icons.arrow_upward : Icons.arrow_downward, color: const Color(0xFF7A0BD4), size: 14),
        ),
      ),
    ]);
  }

  Widget _tabChip(String key, String label) {
    final selected = _tab == key;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      selectedColor: const Color(0xFF7A0BD4),
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
      onSelected: (_) => setState(() => _tab = key),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text("Erro ao carregar: " + _error!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
        ),
      );
    }

    final receitaGarantida = _items.where((i) => i["maintained"] == true).toList();
    final proximosUpgrades = _items.where((i) => i["canUpgradeDiamonds"] == true).toList();
    final emRisco = _items.where((i) => i["maintained"] != true && i["isRecovering"] != true).toList();
    final recuperacao = _items.where((i) => i["isRecovering"] == true).toList();
    final diasHoras = _items.where((i) => i["meetsMaintDiamonds"] == true && i["meetsMaintActivity"] != true).toList();

    final filtered = _filteredItems;
    final emRiscoFiltered = filtered.where((i) => i["maintained"] != true && i["isRecovering"] != true).toList();
    final recuperacaoFiltered = filtered.where((i) => i["isRecovering"] == true).toList();
    final proximosUpgradesFiltered = filtered.where((i) => i["canUpgradeDiamonds"] == true).toList();

    final goalCount = _agencyGoal?["target_count"] as int? ?? 30;
    final goalDiamonds = _agencyGoal?["target_diamonds"] as int? ?? 80000;
    final currentAboveGoal = _items.where((i) => (i["currentDiamonds"] as num) >= goalDiamonds).length;
    final goalFraction = goalCount == 0 ? 0.0 : (currentAboveGoal / goalCount).clamp(0.0, 1.0);

    final distribution = <String, int>{
      "Ate 40k": 0, "40k-80k": 0, "80k-150k": 0, "150k-250k": 0, "250k-350k": 0,
      "350k-500k": 0, "500k-800k": 0, "800k-1.2M": 0, "1.2M-1.6M": 0, "1.6M+": 0,
    };
    for (final i in _items) {
      final d = i["currentDiamonds"] as num;
      if (d < 40000) distribution["Ate 40k"] = distribution["Ate 40k"]! + 1;
      else if (d < 80000) distribution["40k-80k"] = distribution["40k-80k"]! + 1;
      else if (d < 150000) distribution["80k-150k"] = distribution["80k-150k"]! + 1;
      else if (d < 250000) distribution["150k-250k"] = distribution["150k-250k"]! + 1;
      else if (d < 350000) distribution["250k-350k"] = distribution["250k-350k"]! + 1;
      else if (d < 500000) distribution["350k-500k"] = distribution["350k-500k"]! + 1;
      else if (d < 800000) distribution["500k-800k"] = distribution["500k-800k"]! + 1;
      else if (d < 1200000) distribution["800k-1.2M"] = distribution["800k-1.2M"]! + 1;
      else if (d < 1600000) distribution["1.2M-1.6M"] = distribution["1.2M-1.6M"]! + 1;
      else distribution["1.6M+"] = distribution["1.6M+"]! + 1;
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Manutencao de Nivel", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    SizedBox(height: 4),
                    Text("Acompanhe quais streamers podem gerar mais receita atraves da manutencao e evolucao de niveis.", style: TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _load),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              _summaryCard("Receita Garantida", receitaGarantida.length.toString(), Icons.verified, Colors.greenAccent, ""),
              const SizedBox(width: 10),
              _summaryCard("Proximos Upgrades", proximosUpgrades.length.toString(), Icons.trending_up, Colors.blueAccent, ""),
              const SizedBox(width: 10),
              _summaryCard("Em Risco", emRisco.length.toString(), Icons.warning_amber, Colors.orangeAccent, ""),
              const SizedBox(width: 10),
              _summaryCard("Recuperacao", recuperacao.length.toString(), Icons.replay, const Color(0xFF7A0BD4), ""),
            ]),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.flag, color: Color(0xFF7A0BD4), size: 16),
                          const SizedBox(width: 6),
                          const Text("Meta da Agencia", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          const Spacer(),
                          Text(currentAboveGoal.toString() + " / " + goalCount.toString(), style: const TextStyle(color: Color(0xFF7A0BD4), fontWeight: FontWeight.bold, fontSize: 12)),
                        ]),
                        const SizedBox(height: 4),
                        Text(goalCount.toString() + " streamers acima de " + goalDiamonds.toString(), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        const SizedBox(height: 6),
                        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: goalFraction, minHeight: 7, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation(Color(0xFF7A0BD4)))),
                        const SizedBox(height: 4),
                        Row(children: [
                          Text((goalFraction * 100).toStringAsFixed(0) + "% da meta", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                          const Spacer(),
                          TextButton(onPressed: _editGoal, style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)), child: const Text("Editar", style: TextStyle(fontSize: 11))),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Distribuicao da Agencia", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 110,
                          child: BarChart(
                            BarChartData(
                              barTouchData: BarTouchData(enabled: true),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final keys = distribution.keys.toList();
                                      final i = value.toInt();
                                      if (i < 0 || i >= keys.length) return const SizedBox.shrink();
                                      return Padding(padding: const EdgeInsets.only(top: 4), child: Text(keys[i], style: const TextStyle(color: Colors.white54, fontSize: 7)));
                                    },
                                  ),
                                ),
                              ),
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              barGroups: distribution.values.toList().asMap().entries.map((e) {
                                return BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: e.value.toDouble(), color: const Color(0xFF7A0BD4), width: 10, borderRadius: BorderRadius.circular(3))]);
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _tabChip("prioridade", "Prioridade Maxima"),
              _tabChip("dias_horas", "Dias e Horas"),
              _tabChip("risco", "Manutencao em Risco"),
              _tabChip("ranking", "Ranking de Oportunidades"),
              _tabChip("recomendacoes", "Recomendacoes IA"),
            ]),
            const SizedBox(height: 16),
            if (_tab == "prioridade") _prioridadeFilterBar(),
            if (_tab == "prioridade") ...[
              _sectionHeader("Prioridade Maxima - mais perto do proximo Tier primeiro"),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: _prioridadeItems.take(30).map((i) {
                    final atMax = i["atMaxLevel"] == true;
                    final probColor = i["probability"] == "Alta" ? Colors.greenAccent : i["probability"] == "Media" ? Colors.amber : Colors.orangeAccent;
                    final previousLevel = i["previousLevel"] as int;
                    final currentLevelNow = i["currentLevelNow"] as int;
                    final displayPrevTier = previousLevel;
                    final displayCurrentTier = currentLevelNow;

                    const tierColors = [
                      Colors.white38, Colors.tealAccent, Colors.blueAccent, Colors.purpleAccent,
                      Colors.pinkAccent, Colors.orangeAccent, Colors.amber, Colors.lightGreenAccent,
                      Colors.greenAccent, Colors.yellowAccent,
                    ];
                    final currentTierColor = tierColors[displayCurrentTier.clamp(0, 9)];

                    final showManutencao = previousLevel >= 2 && currentLevelNow == previousLevel;
                    final subidaCount = (previousLevel >= 2 && currentLevelNow > previousLevel) ? (currentLevelNow - previousLevel) : 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: const Border(bottom: BorderSide(color: Colors.white12))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white24,
                              backgroundImage: i["avatar_url"] != null ? NetworkImage(i["avatar_url"] as String) : null,
                              child: i["avatar_url"] == null ? const Icon(Icons.person, color: Colors.white70, size: 18) : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(onTap: () => _openDetail(i), child: Text(i["display_name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, decoration: TextDecoration.underline))),
                                  Text("ID: " + (i["id"] as String).substring(0, 8) + "...", style: const TextStyle(color: Colors.white24, fontSize: 9)),
                                ],
                              ),
                            ),
                            if (displayCurrentTier >= 2)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(border: Border.all(color: currentTierColor), borderRadius: BorderRadius.circular(6)),
                                child: Text("Tier " + displayCurrentTier.toString(), style: TextStyle(color: currentTierColor, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [Text(i["historicoEmoji"] as String, style: const TextStyle(fontSize: 12)), const SizedBox(width: 4), Expanded(child: Text(i["historicoLabel"] as String, style: const TextStyle(color: Colors.white54, fontSize: 11)))]),
                          if (showManutencao || subidaCount > 0) ...[
                            const SizedBox(height: 6),
                            Wrap(spacing: 6, runSpacing: 6, children: [
                              if (showManutencao)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                                  child: const Text("Manutencao de Nivel", style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ...List.generate(subidaCount, (idx) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                                    child: const Text("Subida de Nivel", style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                                  )),
                            ]),
                          ],
                          const SizedBox(height: 10),
                          if (!atMax)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Row(children: [
                                const Icon(Icons.diamond, color: Colors.orangeAccent, size: 16),
                                const SizedBox(width: 6),
                                Text("Faltam " + (i["effDiamondGap"] as double).toStringAsFixed(0) + " diamantes para o proximo nivel", style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                              ]),
                            ),
                          const SizedBox(height: 8),
                          Wrap(spacing: 16, runSpacing: 4, children: [
                            Text("\ud83d\udc8e Atuais: " + (i["currentDiamonds"] as num).toStringAsFixed(0), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            Text("\ud83d\udcc5 Dias: " + i["currentDays"].toString() + " / " + (i["nextReqDays"]?.toString() ?? "-"), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            Text("\u23f1\ufe0f Horas: " + i["currentHours"].toString() + " / " + (i["nextReqHours"]?.toString() ?? "-"), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            if (!atMax) Text("\ud83d\udfe2 Probabilidade: " + (i["probability"] as String), style: TextStyle(color: probColor, fontSize: 12, fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 10),
                          _levelContextBar(i),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            if (_tab == "dias_horas") ...[
              _sectionHeader("Dias e Horas para o proximo Tier - mais perto de concluir primeiro"),
              const SizedBox(height: 12),
              ...filtered.where((i) => i["atMaxLevel"] != true).take(30).map((i) {
                final dayGap = ((i["nextReqDays"] as int?) ?? 0) - (i["currentDays"] as num);
                final hourGap = ((i["nextReqHours"] as int?) ?? 0) - (i["currentHours"] as num);
                final dayOk = dayGap <= 0;
                final hourOk = hourGap <= 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.tealAccent.withOpacity(0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.tealAccent.withOpacity(0.3))),
                  child: Row(children: [
                    CircleAvatar(radius: 16, backgroundColor: Colors.white24, backgroundImage: i["avatar_url"] != null ? NetworkImage(i["avatar_url"] as String) : null, child: i["avatar_url"] == null ? const Icon(Icons.person, color: Colors.white70, size: 16) : null),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(onTap: () => _openDetail(i), child: Text(i["display_name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, decoration: TextDecoration.underline))),
                          const SizedBox(height: 6),
                          Text("Rumo ao Tier " + i["nextLevel"].toString(), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(dayOk ? Icons.check_circle : Icons.radio_button_unchecked, color: dayOk ? Colors.greenAccent : Colors.white38, size: 13),
                            const SizedBox(width: 4),
                            Text("Dias " + i["currentDays"].toString() + " / " + (i["nextReqDays"]?.toString() ?? "-"), style: TextStyle(color: dayOk ? Colors.greenAccent : Colors.white70, fontSize: 12)),
                            const SizedBox(width: 14),
                            Icon(hourOk ? Icons.check_circle : Icons.radio_button_unchecked, color: hourOk ? Colors.greenAccent : Colors.white38, size: 13),
                            const SizedBox(width: 4),
                            Text("Horas " + i["currentHours"].toString() + " / " + (i["nextReqHours"]?.toString() ?? "-"), style: TextStyle(color: hourOk ? Colors.greenAccent : Colors.white70, fontSize: 12)),
                          ]),
                          const SizedBox(height: 6),
                          Row(children: [
                            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: i["dayFractionNext"] as double, minHeight: 6, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation(Colors.blueAccent)))),
                            const SizedBox(width: 8),
                            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: i["hourFractionNext"] as double, minHeight: 6, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation(Colors.purpleAccent)))),
                          ]),
                          const SizedBox(height: 6),
                          if (dayOk && hourOk)
                            const Text("Requisitos de atividade completos para o proximo Tier!", style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold))
                          else
                            Text(
                              "Faltam: " + (dayGap > 0 ? dayGap.toStringAsFixed(0) + " dia(s) " : "") + (hourGap > 0 ? hourGap.toStringAsFixed(0) + " hora(s)" : ""),
                              style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ),
                  ]),
                );
              }),
            ],
            if (_tab == "risco") ...[
              _sectionHeader("Manutencao em Risco"),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: emRiscoFiltered.isEmpty
                      ? [const Padding(padding: EdgeInsets.all(16), child: Text("Nenhum streamer em risco no momento.", style: TextStyle(color: Colors.white54)))]
                      : emRiscoFiltered.map((i) {
                          final sit = _situacao(i);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(onTap: () => _openDetail(i), child: Text(i["display_name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, decoration: TextDecoration.underline))),
                                    const SizedBox(height: 4),
                                    Row(children: [Text(sit.$1 + " ", style: const TextStyle(fontSize: 11)), Expanded(child: Text(sit.$2, style: TextStyle(color: sit.$3, fontSize: 11, fontWeight: FontWeight.bold)))]),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(flex: 3, child: _levelContextBar(i)),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text("Dias " + i["currentDays"].toString() + "/" + i["requiredDays"].toString(), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                  Text("Horas " + i["currentHours"].toString() + "/" + i["requiredHours"].toString(), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                ],
                              ),
                            ]),
                          );
                        }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              const Text("Recuperacao", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              if (recuperacaoFiltered.isEmpty)
                const Text("Nenhum streamer em processo de recuperacao.", style: TextStyle(color: Colors.white54, fontSize: 13))
              else
                ...recuperacaoFiltered.map((i) {
                  final targetThreshold = levelThresholds[(i["bestEverLevel"] as int) - 1];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFF7A0BD4).withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF7A0BD4).withOpacity(0.35))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(onTap: () => _openDetail(i), child: Text(i["display_name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, decoration: TextDecoration.underline))),
                        const SizedBox(height: 6),
                        Text("Melhor nivel: Tier " + i["bestEverLevel"].toString() + " (" + targetThreshold.toString() + " diamantes)    Mes passado: Tier " + i["previousLevel"].toString(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text("Objetivo: voltar para " + targetThreshold.toString() + " diamantes", style: const TextStyle(color: Color(0xFF7A0BD4), fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text("Se recuperar novamente o nivel, a agencia volta a receber a bonificacao.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  );
                }),
            ],
            if (_tab == "ranking") ...[
              const Text("Oportunidades de Upgrade", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              if (proximosUpgradesFiltered.isEmpty)
                const Text("Nenhum streamer proximo de subir de nivel no momento.", style: TextStyle(color: Colors.white54, fontSize: 13))
              else
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: proximosUpgradesFiltered.map((i) {
                    final nextThreshold = (i["nextThreshold"] as int?) ?? 0;
                    final currentDiamonds = i["currentDiamonds"] as num;
                    final fraction = nextThreshold == 0 ? 1.0 : (currentDiamonds / nextThreshold).clamp(0.0, 1.0);
                    final activityOk = (i["currentDays"] as num) >= (i["nextReqDays"] as int? ?? 0) && (i["currentHours"] as num) >= (i["nextReqHours"] as int? ?? 0);
                    return Container(
                      width: 300,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.blueAccent.withOpacity(0.4))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            CircleAvatar(radius: 16, backgroundColor: Colors.white24, backgroundImage: i["avatar_url"] != null ? NetworkImage(i["avatar_url"] as String) : null, child: i["avatar_url"] == null ? const Icon(Icons.person, color: Colors.white70, size: 16) : null),
                            const SizedBox(width: 8),
                            Expanded(child: GestureDetector(onTap: () => _openDetail(i), child: Text(i["display_name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)))),
                          ]),
                          const SizedBox(height: 10),
                          Text("Tier " + i["previousLevel"].toString() + " -> Tier " + i["nextLevel"].toString(), style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          Text(currentDiamonds.toStringAsFixed(0) + " / " + nextThreshold.toString() + " diamantes", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 4),
                          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: fraction, minHeight: 6, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation(Colors.blueAccent))),
                          const SizedBox(height: 8),
                          Text("Faltam " + ((nextThreshold - currentDiamonds).clamp(0, nextThreshold)).toStringAsFixed(0) + " diamantes", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text("Dias: " + i["currentDays"].toString() + "/" + (i["nextReqDays"]?.toString() ?? "-") + "   Horas: " + i["currentHours"].toString() + "/" + (i["nextReqHours"]?.toString() ?? "-"),
                              style: TextStyle(color: activityOk ? Colors.greenAccent : Colors.orangeAccent, fontSize: 11)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: (activityOk ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                            child: Text(activityOk ? "Probabilidade alta" : "Probabilidade media", style: TextStyle(color: activityOk ? Colors.greenAccent : Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 20),
              _sectionHeader("Ranking de Oportunidades"),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: filtered.take(15).toList().asMap().entries.map((entry) {
                    final idx = entry.key;
                    final i = entry.value;
                    final medal = idx == 0 ? "\ud83e\udd47" : idx == 1 ? "\ud83e\udd48" : idx == 2 ? "\ud83e\udd49" : null;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        medal != null ? Text(medal, style: const TextStyle(fontSize: 18)) : SizedBox(width: 24, child: Text((idx + 1).toString(), style: const TextStyle(color: Colors.white38), textAlign: TextAlign.center)),
                        const SizedBox(width: 10),
                        CircleAvatar(radius: 14, backgroundColor: Colors.white24, backgroundImage: i["avatar_url"] != null ? NetworkImage(i["avatar_url"] as String) : null, child: i["avatar_url"] == null ? const Icon(Icons.person, color: Colors.white70, size: 14) : null),
                        const SizedBox(width: 10),
                        Expanded(child: GestureDetector(onTap: () => _openDetail(i), child: Text(i["display_name"] as String, style: const TextStyle(color: Colors.white, fontSize: 13, decoration: TextDecoration.underline)))),
                        Text("Score " + (i["score"] as double).toStringAsFixed(0), style: const TextStyle(color: Color(0xFF7A0BD4), fontWeight: FontWeight.bold, fontSize: 12)),
                      ]),
                    );
                  }).toList(),
                ),
              ),
            ],
            if (_tab == "recomendacoes") ...[
              _sectionHeader("Recomendacoes Inteligentes"),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: filtered.map((i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.lightbulb, color: Colors.amber, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 12.5),
                              children: [
                                TextSpan(text: (i["display_name"] as String) + ": ", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                TextSpan(text: i["recommendation"] as String, style: const TextStyle(color: Colors.white70)),
                              ],
                            ),
                          ),
                        ),
                      ]),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}















