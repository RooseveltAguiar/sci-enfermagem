import 'package:flutter/material.dart';

class UsuarioStatusChip extends StatelessWidget {
  final bool ativo;

  const UsuarioStatusChip({
    super.key,
    required this.ativo,
  });

  @override
  Widget build(BuildContext context) {
    // Hex fundo Ativo: #E8F5E9 (L=0.898), Texto Ativo: #144A18 (L=0.054) -> Contraste 9.11:1
    // Hex fundo Inativo: #EEEEEE (L=0.854), Texto Inativo: #212121 (L=0.017) -> Contraste 13.49:1
    final bgColor = ativo ? const Color(0xFFE8F5E9) : const Color(0xFFEEEEEE);
    final textColor = ativo ? const Color(0xFF144A18) : const Color(0xFF212121);
    final borderColor = ativo ? const Color(0xFFA5D6A7) : const Color(0xFFE0E0E0);
    final label = ativo ? 'Ativo' : 'Inativo';

    return Chip(
      label: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      backgroundColor: bgColor,
      side: BorderSide(color: borderColor),
      visualDensity: VisualDensity.compact,
    );
  }
}
