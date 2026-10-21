import 'package:flutter_test/flutter_test.dart';
import 'package:sci_app/core/utils/cpf_formatter.dart';

void main() {
  group('CpfFormatter', () {
    test('getOnlyNumbers deve remover pontuação', () {
      expect(CpfFormatter.getOnlyNumbers('123.456.789-00'), '12345678900');
      expect(CpfFormatter.getOnlyNumbers('abc123def456'), '123456');
    });

    test('toAuthEmail deve converter CPF de 11 dígitos em e-mail', () {
      expect(CpfFormatter.toAuthEmail('123.456.789-00'), '12345678900@sci.uece.br');
      expect(CpfFormatter.toAuthEmail('12345678900'), '12345678900@sci.uece.br');
    });

    test('toAuthEmail deve lançar FormatException se CPF não tiver 11 dígitos numéricos', () {
      expect(() => CpfFormatter.toAuthEmail('123'), throwsFormatException);
      expect(() => CpfFormatter.toAuthEmail('123.456.789-001'), throwsFormatException); // 12 dígitos
    });
  });
}
