import 'package:test/test.dart';
import 'package:reglas_brilliant/reglas_brilliant.dart';

const _iniciales = [1, 2, 3, 4, 5, 6];

void main() {
  test('hay 9 zonas: 2 de cada color y 1 amarilla de 5 casillas', () {
    final zonas = nivel1.estructura.zonas;
    int cuantas(bool Function(Tipo) f) => zonas.where((z) => f(z.tipo)).length;

    expect(zonas.length, 9);
    expect(cuantas((t) => t is TipoRojo), 2);
    expect(cuantas((t) => t is TipoAzul), 2);
    expect(cuantas((t) => t is TipoVerde), 2);
    expect(cuantas((t) => t is TipoMorado), 2);
    expect(cuantas((t) => t is TipoAmarillo), 1);

    final amarilla = zonas.firstWhere((z) => z.tipo is TipoAmarillo);
    expect(amarilla.celdas.length, 5);
    expect(zonas.fold<int>(0, (a, z) => a + z.celdas.length), 49);
  });

  test('los números iniciales quedan en las estrellas', () {
    final juego = Juego.inicial(_iniciales);
    expect(juego.tablero[0][2], 1);
    expect(juego.tablero[1][5], 2);
    expect(juego.tablero[6][4], 6);
  });

  test('las jugadas son solo arriba, abajo, izquierda o derecha', () {
    final juego = Juego.inicial(_iniciales);

    expect(juego.jugadasPosibles(ancla: 1, aColocar: 5), {(0, 1), (0, 3)});
    expect(juego.jugadasPosibles(ancla: 1, aColocar: 1), {
      (0, 1),
      (0, 3),
      (1, 2),
    });
  });

  test('al llenar una zona ya no se vacía', () {
    var juego = Juego.inicial(_iniciales);
    final z = nivel1.estructura.indiceZona[0][2]; // azul 1

    expect(juego.zonaLlena(z), isFalse);
    juego = juego.colocar(1, 2, 1).colocar(1, 3, 1).colocar(2, 3, 1);
    expect(juego.zonaLlena(z), isTrue);
    expect(juego.tablero[1][2], 1);
  });
}
