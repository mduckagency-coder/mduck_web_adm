import "dart:html" as html;
import "dart:ui";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "admin_auth_repository.dart";
import "../public/privacy_policy_page.dart";
import "../public/terms_page.dart";

const _purple = Color(0xFF7A0BD4);
const _purpleLight = Color(0xFF9B3DF5);
const _darkField = Color(0xFF0A0812);
const _cardColor = Color(0xFF15101F);
const _labelGray = Color(0xFFB4AFC7);
const _cardRadius = 20.0;

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

enum _LoginMode { login, forgotEmail, forgotCode, forgotNewPassword }

class _AdminLoginPageState extends State<AdminLoginPage> with TickerProviderStateMixin {
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
  late AnimationController _borderBeamController;

  static const _prefsKey = "mduck_remembered_email";

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
    _borderBeamController = AnimationController(vsync: this, duration: const Duration(milliseconds: 5200))..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    _borderBeamController.dispose();
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
    return Text(
      text,
      style: const TextStyle(color: _labelGray, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8),
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
        side: BorderSide(color: Colors.white.withOpacity(0.45), width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
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
        _PremiumTextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _fieldLabel("SENHA"),
        const SizedBox(height: 6),
        _PremiumTextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          onSubmitted: (_) => _handleLogin(),
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 18),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _HoverLink(
              text: "Esqueci minha senha",
              baseColor: Colors.white70,
              onPressed: () => setState(() {
                _mode = _LoginMode.forgotEmail;
                _errorMessage = null;
                _infoMessage = null;
              }),
            ),
          ),
        ),
        _buildMessages(),
        const SizedBox(height: 6),
        _PremiumButton(label: _isLoading ? "Entrando..." : "Entrar", loading: _isLoading, onPressed: _isLoading ? null : _handleLogin),
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
        _PremiumTextField(controller: _emailController),
        const SizedBox(height: 12),
        _buildMessages(),
        _PremiumButton(label: _isLoading ? "Enviando..." : "Enviar codigo", loading: _isLoading, onPressed: _isLoading ? null : _handleSendCode),
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
        _PremiumTextField(
          controller: _codeController,
          style: const TextStyle(color: Colors.white, letterSpacing: 4, fontSize: 18),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        _buildMessages(),
        _PremiumButton(label: _isLoading ? "Validando..." : "Validar codigo", loading: _isLoading, onPressed: _isLoading ? null : _handleVerifyCode),
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
        _PremiumTextField(
          controller: _newPasswordController,
          obscureText: _obscureNewPassword,
          suffixIcon: IconButton(
            icon: Icon(_obscureNewPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 18),
            onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
          ),
        ),
        const SizedBox(height: 12),
        _fieldLabel("CONFIRMAR SENHA"),
        const SizedBox(height: 6),
        _PremiumTextField(controller: _confirmPasswordController, obscureText: _obscureNewPassword),
        const SizedBox(height: 12),
        _buildMessages(),
        _PremiumButton(label: _isLoading ? "Salvando..." : "Confirmar senha", loading: _isLoading, onPressed: _isLoading ? null : _handleSetNewPassword),
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

  void _openPublicPage(String path, Widget page) {
    html.window.history.pushState(null, "", path);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)).then((_) {
      html.window.history.pushState(null, "", "/");
    });
  }

  Widget _buildFooterLinks() {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 20,
        children: [
          _HoverLink(
            text: "Política de Privacidade",
            fontSize: 11,
            baseColor: Colors.white54,
            onPressed: () => _openPublicPage("/privacy", const PrivacyPolicyPage()),
          ),
          _HoverLink(
            text: "Termos de Uso",
            fontSize: 11,
            baseColor: Colors.white54,
            onPressed: () => _openPublicPage("/terms", const TermsPage()),
          ),
        ],
      ),
    );
  }

  Widget _buildBorderBeam() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _borderBeamController,
        builder: (context, _) {
          return CustomPaint(
            painter: _BorderBeamPainter(progress: _borderBeamController.value),
            size: Size.infinite,
          );
        },
      ),
    );
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
                  decoration: BoxDecoration(
                    color: _cardColor.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(_cardRadius),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 60, offset: const Offset(0, 24)),
                      BoxShadow(color: _purple.withOpacity(0.10), blurRadius: 40, offset: const Offset(0, 0)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_cardRadius),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset("assets/logo/LogoMduck.png", height: 204, errorBuilder: (context, error, stack) => const Icon(Icons.hive, color: _purple, size: 120)),
                              const SizedBox(height: 4),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: _buildCurrentForm(),
                              ),
                              _buildFooterLinks(),
                            ],
                          ),
                        ),
                        Positioned.fill(child: _buildBorderBeam()),
                      ],
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

class _PremiumTextField extends StatefulWidget {
  const _PremiumTextField({
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.textAlign = TextAlign.start,
    this.style,
    this.suffixIcon,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextAlign textAlign;
  final TextStyle? style;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_PremiumTextField> createState() => _PremiumTextFieldState();
}

class _PremiumTextFieldState extends State<_PremiumTextField> {
  final _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _hasFocus = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: _darkField,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _hasFocus ? _purple : Colors.white.withOpacity(0.10), width: _hasFocus ? 1.3 : 1),
        boxShadow: _hasFocus ? [BoxShadow(color: _purple.withOpacity(0.28), blurRadius: 14, spreadRadius: 1)] : const [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textAlign: widget.textAlign,
        style: widget.style ?? const TextStyle(color: Colors.white),
        onSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          suffixIcon: widget.suffixIcon,
          hintStyle: const TextStyle(color: Colors.white24),
        ),
      ),
    );
  }
}

class _HoverLink extends StatefulWidget {
  const _HoverLink({required this.text, required this.onPressed, this.fontSize = 12, this.baseColor = Colors.white70});

  final String text;
  final VoidCallback onPressed;
  final double fontSize;
  final Color baseColor;

  @override
  State<_HoverLink> createState() => _HoverLinkState();
}

class _HoverLinkState extends State<_HoverLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: TextStyle(color: _hovered ? _purpleLight : widget.baseColor, fontSize: widget.fontSize, fontWeight: FontWeight.w500),
          child: Text(widget.text),
        ),
      ),
    );
  }
}

class _PremiumButton extends StatefulWidget {
  const _PremiumButton({required this.label, required this.loading, required this.onPressed});

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  State<_PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<_PremiumButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_purpleLight, _purple]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: _purple.withOpacity(_hovered ? 0.55 : 0.35), blurRadius: _hovered ? 28 : 18, offset: const Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              child: Center(
                child: widget.loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.3)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BorderBeamPainter extends CustomPainter {
  const _BorderBeamPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(_cardRadius));
    final path = Path()..addRRect(rrect);

    final gradient = SweepGradient(
      transform: GradientRotation(progress * 2 * 3.141592653589793),
      colors: const [
        Colors.transparent,
        Colors.transparent,
        Color(0xE6FFFFFF),
        Colors.transparent,
        Colors.transparent,
      ],
      stops: const [0.0, 0.44, 0.5, 0.56, 1.0],
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = gradient.createShader(rect);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BorderBeamPainter oldDelegate) => oldDelegate.progress != progress;
}
