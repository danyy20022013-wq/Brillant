import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/tipo.dart';

/// Tabla de puntos que cada tipo trae para el modelo anterior del tablero
/// (Tablero.puntajeTotal). La partida actual usa los puntos de cada mapa.
void main() {
  test('cada tipo trae su tabla de puntos del modelo anterior', () {
    expect(Tipo.rojo.puntuaciones, {1: 8, 2: 6, 3: 4});
    expect(Tipo.amarillo.puntuaciones, {1: 8, 2: 6, 3: 4});
    expect(Tipo.verde.puntuaciones, {1: 4, 2: 3, 3: 2});
    expect(Tipo.azul.puntuaciones, {1: 10, 2: 8, 3: 6});
    expect(Tipo.morado.puntuaciones, {1: 8, 2: 6, 3: 4});
  });

  test('blanco y naranja no tienen puntos en el modelo anterior', () {
    expect(Tipo.blanco.puntuaciones, isEmpty);
    expect(Tipo.naranja46.puntuaciones, isEmpty);
    expect(Tipo.naranja13.puntuaciones, isEmpty);
  });
}
