import 'package:flutter_test/flutter_test.dart';
import 'package:interfajas_app/utils/formatos.dart';

void main() {
  test('formatos como en la web', () {
    expect(cop(45000), '\$45.000');
    expect(time12('14:30'), '2:30 p. m.');
    expect(codigoArreglo(7), 'R007');
  });
}
