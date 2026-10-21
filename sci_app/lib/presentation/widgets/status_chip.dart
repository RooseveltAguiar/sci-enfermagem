import 'package:flutter/material.dart';

enum FrequenciaStatus {
  pendenteValidacao,
  validado,
  rejeitado,
  ausente,
  abonadoPendRatificacao,
  ratificado,
}

class StatusChip extends StatelessWidget {
  final FrequenciaStatus status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        _getLabel(),
        style: TextStyle(
          color: _getTextColor(context),
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: _getBackgroundColor(context),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  String _getLabel() {
    switch (status) {
      case FrequenciaStatus.pendenteValidacao:
        return 'Pendente';
      case FrequenciaStatus.validado:
        return 'Validado';
      case FrequenciaStatus.rejeitado:
        return 'Rejeitado';
      case FrequenciaStatus.ausente:
        return 'Ausente';
      case FrequenciaStatus.abonadoPendRatificacao:
        return 'Abono Pendente';
      case FrequenciaStatus.ratificado:
        return 'Ratificado';
    }
  }

  Color _getBackgroundColor(BuildContext context) {
    switch (status) {
      case FrequenciaStatus.pendenteValidacao:
      case FrequenciaStatus.abonadoPendRatificacao:
        return const Color(0xFFFFE0B2); // Hex #FFE0B2 (L=0.738)
      case FrequenciaStatus.validado:
      case FrequenciaStatus.ratificado:
        return const Color(0xFFC8E6C9); // Hex #C8E6C9 (L=0.748)
      case FrequenciaStatus.rejeitado:
      case FrequenciaStatus.ausente:
        return const Color(0xFFFFCDD2); // Hex #FFCDD2 (L=0.648)
    }
  }

  Color _getTextColor(BuildContext context) {
    switch (status) {
      case FrequenciaStatus.pendenteValidacao:
      case FrequenciaStatus.abonadoPendRatificacao:
        return const Color(0xFF7E2A00); // Hex #7E2A00 (L=0.061) -> Contraste 7.10:1
      case FrequenciaStatus.validado:
      case FrequenciaStatus.ratificado:
        return const Color(0xFF144A18); // Hex #144A18 (L=0.054) -> Contraste 7.67:1
      case FrequenciaStatus.rejeitado:
      case FrequenciaStatus.ausente:
        return const Color(0xFF7F1010); // Hex #7F1010 (L=0.038) -> Contraste 7.93:1
    }
  }
}
