import "dart:ui";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "admin_auth_repository.dart";

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

enum _LoginMode { login, forgotEmail, forgotCode, forgotNewPassword }

class _AdminLoginPageState extends State<AdminLoginPage> with SingleTickerProviderStateMixin {
  final _authRepository = AdminAuthRepository();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _LoginMode _mode = _LoginMode.login;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureNewPassword = true;
  bool _rememberEmail = false;
  bool _keepConnected = true;
  String? _errorMessage;
  String? _infoMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static const _prefsKey = "mduck_remembered_email";
  static const _purple = Color(0xFF7A0BD4);
  static const _darkField = Color(0xFF0C0A14);

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && saved.isNotEmpty) {
      setState(() {
        _emailController.text = saved;
        _rememberEmail = true;
      });
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains("invalid login credentials") || msg.contains("invalid_credentials")) return "E-mail ou senha incorretos.";
    if (msg.contains("user not found")) return "Usuario nao encontrado.";
    if (msg.contains("email not confirmed")) return "E-mail ainda nao confirmado.";
    if (msg.contains("token") && msg.contains("expired")) return "Sessao expirada. Faca login novamente.";
    if (msg.contains("network")) return "Falha de conexao. Verifique sua internet.";
    return "Nao foi possivel entrar. Tente novamente.";
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    if (email.isEmpty || _passwordController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Preencha usuario e senha.");
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final status = await _authRepository.checkLoginStatus(email);
      final managerId = status?["id"] as String?;
      final lockedUntilStr = status?["locked_until"] as String?;
      if (lockedUntilStr != null) {
        final lockedUntil = DateTime.parse(lockedUntilStr);
        if (DateTime.now().isBefore(lockedUntil)) {
          setState(() {
            _isLoading = false;
            _errorMessage = "Conta bloqueada por excesso de tentativas. Tente novamente apos " + lockedUntil.toLocal().toString().substring(11, 16) + ".";
          });
          return;
        }
      }
      final employmentStatus = status?["employment_status"] as String?;
      if (employmentStatus == "desligado") {
        setState(() {
          _isLoading = false;
          _errorMessage = "Esta conta esta inativa. Fale com o administrador.";
        });
        return;
      }

      await _authRepository.signIn(email: email, password: _passwordController.text.trim());
      await _authRepository.recordAttempt(email, true, managerId);
      if (managerId != null) await _authRepository.logSession(managerId);

      final prefs = await SharedPreferences.getInstance();
      if (_rememberEmail) {
        await prefs.setString(_prefsKey, email);
      } else {
        await prefs.remove(_prefsKey);
      }
    } catch (e) {
      final status = await _authRepository.checkLoginStatus(email);
      await _authRepository.recordAttempt(email, false, status?["id"] as String?);
      setState(() => _errorMessage = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSendCode() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Digite seu e-mail.");
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _authRepository.sendPasswordReset(_emailController.text.trim());
      setState(() {
        _mode = _LoginMode.forgotCode;
        _infoMessage = "Enviamos um codigo para o seu e-mail.";
      });
    } catch (e) {
      setState(() => _errorMessage = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyCode() async {
    if (_codeController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Digite o codigo recebido.");
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _authRepository.verifyRecoveryCode(email: _emailController.text.trim(), code: _codeController.text.trim());
      setState(() {
        _mode = _LoginMode.forgotNewPassword;
        _infoMessage = null;
      });
    } catch (e) {
      setState(() => _errorMessage = "Codigo invalido ou expirado. Tente enviar novamente.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSetNewPassword() async {
    if (_newPasswordController.text.trim().length < 6) {
      setState(() => _errorMessage = "A senha deve ter pelo menos 6 caracteres.");
      return;
    }
    if (_newPasswordController.text.trim() != _confirmPasswordController.text.trim()) {
      setState(() => _errorMessage = "As senhas nao sao iguais.");
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _authRepository.updatePassword(_newPasswordController.text.trim());
      setState(() {
        _mode = _LoginMode.login;
        _infoMessage = "Senha alterada com sucesso! Faca login com a nova senha.";
        _passwordController.clear();
        _codeController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
    } catch (e) {
      setState(() => _errorMessage = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _fieldLabel(String text) {
    return Text(text, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1));
  }

  InputDecoration _darkDecoration({Widget? suffixIcon, String? hint}) {
    return InputDecoration(
      filled: true,
      fillColor: _darkField,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      suffixIcon: suffixIcon,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _purple, width: 1.2)),
    );
  }

  Widget _smallPurpleButton({required String label, required bool loading, required VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: _purple,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _purpleCheckbox(bool value, ValueChanged<bool?> onChanged) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Checkbox(
        value: value,
        onChanged: onChanged,
        activeColor: _purple,
        checkColor: Colors.white,
        side: const BorderSide(color: Colors.white38),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey("login"),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel("USUARIO"),
        const SizedBox(height: 6),
        TextField(
          controller: _emailController,
          style: const TextStyle(color: Colors.white),
          decoration: _darkDecoration(),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _fieldLabel("SENHA"),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          style: const TextStyle(color: Colors.white),
          decoration: _darkDecoration(
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 18),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          obscureText: _obscurePassword,
          onSubmitted: (_) => _handleLogin(),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _purpleCheckbox(_rememberEmail, (v) => setState(() => _rememberEmail = v ?? false)),
          const SizedBox(width: 8),
          const Text("Lembrar-me", style: TextStyle(color: Colors.white, fontSize: 12)),
        ]),
        Row(children: [
          _purpleCheckbox(_keepConnected, (v) => setState(() => _keepConnected = v ?? true)),
          const SizedBox(width: 8),
          const Text("Manter conectado", style: TextStyle(color: Colors.white, fontSize: 12)),
        ]),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => setState(() {
              _mode = _LoginMode.forgotEmail;
              _errorMessage = null;
              _infoMessage = null;
            }),
            child: const Text("Esqueci minha senha", style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ),
        const SizedBox(height: 6),
        _buildMessages(),
        _smallPurpleButton(label: _isLoading ? "Entrando..." : "Entrar", loading: _isLoading, onPressed: _isLoading ? null : _handleLogin),
      ],
    );
  }

  Widget _buildForgotEmailForm() {
    return Column(
      key: const ValueKey("forgotEmail"),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Recuperar senha", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text("Informe seu e-mail para receber um codigo de verificacao.", style: TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 16),
        _fieldLabel("E-MAIL"),
        const SizedBox(height: 6),
        TextField(controller: _emailController, style: const TextStyle(color: Colors.white), decoration: _darkDecoration()),
        const SizedBox(height: 12),
        _buildMessages(),
        _smallPurpleButton(label: _isLoading ? "Enviando..." : "Enviar codigo", loading: _isLoading, onPressed: _isLoading ? null : _handleSendCode),
        Align(alignment: Alignment.center, child: TextButton(onPressed: () => setState(() => _mode = _LoginMode.login), child: const Text("Voltar para o login", style: TextStyle(color: Colors.white54)))),
      ],
    );
  }

  Widget _buildForgotCodeForm() {
    return Column(
      key: const ValueKey("forgotCode"),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Digite o codigo", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text("Verifique seu e-mail e cole o codigo recebido.", style: TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 16),
        _fieldLabel("CODIGO"),
        const SizedBox(height: 6),
        TextField(controller: _codeController, style: const TextStyle(color: Colors.white, letterSpacing: 4, fontSize: 18), textAlign: TextAlign.center, decoration: _darkDecoration()),
        const SizedBox(height: 12),
        _buildMessages(),
        _smallPurpleButton(label: _isLoading ? "Validando..." : "Validar codigo", loading: _isLoading, onPressed: _isLoading ? null : _handleVerifyCode),
        Align(alignment: Alignment.center, child: TextButton(onPressed: _isLoading ? null : _handleSendCode, child: const Text("Reenviar codigo", style: TextStyle(color: Colors.white54)))),
        Align(alignment: Alignment.center, child: TextButton(onPressed: () => setState(() => _mode = _LoginMode.login), child: const Text("Voltar para o login", style: TextStyle(color: Colors.white54)))),
      ],
    );
  }

  Widget _buildForgotNewPasswordForm() {
    return Column(
      key: const ValueKey("forgotNewPassword"),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Nova senha", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _fieldLabel("NOVA SENHA"),
        const SizedBox(height: 6),
        TextField(
          controller: _newPasswordController,
          obscureText: _obscureNewPassword,
          style: const TextStyle(color: Colors.white),
          decoration: _darkDecoration(suffixIcon: IconButton(icon: Icon(_obscureNewPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 18), onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword))),
        ),
        const SizedBox(height: 12),
        _fieldLabel("CONFIRMAR SENHA"),
        const SizedBox(height: 6),
        TextField(controller: _confirmPasswordController, obscureText: _obscureNewPassword, style: const TextStyle(color: Colors.white), decoration: _darkDecoration()),
        const SizedBox(height: 12),
        _buildMessages(),
        _smallPurpleButton(label: _isLoading ? "Salvando..." : "Confirmar senha", loading: _isLoading, onPressed: _isLoading ? null : _handleSetNewPassword),
      ],
    );
  }

  Widget _buildMessages() {
    return Column(children: [
      if (_infoMessage != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_infoMessage!, style: const TextStyle(color: Colors.greenAccent, fontSize: 12), textAlign: TextAlign.center)),
      if (_errorMessage != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12), textAlign: TextAlign.center)),
    ]);
  }

  Widget _buildCurrentForm() {
    switch (_mode) {
      case _LoginMode.login:
        return _buildLoginForm();
      case _LoginMode.forgotEmail:
        return _buildForgotEmailForm();
      case _LoginMode.forgotCode:
        return _buildForgotCodeForm();
      case _LoginMode.forgotNewPassword:
        return _buildForgotNewPasswordForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth < 480 ? screenWidth * 0.9 : 380.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [Color(0xFF241238), Color(0xFF120A1E), Color(0xFF08060D)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Container(
                  width: cardWidth,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF15101F).withOpacity(0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 20))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset("assets/logo/LogoMduck.png", height: 170, errorBuilder: (context, error, stack) => const Icon(Icons.hive, color: _purple, size: 100)),
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _buildCurrentForm(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}






