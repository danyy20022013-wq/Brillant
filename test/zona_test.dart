import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/tipo.dart';
import 'package:juego_brilliant/zona.dart';

void main() {
  const zona = Zona(id: 'azul-1', tipo: Tipo.azul, capacidad: 2);

  test('empieza vacía y sin completar', () {
    expect(zona.valores, isEmpty);
    expect(zona.estaCompleta, isFalse);
  });

  test('copyWith cambia solo los valores', () {
    final llena = zona.copyWith(valores: [3, 3]);

    expect(llena.valores, [3, 3]);
    expect(llena.id, 'azul-1');
    expect(llena.tipo, Tipo.azul);
    expect(llena.capacidad, 2);
    expect(llena.estaCompleta, isTrue);
    expect(zona.valores, isEmpty); // la original no cambia
  });

  test('dos zonas con los mismos datos son iguales', () {
    expect(
      zona,
      equals(const Zona(id: 'azul-1', tipo: Tipo.azul, capacidad: 2)),
    );
    expect(zona, isNot(equals(zona.copyWith(valores: [1]))));
  });
}