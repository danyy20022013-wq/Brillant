import 'package:test/test.dart';
import 'package:reglas_brilliant/reglas_brilliant.dart';

void main() {
  test('el tablero es de 7x7', () {
    expect(layoutTableroNivel1.length, 7);
    for (final fila in layoutTableroNivel1) {
      expect(fila.length, 7);
    }
  });

  test('las 6 estrellas caen en 6 zonas distintas', () {
    expect(casillasEstrella.length, 6);
    final zonas = {
      for (final p in casillasEstrella)
        nivel1.estructura.indiceZona[p.fila][p.columna],
    };
    expect(zonas.length, 6);
  });

  test('cada zona tiene el tamaño correcto', () {
    for (final zona in nivel1.estructura.zonas) {
      if (zona.tipo is TipoAzul) {
        expect(zona.celdas.length, 4, reason: zona.nombre);
      } else if (zona.tipo is TipoAmarillo) {
        expect(zona.celdas.length, 5, reason: zona.nombre);
      } else {
        expect(zona.celdas.length, 6, reason: zona.nombre);
      }
    }
  });

  test('las zonas tienen sus nombres', () {
    final nombres = nivel1.estructura.zonas.map((z) => z.nombre).toSet();
    expect(
      nombres,
      containsAll([
        'Amarillo',
        'Rojo 1',
        'Rojo 2',
        'Azul 1',
        'Azul 2',
        'Verde 1',
        'Verde 2',
        'Morado 1',
        'Morado 2',
      ]),
    );
  });

  test('los puntos por orden de llenado de cada color (datos del mapa 1)', () {
    const esperados = {
      Tipo.rojo: [6, 4, 2],
      Tipo.azul: [7, 5, 3],
      Tipo.verde: [4, 3, 2],
      Tipo.amarillo: [8, 6, 4],
      Tipo.morado: [6, 4, 2],
    };
    for (final zona in nivel1.estructura.zonas) {
      expect(zona.puntos, esperados[zona.tipo], reason: zona.nombre);
    }
  });

  test('si a un mapa le faltan los puntos de un color, avisa', () {
    expect(
      () => EstructuraTablero.desdeLayout(
        layoutTableroNivel1,
        puntos: const {
          Tipo.rojo: [6, 4, 2],
        },
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'mensaje',
          contains('Faltan los puntos de'),
        ),
      ),
    );
  });

  test('estado inicial de Juego', () {
    final juego = Juego.inicial([1, 2, 3, 4, 5, 6]);
    final azul1 = nivel1.estructura.indiceZona[0][2];

    expect(nivel1.esEstrella(0, 2), isTrue);
    expect(nivel1.esEstrella(0, 0), isFalse);
    expect(juego.valoresDeZona(azul1), [1]);
    expect(juego.zonaLlena(azul1), isFalse);
    expect(juego.estaLleno, isFalse);
  });
}
