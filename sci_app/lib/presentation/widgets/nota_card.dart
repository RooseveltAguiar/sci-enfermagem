import 'package:flutter/material.dart';

class NotaCard extends StatelessWidget {
  final int notaGeral;

  const NotaCard({super.key, required this.notaGeral});

  @override
  Widget build(BuildContext context) {
    final faixa = _getFaixa();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: faixa.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: faixa.borderColor, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nota Geral',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: faixa.textColor.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                faixa.label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: faixa.textColor,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: faixa.borderColor.withValues(alpha: 0.2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Text(
              '$notaGeral',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: faixa.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _FaixaNota _getFaixa() {
    if (notaGeral <= 3) {
      return _FaixaNota(
        label: 'Insatisfatório',
        backgroundColor: Colors.red.shade50,
        borderColor: Colors.red.shade200,
        textColor: Colors.red.shade900,
      );
    } else if (notaGeral <= 6) {
      return _FaixaNota(
        label: 'Regular',
        backgroundColor: Colors.amber.shade50,
        borderColor: Colors.amber.shade200,
        textColor: Colors.amber.shade900,
      );
    } else if (notaGeral <= 8) {
      return _FaixaNota(
        label: 'Bom',
        backgroundColor: Colors.green.shade50,
        borderColor: Colors.green.shade200,
        textColor: Colors.green.shade900,
      );
    } else {
      return _FaixaNota(
        label: 'Excelente',
        backgroundColor: Colors.teal.shade50,
        borderColor: Colors.teal.shade200,
        textColor: Colors.teal.shade900,
      );
    }
  }
}

class _FaixaNota {
  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  _FaixaNota({
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });
}
