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

  const StatusChip({Key? key, required this.status}) : super(key: key);

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
        return Colors.orange.shade100;
      case FrequenciaStatus.validado:
      case FrequenciaStatus.ratificado:
        return Colors.green.shade100;
      case FrequenciaStatus.rejeitado:
      case FrequenciaStatus.ausente:
        return Colors.red.shade100;
    }
  }

  Color _getTextColor(BuildContext context) {
    switch (status) {
      case FrequenciaStatus.pendenteValidacao:
      case FrequenciaStatus.abonadoPendRatificacao:
        return Colors.orange.shade900;
      case FrequenciaStatus.validado:
      case FrequenciaStatus.ratificado:
        return Colors.green.shade900;
      case FrequenciaStatus.rejeitado:
      case FrequenciaStatus.ausente:
        return Colors.red.shade900;
    }
  }
}
