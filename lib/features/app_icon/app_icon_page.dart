import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../inventario/app_settings_service.dart";

/// Chave em app_settings para a arte mestre do icone do app (config padrao).
/// Futuros icones sazonais (Natal, Halloween etc.) entram como chaves novas
/// (ex: "app_icon_natal") sem precisar de mudanca de schema.
const appIconDefaultKey = "app_icon_default";

class AppIconPage extends StatefulWidget {
  const AppIconPage({super.key});

  @override
  State<AppIconPage> createState() => _AppIconPageState();
}

class _AppIconPageState extends State<AppIconPage> {
  final _service = AppSettingsService();

  bool _loading = true;
  bool _uploading = false;
  String? _iconUrl;
  String? _error;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// AppSettingsService.fetchValue usa .maybeSingle(), que nesta versao do
  /// client lanca excecao quando a chave ainda nao tem nenhuma linha (em vez
  /// de simplesmente retornar null) -- por isso "nenhum icone cadastrado"
  /// virava erro. Consulta local em lista evita esse caso: lista vazia nunca
  /// lanca excecao, so significa "nada cadastrado ainda".
  Future<String?> _fetchIconUrl() async {
    final agencyId = await _service.currentAgencyId();
    final rows = await Supabase.instance.client
        .from("app_settings")
        .select("value")
        .eq("agency_id", agencyId)
        .eq("key", appIconDefaultKey)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    final value = (list.first as Map<String, dynamic>)["value"];
    return value is String && value.isNotEmpty ? value : null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final value = await _fetchIconUrl();
      if (mounted) setState(() => _iconUrl = value);
    } catch (e) {
      if (mounted) setState(() => _loadError = "Não foi possível carregar o ícone atual. Tente novamente.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndSave() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.single.bytes == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final url = await _service.uploadMedia(result.files.single);
      await _service.saveValue(appIconDefaultKey, url);
      if (mounted) setState(() => _iconUrl = url);
    } catch (e) {
      if (mounted) setState(() => _error = "Não foi possível salvar o ícone. Tente novamente.");
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!, style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _load, child: const Text("Tentar novamente")),
                    ],
                  ),
                )
              : SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("🎨 Ícone do Aplicativo", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text(
                      "Arte mestre usada para gerar o ícone do app nas lojas (Android e iPhone).",
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    const Text("Ícone atual", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: _iconUrl == null || _iconUrl!.isEmpty
                            ? const Center(child: Icon(Icons.image_outlined, color: Colors.white38, size: 56))
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Image.network(_iconUrl!, fit: BoxFit.cover),
                              ),
                      ),
                    ),
                    if (_iconUrl == null || _iconUrl!.isEmpty) ...[
                      const SizedBox(height: 10),
                      const Center(
                        child: Text("Nenhum ícone configurado ainda.", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _uploading ? null : _pickAndSave,
                        icon: const Icon(Icons.upload),
                        label: Text(_uploading ? "Enviando..." : (_iconUrl == null || _iconUrl!.isEmpty ? "Enviar ícone" : "Substituir ícone")),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                    ],
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("📐 Especificação recomendada", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          SizedBox(height: 6),
                          Text(
                            "Envie a arte em PNG, 1024 × 1024 px, de preferência com fundo transparente.\n"
                            "Essa é a imagem mestre que será usada para gerar os formatos necessários para Android e iPhone.",
                            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
