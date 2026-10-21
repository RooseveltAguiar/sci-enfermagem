import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 11; i++) {
      if (i == 3 || i == 6) {
        buffer.write('.');
      } else if (i == 9) {
        buffer.write('-');
      }
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CpfFormField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final String? errorText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final FocusNode? focusNode;

  const CpfFormField({
    super.key,
    this.controller,
    this.initialValue,
    this.enabled = true,
    this.onChanged,
    this.validator,
    this.errorText,
    this.textInputAction,
    this.onFieldSubmitted,
    this.focusNode,
  });

  static bool isCpfValido(String? cpf) {
    if (cpf == null || cpf.isEmpty) return false;
    final numbers = cpf.replaceAll(RegExp(r'\D'), '');
    if (numbers.length != 11) return false;

    // Bloquear sequências de dígitos iguais
    if (RegExp(r'^(\d)\1{10}$').hasMatch(numbers)) return false;

    List<int> digits = numbers.split('').map(int.parse).toList();

    // Primeiro dígito verificador
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += digits[i] * (10 - i);
    }
    int firstCheck = 11 - (sum % 11);
    if (firstCheck >= 10) firstCheck = 0;
    if (digits[9] != firstCheck) return false;

    // Segundo dígito verificador
    sum = 0;
    for (int i = 0; i < 10; i++) {
      sum += digits[i] * (11 - i);
    }
    int secondCheck = 11 - (sum % 11);
    if (secondCheck >= 10) secondCheck = 0;
    return digits[10] == secondCheck;
  }

  static String? defaultValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'CPF é obrigatório';
    }
    if (!isCpfValido(value)) {
      return 'CPF inválido';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      enabled: enabled,
      focusNode: focusNode,
      textInputAction: textInputAction,
      autofillHints: const [AutofillHints.username],
      onFieldSubmitted: onFieldSubmitted,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        CpfInputFormatter(),
      ],
      decoration: InputDecoration(
        labelText: 'CPF',
        hintText: '000.000.000-00',
        border: const OutlineInputBorder(),
        errorText: errorText,
      ),
      validator: validator ?? defaultValidator,
      onChanged: onChanged,
    );
  }
}
