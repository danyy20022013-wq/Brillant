import 'package:reglas_brilliant/reglas_brilliant.dart';
import 'package:test/test.dart';

const _iniciales = [1, 2, 3, 4, 5, 6];

void main() {
  test('dos tableros con los mismos números son iguales', () {
    final a = Juego.inicial(_iniciales).colocar(0, 1, 5);
    final b = Juego.inicial(_iniciales).colocar(0, 1, 5);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('distinto número, casilla o mapa los hace distintos', () {
    final base = Juego.inicial(_iniciales);
    expect(base.colocar(0, 1, 5), isNot(base.colocar(0, 1, 4)));
    expect(base.colocar(0, 1, 5), isNot(base.colocar(0, 3, 5)));
    expect(base, isNot(Juego.inicial(_iniciales, nivel: nivel2)));
  });

  test('colocar no cambia el tablero original', () {
    final base = Juego.inicial(_iniciales);
    base.colocar(0, 1, 5);
    expect(base.tablero[0][1], isNull);
  });

  test('hayJugadaCon prueba los dos dados como ancla', () {
    final juego = Juego.inicial(_iniciales);
    // El 1 está en (0, 2): con 1 y 5 hay jugada usando el 1 de ancla.
    expect(juego.hayJugadaCon(1, 5), isTrue);
    expect(juego.hayJugadaCon(5, 1), isTrue);
  });

  test('sin el número del ancla en el tablero no hay jugada', () {
    var juego = Juego.inicial(_iniciales);
    // Ningún dado es mayor que 6: con 6 y 6 se busca algún 6 en el tablero.
    expect(juego.hayJugadaCon(6, 6), isTrue);
    // Un tablero lleno nunca tiene jugadas.
    for (var f = 0; f < 7; f++) {
      for (var c = 0; c < 7; c++) {
        if (juego.tablero[f][c] == null) juego = juego.colocar(f, c, 1);
      }
    }
    expect(juego.estaLleno, isTrue);
    expect(juego.hayJugadaCon(1, 1), isFalse);
  });

  test('nivelPorNumero encuentra los 4 mapas y null si no existe', () {
    for (final mapa in nivelesDisponibles) {
      expect(nivelPorNumero(mapa.numero), same(mapa));
    }
    expect(nivelPorNumero(0), isNull);
    expect(nivelPorNumero(5), isNull);
  });
}
