import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "unified_profile_page.dart";

class ProfileAvatarMenu extends StatefulWidget {
  const ProfileAvatarMenu({super.key});

  @override
  State<ProfileAvatarMenu> createState() => _ProfileAvatarMenuState();
}

class _ProfileAvatarMenuState extends State<ProfileAvatarMenu> {
  String? _photoUrl;
  String? _label;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final me = await client.from("managers").select("photo_url, full_name, login_email").eq("id", userId).maybeSingle();
    if (mounted && me != null) {
      setState(() {
        _photoUrl = me["photo_url"] as String?;
        _label = (me["full_name"] as String?)?.isNotEmpty == true ? me["full_name"] as String : me["login_email"] as String?;
      });
    }
  }

  Future<void> _changePasswordQuick(BuildContext context) async {
    final newPasswordController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorMessage;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text("Alterar senha", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: newPasswordController, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nova senha", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              TextField(controller: confirmController, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Confirmar senha", labelStyle: TextStyle(color: Colors.white54))),
              if (errorMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
              onPressed: () async {
                if (newPasswordController.text.trim().length < 6) {
                  setState(() => errorMessage = "A senha deve ter pelo menos 6 caracteres.");
                  return;
                }
                if (newPasswordController.text.trim() != confirmController.text.trim()) {
                  setState(() => errorMessage = "As senhas nao coincidem.");
                  return;
                }
                try {
                  await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPasswordController.text.trim()));
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Senha alterada com sucesso.")));
                  }
                } catch (e) {
                  setState(() => errorMessage = "Erro ao alterar senha: " + e.toString());
                }
              },
              child: const Text("Salvar"),
            ),
          ],
        ),
      ),
    );
  }

  void _openProfile(BuildContext context, String initialTab) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => UnifiedProfilePage(initialTab: initialTab)));
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: "Conta",
      offset: const Offset(0, -160),
      color: const Color(0xFF1A1A1A),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Text(_label ?? "...", style: const TextStyle(color: Colors.white54, fontSize: 12), overflow: TextOverflow.ellipsis),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: "perfil", child: Row(children: [Icon(Icons.person_outline, color: Colors.white70, size: 18), SizedBox(width: 10), Text("Meu Perfil", style: TextStyle(color: Colors.white))])),
        const PopupMenuItem(value: "conta", child: Row(children: [Icon(Icons.account_circle_outlined, color: Colors.white70, size: 18), SizedBox(width: 10), Text("Minha Conta", style: TextStyle(color: Colors.white))])),
        const PopupMenuItem(value: "config", child: Row(children: [Icon(Icons.settings_outlined, color: Colors.white70, size: 18), SizedBox(width: 10), Text("Configuracoes", style: TextStyle(color: Colors.white))])),
        const PopupMenuItem(value: "senha", child: Row(children: [Icon(Icons.lock_outline, color: Colors.white70, size: 18), SizedBox(width: 10), Text("Alterar Senha", style: TextStyle(color: Colors.white))])),
        const PopupMenuDivider(),
        const PopupMenuItem(value: "sair", child: Row(children: [Icon(Icons.logout, color: Colors.redAccent, size: 18), SizedBox(width: 10), Text("Sair", style: TextStyle(color: Colors.redAccent))])),
      ],
      onSelected: (value) {
        switch (value) {
          case "perfil":
            _openProfile(context, "Informacoes");
            break;
          case "conta":
            _openProfile(context, "Conta");
            break;
          case "config":
            _openProfile(context, "Conta");
            break;
          case "senha":
            _changePasswordQuick(context);
            break;
          case "sair":
            Supabase.instance.client.auth.signOut();
            break;
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
              child: _photoUrl == null ? const Icon(Icons.person, color: Colors.white70, size: 18) : null,
            ),
            const SizedBox(width: 8),
            SizedBox(width: 110, child: Text(_label ?? "...", style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
            const Icon(Icons.expand_more, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }
}

