import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/tipo.dart';

void main() {
  test('Azul acepta si todos son iguales', () {
    const azul = TipoAzul();
    expect(azul.esPosibleAgregar([], 4), isTrue);
    expect(azul.esPosibleAgregar([4, 4], 4), isTrue);
    expect(azul.esPosibleAgregar([4, 5], 4), isFalse);
  });

  test('Rojo no deja repetir números', () {
    const rojo = TipoRojo();
    expect(rojo.esPosibleAgregar([1, 2, 3], 4), isTrue);
    expect(rojo.esPosibleAgregar([1, 2, 3], 1), isFalse);
  });

  test('Verde acepta cualquier número', () {
    const verde = TipoVerde();
    expect(verde.esPosibleAgregar([5, 5, 9], 1), isTrue);
  });

  test('Morado solo deja dos números distintos', () {
    const morado = TipoMorado();
    expect(morado.esPosibleAgregar([2, 8, 2], 8), isTrue);
    expect(morado.esPosibleAgregar([2, 8], 5), isFalse);
  });

  test('Amarillo no deja repetir números', () {
    const amarillo = TipoAmarillo();
    expect(amarillo.esPosibleAgregar([10, 20], 30), isTrue);
    expect(amarillo.esPosibleAgregar([10, 20], 10), isFalse);
  });

  test('Devuelve los puntos y la descripción', () {
    expect(Tipo.verde.puntuaciones[1], equals(4));
    expect(Tipo.azul.descripcion, 'Todos los números deben de ser iguales');
  });
}