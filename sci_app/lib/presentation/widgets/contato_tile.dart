import 'package:flutter/material.dart';

class ContatoTile extends StatelessWidget {
  final String nome;
  final String perfil;
  final String? avatarUrl;
  final VoidCallback? onTap;

  const ContatoTile({
    super.key,
    required this.nome,
    required this.perfil,
    this.avatarUrl,
    this.onTap,
  });

  String _formatarPerfil(String p) {
    switch (p.toLowerCase()) {
      case 'aluno':
        return 'Aluno';
      case 'supervisor':
        return 'Supervisor';
      case 'professor':
        return 'Professor';
      case 'coordenacao':
        return 'Coordenação';
      default:
        return p;
    }
  }

  Color _corPerfil(String p) {
    switch (p.toLowerCase()) {
      case 'aluno':
        return Colors.blue.shade700;
      case 'supervisor':
        return Colors.orange.shade800;
      case 'professor':
        return const Color(0xFF1B6B45);
      case 'coordenacao':
        return Colors.purple.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final inicial = nome.isNotEmpty ? nome[0].toUpperCase() : '?';

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF1B6B45),
        child: Text(
          inicial,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        nome,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Container(
        margin: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _corPerfil(perfil).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _corPerfil(perfil).withValues(alpha: 0.3)),
              ),
              child: Text(
                _formatarPerfil(perfil),
                style: TextStyle(
                  color: _corPerfil(perfil),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
    );
  }
}
