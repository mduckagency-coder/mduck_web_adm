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
      setState(() => _errorMessage = "Preencha e-mail e senha.");
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

  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey("login"),
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _emailController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: "E-mail", labelStyle: TextStyle(color: Colors.white70), prefixIcon: Icon(Icons.email_outlined, color: Colors.white54)),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: "Senha",
            labelStyle: const TextStyle(color: Colors.white70),
            prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          obscureText: _obscurePassword,
          onSubmitted: (_) => _handleLogin(),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Checkbox(value: _rememberEmail, onChanged: (v) => setState(() => _rememberEmail = v ?? false), activeColor: const Color(0xFF7A0BD4)),
          const Text("Lembrar meu e-mail", style: TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
        Row(children: [
          Checkbox(value: _keepConnected, onChanged: (v) => setState(() => _keepConnected = v ?? true), activeColor: const Color(0xFF7A0BD4)),
          const Text("Manter conectado", style: TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => setState(() {
              _mode = _LoginMode.forgotEmail;
              _errorMessage = null;
              _infoMessage = null;
            }),
            child: const Text("Esqueci minha senha"),
          ),
        ),
        const SizedBox(height: 8),
        _buildMessages(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _isLoading
                ? const Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    SizedBox(width: 10),
                    Text("Entrando..."),
                  ])
                : const Text("Entrar"),
          ),
        ),
      ],
    );
  }

  Widget _buildForgotEmailForm() {
    return Column(
      key: const ValueKey("forgotEmail"),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("Recuperar senha", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text("Informe seu e-mail para receber um codigo de verificacao.", style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: "E-mail", labelStyle: TextStyle(color: Colors.white70), prefixIcon: Icon(Icons.email_outlined, color: Colors.white54)),
        ),
        const SizedBox(height: 12),
        _buildMessages(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSendCode,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Text(_isLoading ? "Enviando..." : "Enviar codigo"),
          ),
        ),
        TextButton(onPressed: () => setState(() => _mode = _LoginMode.login), child: const Text("Voltar para o login")),
      ],
    );
  }

  Widget _buildForgotCodeForm() {
    return Column(
      key: const ValueKey("forgotCode"),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("Digite o codigo", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text("Verifique seu e-mail e cole o codigo recebido.", style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        TextField(
          controller: _codeController,
          style: const TextStyle(color: Colors.white, letterSpacing: 4, fontSize: 18),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(labelText: "Codigo", labelStyle: TextStyle(color: Colors.white70)),
        ),
        const SizedBox(height: 12),
        _buildMessages(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleVerifyCode,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Text(_isLoading ? "Validando..." : "Validar codigo"),
          ),
        ),
        TextButton(onPressed: _isLoading ? null : _handleSendCode, child: const Text("Reenviar codigo")),
        TextButton(onPressed: () => setState(() => _mode = _LoginMode.login), child: const Text("Voltar para o login")),
      ],
    );
  }

  Widget _buildForgotNewPasswordForm() {
    return Column(
      key: const ValueKey("forgotNewPassword"),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("Nova senha", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          controller: _newPasswordController,
          obscureText: _obscureNewPassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: "Nova senha",
            labelStyle: const TextStyle(color: Colors.white70),
            suffixIcon: IconButton(icon: Icon(_obscureNewPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white54), onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureNewPassword,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: "Confirmar senha", labelStyle: TextStyle(color: Colors.white70)),
        ),
        const SizedBox(height: 12),
        _buildMessages(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSetNewPassword,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Text(_isLoading ? "Salvando..." : "Confirmar senha"),
          ),
        ),
      ],
    );
  }

  Widget _buildMessages() {
    return Column(children: [
      if (_infoMessage != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_infoMessage!, style: const TextStyle(color: Colors.greenAccent), textAlign: TextAlign.center)),
      if (_errorMessage != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center)),
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
    final cardWidth = screenWidth < 480 ? screenWidth * 0.9 : 400.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.black,
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    width: cardWidth,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 12))],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset("assets/logo/LogoMduck.png", height: 150, errorBuilder: (context, error, stack) => const Icon(Icons.hive, color: Color(0xFF7A0BD4), size: 100)),
                          const SizedBox(height: 28),
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
        ),
      ),
    );
  }
}




