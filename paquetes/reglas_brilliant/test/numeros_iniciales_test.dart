import 'dart:math';

import 'package:reglas_brilliant/reglas_brilliant.dart';
import 'package:test/test.dart';

void main() {
  group('numerosInicialesValidos', () {
    test('1 a 6 en orden vale en los mapas 1, 2 y 3', () {
      for (final mapa in [nivel1, nivel2, nivel3]) {
        expect(
          numerosInicialesValidos(mapa, const [1, 2, 3, 4, 5, 6]),
          isTrue,
          reason: 'Mapa ${mapa.numero}',
        );
      }
    });

    test('en el mapa 4 los naranjas exigen su rango', () {
      expect(numerosInicialesValidos(nivel4, const [4, 5, 6, 1, 2, 3]), isTrue);
      // La primera estrella es naranja 4-6: un 1 no vale.
      expect(
        numerosInicialesValidos(nivel4, const [1, 2, 3, 4, 5, 6]),
        isFalse,
      );
    });

    test('rechaza cantidad incorrecta, repetidos y fuera de rango', () {
      expect(numerosInicialesValidos(nivel1, const [1, 2, 3, 4, 5]), isFalse);
      expect(
        numerosInicialesValidos(nivel1, const [1, 2, 3, 4, 5, 6, 1]),
        isFalse,
      );
      expect(
        numerosInicialesValidos(nivel1, const [1, 1, 3, 4, 5, 6]),
        isFalse,
      );
      expect(
        numerosInicialesValidos(nivel1, const [0, 2, 3, 4, 5, 6]),
        isFalse,
      );
      expect(
        numerosInicialesValidos(nivel1, const [7, 2, 3, 4, 5, 6]),
        isFalse,
      );
    });
  });

  group('esPosibleNumeroInicial', () {
    test('mira solo las estrellas de la misma zona', () {
      // Mapa 1: las estrellas 2 y 5 son rojas pero de zonas rojas
      // distintas, así que un mismo número no rompe la regla del rojo
      // (los repetidos los rechaza numerosInicialesValidos aparte).
      final valores = <int?>[null, null, 3, null, null, 3];
      expect(esPosibleNumeroInicial(nivel1, valores, 2, 3), isTrue);
      expect(esPosibleNumeroInicial(nivel1, valores, 5, 3), isTrue);
      expect(
        numerosInicialesValidos(nivel1, const [1, 2, 3, 4, 5, 3]),
        isFalse,
      );
    });

    test('con casillas vacías no hay con qué comparar', () {
      final vacias = List<int?>.filled(6, null);
      for (var i = 0; i < 6; i++) {
        expect(esPosibleNumeroInicial(nivel1, vacias, i, 3), isTrue);
      }
    });

    test('en el mapa 4 el naranja 1-3 rechaza un 5', () {
      final vacias = List<int?>.filled(6, null);
      expect(esPosibleNumeroInicial(nivel4, vacias, 5, 5), isFalse);
      expect(esPosibleNumeroInicial(nivel4, vacias, 5, 2), isTrue);
    });
  });

  group('al azar', () {
    for (final mapa in nivelesDisponibles) {
      test('el mapa ${mapa.numero} tiene combinaciones y todas valen', () {
        final todas = combinacionesIniciales(mapa);
        expect(todas, isNotEmpty);
        for (final c in todas) {
          expect(numerosInicialesValidos(mapa, c), isTrue, reason: '$c');
        }
      });
    }

    test('numerosInicialesAlAzar siempre da una combinación válida', () {
      final random = Random(7);
      for (final mapa in nivelesDisponibles) {
        for (var i = 0; i < 20; i++) {
          final n = numerosInicialesAlAzar(mapa, random);
          expect(numerosInicialesValidos(mapa, n), isTrue);
        }
      }
    });
  });
}
