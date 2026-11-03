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
    expect(Tipo.azul.descripcion, 'Todos los números deben ser iguales');
  });

  test('Blanco acepta si todos son iguales', () {
    const blanco = TipoBlanco();
    expect(blanco.esPosibleAgregar([], 3), isTrue);
    expect(blanco.esPosibleAgregar([3, 3], 3), isTrue);
    expect(blanco.esPosibleAgregar([3, 3], 2), isFalse);
    expect(Tipo.blanco.descripcion, 'Todos los números deben ser iguales (blanco)');
  });

  test('Naranja 4-6 solo acepta del 4 al 6, aunque se repitan', () {
    const naranja = Tipo.naranja46;
    for (final n in [4, 5, 6]) {
      expect(naranja.esPosibleAgregar([], n), isTrue, reason: '$n');
    }
    expect(naranja.esPosibleAgregar([5, 5], 5), isTrue);
    for (final n in [1, 2, 3]) {
      expect(naranja.esPosibleAgregar([4], n), isFalse, reason: '$n');
    }
    expect(naranja.descripcion, 'Solo números del 4 al 6');
  });

  test('Naranja 1-3 solo acepta del 1 al 3, aunque se repitan', () {
    const naranja = Tipo.naranja13;
    for (final n in [1, 2, 3]) {
      expect(naranja.esPosibleAgregar([], n), isTrue, reason: '$n');
    }
    expect(naranja.esPosibleAgregar([2, 2], 2), isTrue);
    for (final n in [4, 5, 6]) {
      expect(naranja.esPosibleAgregar([1], n), isFalse, reason: '$n');
    }
    expect(naranja.descripcion, 'Solo números del 1 al 3');
  });

  test('Los naranjas guardan su rango', () {
    final n46 = Tipo.naranja46 as TipoNaranja;
    final n13 = Tipo.naranja13 as TipoNaranja;
    expect((n46.minimo, n46.maximo), (4, 6));
    expect((n13.minimo, n13.maximo), (1, 3));
  });

  test('Los dos naranjas comparten color y los colores son todos distintos',
      () {
    expect(Tipo.naranja46.color, Tipo.naranja13.color);
    final colores = [
      Tipo.rojo,
      Tipo.amarillo,
      Tipo.verde,
      Tipo.azul,
      Tipo.morado,
      Tipo.blanco,
      Tipo.naranja46,
    ].map((t) => t.color).toSet();
    expect(colores.length, 7);
  });
}