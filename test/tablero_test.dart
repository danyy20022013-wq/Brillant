import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/tablero.dart';
import 'package:juego_brilliant/tipo.dart';
import 'package:juego_brilliant/zona.dart';

Tablero crearTablero() => const Tablero(id: 't1', zonas: [
      Zona(id: 'azul', tipo: Tipo.azul, capacidad: 3),
      Zona(id: 'rojo', tipo: Tipo.rojo, capacidad: 2),
    ]);

void main() {
  test('agrega un valor válido a una zona', () {
    final tablero = crearTablero().agregarValor('azul', 4);
    expect(tablero.zonaPorId('azul').valores, [4]);
  });

  test('rechaza un valor que rompe la regla del tipo', () {
    final tablero = crearTablero().agregarValor('rojo', 3).agregarValor('rojo', 3);
    expect(tablero.zonaPorId('rojo').valores, [3]);
  });

  test('no acepta valores si la zona está completa', () {
    final tablero =
        crearTablero().agregarValor('rojo', 1).agregarValor('rojo', 2).agregarValor('rojo', 3);
    expect(tablero.zonaPorId('rojo').valores, [1, 2]);
  });

  test('calcula el puntaje total', () {
    final tablero = crearTablero().agregarValor('azul', 4).agregarValor('rojo', 1);
    // azul con 1 valor = 10, rojo con 1 valor = 8
    expect(tablero.puntajeTotal, 18);
  });

  test('estaCompleto es true cuando todas las zonas se llenan', () {
    var tablero = crearTablero();
    expect(tablero.estaCompleto, isFalse);
    for (final v in [4, 4, 4]) {
      tablero = tablero.agregarValor('azul', v);
    }
    for (final v in [1, 2]) {
      tablero = tablero.agregarValor('rojo', v);
    }
    expect(tablero.estaCompleto, isTrue);
  });
}