class CpfFormatter {
  /// Remove qualquer caractere não numérico de uma string (ex: '123.456.789-00' -> '12345678900')
  static String getOnlyNumbers(String cpf) {
    return cpf.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// Converte o CPF mascarado do usuário para o formato de email do Supabase
  /// Ex: '123.456.789-00' -> '12345678900@sci.uece.br'
  static String toAuthEmail(String rawCpf) {
    final numbers = getOnlyNumbers(rawCpf);
    if (numbers.length != 11) {
      throw const FormatException('CPF inválido');
    }
    return '$numbers@sci.uece.br';
  }
}
