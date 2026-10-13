import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/juego.dart';
import 'package:juego_brilliant/tablero_layout.dart';
import 'package:juego_brilliant/tipo.dart';

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
        estructuraNivel1.indiceZona[p.fila][p.columna],
    };
    expect(zonas.length, 6);
  });

  test('cada zona tiene el tamaño correcto', () {
    for (final zona in estructuraNivel1.zonas) {
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
    final nombres = estructuraNivel1.zonas.map((z) => z.nombre).toSet();
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

  test('los puntos por llenado de cada color', () {
    expect(puntosDe(Tipo.rojo), [6, 4, 2]);
    expect(puntosDe(Tipo.azul), [7, 5, 3]);
    expect(puntosDe(Tipo.verde), [4, 3, 2]);
    expect(puntosDe(Tipo.amarillo), [8, 6, 4]);
    expect(puntosDe(Tipo.morado), [6, 4, 2]);
  });

  test('estado inicial de Juego', () {
    final juego = Juego.inicial([1, 2, 3, 4, 5, 6]);
    final azul1 = estructuraNivel1.indiceZona[0][2];

    expect(Juego.esSemilla(0, 2), isTrue);
    expect(Juego.esSemilla(0, 0), isFalse);
    expect(juego.valoresDeZona(azul1), [1]);
    expect(juego.puntajeTotal, 0);
    expect(juego.todasAgotadas, isFalse);
  });
}