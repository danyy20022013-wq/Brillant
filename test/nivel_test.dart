import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/juego.dart';
import 'package:juego_brilliant/tipo.dart';

/// Nombre y cantidad de casillas de cada zona, en orden de aparición.
Map<String, int> _tamanos(Nivel mapa) => {
      for (final z in mapa.estructura.zonas) z.nombre: z.celdas.length,
    };

/// Revisa nombres, tamaños y también el orden de aparición (fila por fila).
void _verificarZonas(Nivel mapa, Map<String, int> esperado) {
  final real = _tamanos(mapa);
  expect(real, esperado);
  expect(real.keys.toList(), esperado.keys.toList());
}

ZonaDef _zona(Nivel mapa, String nombre) =>
    mapa.estructura.zonas.firstWhere((z) => z.nombre == nombre);

ZonaDef _zonaEn(Nivel mapa, int fila, int columna) =>
    mapa.estructura.zonas[mapa.estructura.indiceZona[fila][columna]];

void main() {
  test('hay 4 mapas en orden', () {
    expect(nivelesDisponibles, [nivel1, nivel2, nivel3, nivel4]);
    expect([for (final m in nivelesDisponibles) m.numero], [1, 2, 3, 4]);
  });

  for (final mapa in nivelesDisponibles) {
    group('Mapa ${mapa.numero}', () {
      test('es de 7x7 y las 49 casillas tienen zona', () {
        expect(mapa.layout.length, 7);
        for (final fila in mapa.layout) {
          expect(fila.length, 7);
        }
        final indice = mapa.estructura.indiceZona;
        var casillas = 0;
        for (var f = 0; f < 7; f++) {
          for (var c = 0; c < 7; c++) {
            final z = indice[f][c];
            expect(z, inInclusiveRange(0, mapa.estructura.zonas.length - 1));
            expect(mapa.estructura.zonas[z].celdas, contains((f, c)));
            expect(mapa.estructura.zonas[z].tipo, mapa.layout[f][c]);
          }
        }
        for (final z in mapa.estructura.zonas) {
          casillas += z.celdas.length;
        }
        expect(casillas, 49);
      });

      test('las 6 estrellas van en orden de lectura y en 6 zonas distintas',
          () {
        expect(mapa.estrellas.length, 6);
        for (var i = 1; i < 6; i++) {
          final a = mapa.estrellas[i - 1];
          final b = mapa.estrellas[i];
          expect(a.fila * 7 + a.columna, lessThan(b.fila * 7 + b.columna));
        }
        final zonas = {
          for (final p in mapa.estrellas)
            mapa.estructura.indiceZona[p.fila][p.columna],
        };
        expect(zonas.length, 6);
        for (final p in mapa.estrellas) {
          expect(mapa.esEstrella(p.fila, p.columna), isTrue);
        }
      });

      test('cada zona tiene 3 valores de puntos', () {
        for (final z in mapa.estructura.zonas) {
          expect(z.puntos.length, 3, reason: z.nombre);
        }
      });
    });
  }

  group('Mapa 1', () {
    test('sigue con sus 9 zonas y la estructura de siempre', () {
      expect(identical(estructuraNivel1, nivel1.estructura), isTrue);
      _verificarZonas(nivel1, {
        'Amarillo': 5,
        'Verde 1': 6,
        'Azul 1': 4,
        'Morado 1': 6,
        'Verde 2': 6,
        'Rojo 1': 6,
        'Morado 2': 6,
        'Rojo 2': 6,
        'Azul 2': 4,
      });
    });

    test('puntos por zona', () {
      expect(_zona(nivel1, 'Azul 1').puntos, [7, 5, 3]);
      expect(_zona(nivel1, 'Azul 2').puntos, [7, 5, 3]);
      expect(_zona(nivel1, 'Verde 1').puntos, [4, 3, 2]);
      expect(_zona(nivel1, 'Rojo 2').puntos, [6, 4, 2]);
      expect(_zona(nivel1, 'Morado 1').puntos, [6, 4, 2]);
      expect(_zona(nivel1, 'Amarillo').puntos, [8, 6, 4]);
    });
  });

  group('Mapa 2', () {
    test('10 zonas con sus nombres y tamaños', () {
      _verificarZonas(nivel2, {
        'Morado 1': 5,
        'Blanco': 2,
        'Verde 1': 5,
        'Amarillo': 5,
        'Azul 1': 5,
        'Rojo 1': 6,
        'Rojo 2': 6,
        'Verde 2': 5,
        'Azul 2': 5,
        'Morado 2': 5,
      });
    });

    test('amarillo y blanco separados forman una sola zona', () {
      expect(_zona(nivel2, 'Amarillo').celdas.toSet(),
          {(1, 1), (1, 5), (3, 3), (5, 1), (5, 5)});
      expect(_zona(nivel2, 'Blanco').celdas.toSet(), {(0, 3), (6, 3)});
    });

    test('puntos por zona', () {
      expect(_zona(nivel2, 'Azul 1').puntos, [7, 5, 3]);
      expect(_zona(nivel2, 'Verde 2').puntos, [4, 3, 2]);
      expect(_zona(nivel2, 'Rojo 1').puntos, [6, 4, 2]);
      expect(_zona(nivel2, 'Morado 2').puntos, [6, 4, 2]);
      expect(_zona(nivel2, 'Amarillo').puntos, [6, 4, 2]);
      expect(_zona(nivel2, 'Blanco').puntos, [3, 2, 1]);
    });
  });

  group('Mapa 3', () {
    test('10 zonas con sus nombres y tamaños', () {
      _verificarZonas(nivel3, {
        'Amarillo 1': 3,
        'Morado 1': 6,
        'Blanco': 5,
        'Amarillo 2': 3,
        'Rojo 1': 6,
        'Rojo 2': 6,
        'Verde': 9,
        'Azul': 5,
        'Morado 2': 3,
        'Morado 3': 3,
      });
    });

    test('el blanco separado es una zona; los amarillos son dos', () {
      expect(_zona(nivel3, 'Blanco').celdas.toSet(),
          {(0, 3), (1, 0), (1, 6), (3, 3), (6, 3)});
      expect(_zonaEn(nivel3, 0, 0).nombre, 'Amarillo 1');
      expect(_zonaEn(nivel3, 0, 6).nombre, 'Amarillo 2');
      expect(_zonaEn(nivel3, 0, 2).nombre, 'Morado 1'); // la de arriba
      expect(_zonaEn(nivel3, 6, 0).nombre, 'Morado 2');
      expect(_zonaEn(nivel3, 6, 6).nombre, 'Morado 3');
    });

    test('puntos por zona', () {
      expect(_zona(nivel3, 'Azul').puntos, [7, 5, 3]);
      expect(_zona(nivel3, 'Verde').puntos, [6, 5, 4]);
      expect(_zona(nivel3, 'Rojo 2').puntos, [6, 4, 2]);
      expect(_zona(nivel3, 'Morado 1').puntos, [7, 5, 3]);
      expect(_zona(nivel3, 'Morado 3').puntos, [7, 5, 3]);
      expect(_zona(nivel3, 'Amarillo 1').puntos, [7, 5, 3]);
      expect(_zona(nivel3, 'Amarillo 2').puntos, [7, 5, 3]);
      expect(_zona(nivel3, 'Blanco').puntos, [8, 6, 4]);
    });
  });

  group('Mapa 4', () {
    test('10 zonas con sus nombres y tamaños', () {
      _verificarZonas(nivel4, {
        'Naranja 4-6': 7,
        'Amarillo': 6,
        'Rojo 1': 3,
        'Azul': 6,
        'Verde': 4,
        'Rojo 2': 3,
        'Morado': 7,
        'Rojo 3': 3,
        'Rojo 4': 3,
        'Naranja 1-3': 7,
      });
    });

    test('amarillo, azul y verde separados son una zona cada uno', () {
      expect(_zona(nivel4, 'Amarillo').celdas.toSet(),
          {(1, 0), (1, 6), (3, 0), (3, 6), (5, 0), (5, 6)});
      expect(_zona(nivel4, 'Azul').celdas.toSet(),
          {(1, 2), (1, 4), (3, 2), (3, 4), (5, 2), (5, 4)});
      expect(_zona(nivel4, 'Verde').celdas.toSet(),
          {(1, 3), (3, 1), (3, 5), (5, 3)});
    });

    test('las 4 zonas rojas son distintas', () {
      final rojas = {
        for (final (f, c) in [(2, 0), (2, 6), (4, 0), (4, 6)])
          nivel4.estructura.indiceZona[f][c],
      };
      expect(rojas.length, 4);
    });

    test('las filas naranjas tienen su tipo', () {
      expect(_zona(nivel4, 'Naranja 4-6').tipo, Tipo.naranja46);
      expect(_zona(nivel4, 'Naranja 1-3').tipo, Tipo.naranja13);
    });

    test('puntos por zona', () {
      expect(_zona(nivel4, 'Azul').puntos, [8, 6, 4]);
      expect(_zona(nivel4, 'Verde').puntos, [3, 2, 1]);
      expect(_zona(nivel4, 'Rojo 4').puntos, [6, 4, 2]);
      expect(_zona(nivel4, 'Morado').puntos, [7, 5, 3]);
      expect(_zona(nivel4, 'Amarillo').puntos, [8, 6, 4]);
      expect(_zona(nivel4, 'Naranja 4-6').puntos, [6, 4, 3]);
      expect(_zona(nivel4, 'Naranja 1-3').puntos, [6, 4, 3]);
    });
  });
}
