import 'package:flutter/material.dart';

enum AvaliacaoStatus {
  rascunho,
  submetida,
  validada,
  aprovada,
  devolvida,
}

class AvaliacaoStatusChip extends StatelessWidget {
  final AvaliacaoStatus status;

  const AvaliacaoStatusChip({super.key, required this.status});

  factory AvaliacaoStatusChip.fromString(String rawStatus, {String? comentarioValidacao}) {
    if (rawStatus.toLowerCase() == 'rascunho' &&
        comentarioValidacao != null &&
        comentarioValidacao.trim().isNotEmpty) {
      return const AvaliacaoStatusChip(status: AvaliacaoStatus.devolvida);
    }
    switch (rawStatus.toLowerCase()) {
      case 'submetida':
        return const AvaliacaoStatusChip(status: AvaliacaoStatus.submetida);
      case 'validada':
        return const AvaliacaoStatusChip(status: AvaliacaoStatus.validada);
      case 'aprovada':
        return const AvaliacaoStatusChip(status: AvaliacaoStatus.aprovada);
      case 'devolvida':
        return const AvaliacaoStatusChip(status: AvaliacaoStatus.devolvida);
      case 'rascunho':
      default:
        return const AvaliacaoStatusChip(status: AvaliacaoStatus.rascunho);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        _getLabel(),
        style: TextStyle(
          color: _getTextColor(),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      backgroundColor: _getBackgroundColor(),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  String _getLabel() {
    switch (status) {
      case AvaliacaoStatus.rascunho:
        return 'Rascunho';
      case AvaliacaoStatus.submetida:
        return 'Submetida';
      case AvaliacaoStatus.validada:
        return 'Validada';
      case AvaliacaoStatus.aprovada:
        return 'Aprovada';
      case AvaliacaoStatus.devolvida:
        return 'Devolvida';
    }
  }

  Color _getBackgroundColor() {
    switch (status) {
      case AvaliacaoStatus.rascunho:
        return const Color(0xFFEEEEEE); // Hex #EEEEEE (L=0.854)
      case AvaliacaoStatus.submetida:
        return const Color(0xFFFFECB3); // Hex #FFECB3 (L=0.835)
      case AvaliacaoStatus.validada:
        return const Color(0xFFBBDEFB); // Hex #BBDEFB (L=0.724)
      case AvaliacaoStatus.aprovada:
        return const Color(0xFFB2DFDB); // Hex #B2DFDB (L=0.718)
      case AvaliacaoStatus.devolvida:
        return const Color(0xFFFFE0B2); // Hex #FFE0B2 (L=0.738)
    }
  }

  Color _getTextColor() {
    switch (status) {
      case AvaliacaoStatus.rascunho:
        return const Color(0xFF212121); // Hex #212121 (L=0.017) -> Contraste 13.49:1
      case AvaliacaoStatus.submetida:
        return const Color(0xFF6E3000); // Hex #6E3000 (L=0.043) -> Contraste 9.51:1
      case AvaliacaoStatus.validada:
        return const Color(0xFF082C66); // Hex #082C66 (L=0.026) -> Contraste 10.18:1
      case AvaliacaoStatus.aprovada:
        return const Color(0xFF00332B); // Hex #00332B (L=0.030) -> Contraste 9.60:1
      case AvaliacaoStatus.devolvida:
        return const Color(0xFF7E2A00); // Hex #7E2A00 (L=0.061) -> Contraste 7.10:1
    }
  }
}
