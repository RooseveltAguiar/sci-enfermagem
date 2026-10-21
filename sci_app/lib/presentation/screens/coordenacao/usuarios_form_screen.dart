import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/models/usuario_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/usuarios_provider.dart';
import '../../widgets/confirmation_bottom_sheet.dart';
import '../../widgets/cpf_form_field.dart';

class UsuariosFormScreen extends ConsumerStatefulWidget {
  final String modo; // 'criar' | 'editar'
  final UsuarioModel? usuario;

  const UsuariosFormScreen({
    super.key,
    required this.modo,
    this.usuario,
  });

  @override
  ConsumerState<UsuariosFormScreen> createState() => _UsuariosFormScreenState();
}

class _UsuariosFormScreenState extends ConsumerState<UsuariosFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cpfController = TextEditingController();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();

  final _cpfFocusNode = FocusNode();
  String _perfilSelecionado = 'aluno';
  String? _cpfError;
  bool _isLoading = false;

  bool get isCriar => widget.modo == 'criar';

  @override
  void initState() {
    super.initState();
    if (!isCriar && widget.usuario != null) {
      _cpfController.text = widget.usuario!.cpfMascarado;
      _nomeController.text = widget.usuario!.nome;
      _emailController.text = widget.usuario!.email ?? '';
      _perfilSelecionado = widget.usuario!.perfil;
    }

    _cpfFocusNode.addListener(() {
      if (!_cpfFocusNode.hasFocus && isCriar) {
        _verificarDuplicidadeCpf();
      }
    });
  }

  @override
  void dispose() {
    _cpfController.dispose();
    _nomeController.dispose();
    _emailController.dispose();
    _cpfFocusNode.dispose();
    super.dispose();
  }

  Future<void> _verificarDuplicidadeCpf() async {
    final raw = _cpfController.text.trim();
    if (raw.isEmpty) return;
    if (!CpfFormField.isCpfValido(raw)) return;

    try {
      final ctrl = ref.read(usuariosControllerProvider);
      final duplicado = await ctrl.verificarDuplicidadeCpf(raw);
      if (mounted) {
        setState(() {
          _cpfError = duplicado ? 'CPF já cadastrado' : null;
        });
      }
    } catch (_) {}
  }

  String _labelPerfil(String p) {
    switch (p) {
      case 'aluno':
        return 'Aluno';
      case 'supervisor':
        return 'Supervisor';
      case 'professor':
        return 'Professor';
      default:
        return p;
    }
  }

  Future<void> _submeterFormulario() async {
    setState(() => _cpfError = null);
    if (!_formKey.currentState!.validate()) return;

    if (isCriar) {
      await _verificarDuplicidadeCpf();
      if (_cpfError != null) return;
      if (!mounted) return;

      ConfirmationBottomSheet.show(
        context,
        title: 'Criar usuário?',
        message:
            'Criar usuário ${_nomeController.text.trim()} como ${_labelPerfil(_perfilSelecionado)}? Uma senha temporária será gerada automaticamente.',
        onConfirm: () async {
          Navigator.of(context).pop();
          await _executarCriacao();
        },
      );
    } else {
      await _executarEdicao();
    }
  }

  Future<void> _executarCriacao() async {
    setState(() => _isLoading = true);
    try {
      final ctrl = ref.read(usuariosControllerProvider);
      final emailVal = _emailController.text.trim();
      final res = await ctrl.criarUsuario(
        cpf: _cpfController.text.trim(),
        nome: _nomeController.text.trim(),
        perfil: _perfilSelecionado,
        email: emailVal.isNotEmpty ? emailVal : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Usuário criado! Senha temporária: ${res['senha_temporaria']}',
          ),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao criar usuário. Tente novamente.\n${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _executarEdicao() async {
    if (widget.usuario == null) return;
    setState(() => _isLoading = true);
    try {
      final ctrl = ref.read(usuariosControllerProvider);
      final emailVal = _emailController.text.trim();
      await ctrl.editarUsuario(
        id: widget.usuario!.id,
        nome: _nomeController.text.trim(),
        email: emailVal.isNotEmpty ? emailVal : null,
        perfil: widget.usuario!.perfil,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário atualizado com sucesso.')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao atualizar: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _alterarStatus(bool desativar) async {
    if (widget.usuario == null) return;

    final isProprio =
        ref.read(supabaseClientProvider).auth.currentUser?.id == widget.usuario!.id;
    if (isProprio && desativar) return;

    final msg = desativar
        ? 'Desativar ${widget.usuario!.nome}? O usuário perderá acesso ao app. Sessões ativas expiram em até 8 horas.'
        : 'Reativar ${widget.usuario!.nome}? O usuário voltará a ter acesso ao app.';

    ConfirmationBottomSheet.show(
      context,
      title: desativar ? 'Desativar usuário?' : 'Reativar usuário?',
      message: msg,
      isDestructive: desativar,
      onConfirm: () async {
        Navigator.of(context).pop();
        setState(() => _isLoading = true);
        try {
          final ctrl = ref.read(usuariosControllerProvider);
          if (desativar) {
            await ctrl.desativarUsuario(
                widget.usuario!.id, widget.usuario!.perfil);
          } else {
            await ctrl.reativarUsuario(
                widget.usuario!.id, widget.usuario!.perfil);
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                desativar
                    ? 'Usuário desativado com sucesso.'
                    : 'Usuário reativado com sucesso.',
              ),
            ),
          );
          context.pop();
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.red,
            ),
          );
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    final isProprio =
        !isCriar && widget.usuario != null && currentUserId == widget.usuario!.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCriar ? 'Novo Usuário' : 'Editar Usuário'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando...'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isCriar)
                      Focus(
                        focusNode: _cpfFocusNode,
                        child: CpfFormField(
                          controller: _cpfController,
                          enabled: isCriar,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                          errorText: _cpfError,
                          validator: (val) {
                            if (_cpfError != null) return _cpfError;
                            return CpfFormField.defaultValidator(val);
                          },
                        ),
                      )
                    else
                      TextFormField(
                        controller: _cpfController,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'CPF',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nomeController,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                      decoration: const InputDecoration(
                        labelText: 'Nome completo *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Nome é obrigatório';
                        }
                        final words = val
                            .trim()
                            .split(RegExp(r'\s+'))
                            .where((w) => w.isNotEmpty)
                            .toList();
                        if (words.length < 3) {
                          return 'Informe o nome completo (mínimo 3 palavras)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _perfilSelecionado,
                      decoration: const InputDecoration(
                        labelText: 'Perfil *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'aluno', child: Text('Aluno')),
                        DropdownMenuItem(
                            value: 'supervisor', child: Text('Supervisor')),
                        DropdownMenuItem(
                            value: 'professor', child: Text('Professor')),
                      ],
                      onChanged: isCriar
                          ? (val) {
                              if (val != null) {
                                setState(() => _perfilSelecionado = val);
                              }
                            }
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submeterFormulario(),
                      decoration: const InputDecoration(
                        labelText: 'E-mail institucional (opcional)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val != null &&
                            val.trim().isNotEmpty &&
                            !val.contains('@')) {
                          return 'E-mail inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _submeterFormulario,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        isCriar ? 'Criar usuário' : 'Salvar alterações',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    if (!isCriar && widget.usuario != null) ...[
                      const SizedBox(height: 16),
                      if (widget.usuario!.ativo)
                        Tooltip(
                          message: isProprio
                              ? 'Você não pode desativar sua própria conta'
                              : '',
                          child: ElevatedButton(
                            onPressed:
                                isProprio ? null : () => _alterarStatus(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Desativar usuário'),
                          ),
                        )
                      else
                        ElevatedButton(
                          onPressed: () => _alterarStatus(false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Reativar usuário'),
                        ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
