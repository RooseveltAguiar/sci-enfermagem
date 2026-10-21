import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';

// Formatador de CPF: 000.000.000-00
class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 11) text = text.substring(0, 11);

    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 3 || i == 6) {
        formatted += '.';
      } else if (i == 9) {
        formatted += '-';
      }
      formatted += text[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _cpfController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscureText = true;
  bool _rememberCpf = true;
  String? _selectedDemoProfile;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _cpfController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _preFillDemo(String perfil, String cpf, String senha) {
    setState(() {
      _selectedDemoProfile = perfil;
      _cpfController.text = _formatCpf(cpf);
      _passwordController.text = senha;
    });
  }

  String _formatCpf(String digits) {
    if (digits.length != 11) return digits;
    return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6, 9)}-${digits.substring(9, 11)}';
  }

  bool _isFormValid() {
    final cpf = _cpfController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return cpf.length == 11 && _passwordController.text.isNotEmpty;
  }

  Future<void> _login() async {
    if (!_isFormValid()) return;

    TextInput.finishAutofillContext();

    await ref.read(authNotifierProvider.notifier).login(
          _cpfController.text,
          _passwordController.text,
        );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Color(0xFF00695C)),
            SizedBox(width: 10),
            Text('Suporte ao Acesso'),
          ],
        ),
        content: const Text(
          'O acesso ao SCI - Enfermagem é restrito a alunos matriculados em estágios, supervisores conveniados, professores orientadores e coordenação do curso.\n\n'
          'Caso tenha esquecido sua senha institucional ou precise de liberação de CPF, entre em contato pelo e-mail da Coordenação de Enfermagem.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ENTENDI'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF00332C),
          image: DecorationImage(
            image: AssetImage('assets/images/login_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF002A24).withValues(alpha: 0.85),
                const Color(0xFF004D40).withValues(alpha: 0.80),
                const Color(0xFF001F1A).withValues(alpha: 0.90),
              ],
            ),
          ),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 960;
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 36,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isWide ? 1040 : 480,
                      ),
                      child: isWide
                          ? IntrinsicHeight(
                              child: _buildDesktopLayout(authState),
                            )
                          : _buildMobileCard(authState),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // LAYOUT DESKTOP / WEB WIDE (Painel Split Institucional + Card de Login)
  // ===========================================================================
  Widget _buildDesktopLayout(AsyncValue<void> authState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Painel Institucional Esquerdo com a foto humanizada
          Expanded(
            flex: 6,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF004D40),
                image: DecorationImage(
                  image: AssetImage('assets/images/login_bg.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(48),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF004D40).withValues(alpha: 0.70),
                      const Color(0xFF002E27).withValues(alpha: 0.88),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                  // Cabeçalho institucional superior
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.health_and_safety,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SCI · ENFERMAGEM',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            'Curso de Enfermagem · CCIS',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Conteúdo Principal Institucional
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF80CBC4).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: const Color(0xFF80CBC4).withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Text(
                          'SISTEMA ACADÊMICO DE ESTÁGIOS',
                          style: TextStyle(
                            color: Color(0xFFE0F2F1),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Excelência no Controle\ne Gestão da Prática\nClínica.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Acompanhe presenças por geolocalização, avaliações\npor competência e a documentação normativa em um\núnico ecossistema digital integrado.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Indicadores de funcionalidade
                      _buildFeatureTile(
                        icon: Icons.verified_user_outlined,
                        title: 'Frequência com Geolocalização',
                        subtitle:
                            'Registro auditável nos campos hospitalares e UBS',
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureTile(
                        icon: Icons.fact_check_outlined,
                        title: 'Avaliação Pedagógica 360°',
                        subtitle:
                            'Integração fluida entre alunos, preceptores e professores',
                      ),
                    ],
                  ),

                  // Rodapé Institucional
                  const Text(
                    '© 2026 SCI Enfermagem • Todos os direitos reservados',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

          // Painel Direito — Formulário de Acesso
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 48,
                vertical: 40,
              ),
              child: _buildFormContent(authState),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LAYOUT MOBILE / TABLET (Card Único Centralizado)
  // ===========================================================================
  Widget _buildMobileCard(AsyncValue<void> authState) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo mobile
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF00695C).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.health_and_safety,
              size: 44,
              color: Color(0xFF00695C),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'SCI · Enfermagem',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const Text(
            'Sistema de Controle de Estágios',
            style: TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 28),
          _buildFormContent(authState),
        ],
      ),
    );
  }

  // ===========================================================================
  // COMPONENTES DO FORMULÁRIO DE LOGIN
  // ===========================================================================
  Widget _buildFormContent(AsyncValue<void> authState) {
    return AutofillGroup(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Acesso Institucional',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Digite seu CPF e senha institucional para entrar.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 24),

        // Atalhos para Teste / Preenchimento Rápido
        _buildDemoCredentialsSelector(),
        const SizedBox(height: 24),

        // Alerta de Erro (caso ocorra falha no login)
        if (authState.hasError) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEF9A9A)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFC62828),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formatErrorMessage(authState.error.toString()),
                    style: const TextStyle(
                      color: Color(0xFFB71C1C),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Campo CPF
        TextFormField(
          controller: _cpfController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username, AutofillHints.telephoneNumber],
          onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
          inputFormatters: [CpfInputFormatter()],
          decoration: InputDecoration(
            labelText: 'CPF',
            hintText: '000.000.000-00',
            prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF00695C)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF00695C), width: 2),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),

        // Campo Senha
        TextFormField(
          controller: _passwordController,
          obscureText: _obscureText,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            labelText: 'Senha',
            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF00695C)),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: Colors.grey.shade600,
              ),
              tooltip: _obscureText ? 'Mostrar senha' : 'Ocultar senha',
              onPressed: () => setState(() => _obscureText = !_obscureText),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF00695C), width: 2),
            ),
          ),
          onChanged: (_) => setState(() {}),
          onFieldSubmitted: (_) => _login(),
        ),

        const SizedBox(height: 12),

        // Lembrar CPF & Esqueci a Senha
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _rememberCpf = !_rememberCpf),
              child: Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _rememberCpf,
                      activeColor: const Color(0xFF00695C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) =>
                          setState(() => _rememberCpf = val ?? true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Lembrar CPF',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _showHelpDialog,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00695C),
              ),
              child: const Text(
                'Esqueci minha senha',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Botão de Login Primário
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: (_isFormValid() && !authState.isLoading)
                ? const LinearGradient(
                    colors: [Color(0xFF004D40), Color(0xFF00695C)],
                  )
                : null,
            color: (_isFormValid() && !authState.isLoading)
                ? null
                : Colors.grey.shade300,
            boxShadow: (_isFormValid() && !authState.isLoading)
                ? [
                    BoxShadow(
                      color: const Color(0xFF00695C).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap:
                  (_isFormValid() && !authState.isLoading) ? _login : null,
              child: Center(
                child: authState.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                          semanticsLabel: 'Carregando...',
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'ACESSAR SISTEMA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildDemoCredentialsSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tips_and_updates_outlined,
                size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              'Acesso Rápido para Testes / Avaliação:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickPill('Aluno', '11144477735', 'Teste@SCI2026'),
            _buildQuickPill('Supervisor', '22244477760', 'Teste@SCI2026'),
            _buildQuickPill('Professor', '33344477782', 'Teste@SCI2026'),
            _buildQuickPill('Coordenação', '44444477700', 'Teste@SCI2026'),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickPill(String label, String cpf, String senha) {
    final isSelected = _selectedDemoProfile == label;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _preFillDemo(label, cpf, senha),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00695C)
              : const Color(0xFF00695C).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF004D40)
                : const Color(0xFF00695C).withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF00695C),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF80CBC4), size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatErrorMessage(String raw) {
    if (raw.contains('Invalid login credentials') ||
        raw.contains('user not found')) {
      return 'CPF ou senha incorretos. Verifique os dados informados.';
    }
    if (raw.contains('CPF inválido')) {
      return 'O CPF informado é inválido.';
    }
    return raw.replaceAll('Exception: ', '');
  }
}
