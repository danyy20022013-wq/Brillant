import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/juego.dart';
import 'package:juego_brilliant/numeros_iniciales_cubit.dart';
import 'package:juego_brilliant/tablero_layout.dart';
import 'package:juego_brilliant/tipo.dart';

/// Mapa de prueba: todo rojo, una sola zona con las 6 estrellas.
/// Sirve para comprobar que se cuentan los demás números de la zona.
final _mapaTodoRojo = Nivel(
  numero: 99,
  layout: List.generate(7, (_) => List.filled(7, Tipo.rojo)),
  estrellas: const [
    PosicionCasilla(0, 0),
    PosicionCasilla(0, 1),
    PosicionCasilla(0, 2),
    PosicionCasilla(0, 3),
    PosicionCasilla(0, 4),
    PosicionCasilla(0, 5),
  ],
  zonaUnica: const {},
  puntos: const {
    Tipo.rojo: [6, 4, 2],
  },
);

NumerosInicialesEstado _estado(List<int?> valores, {Nivel? nivel}) =>
    NumerosInicialesEstado(valores, nivel: nivel);

void main() {
  test('empieza vacío e inválido', () {
    final cubit = NumerosInicialesCubit();
    expect(cubit.state.completo, isFalse);
    expect(cubit.state.esValido, isFalse);
  });

  test('es válido con 6 números distintos', () {
    final cubit = NumerosInicialesCubit();
    for (var i = 0; i < 6; i++) {
      cubit.seleccionar(i, i + 1);
    }
    expect(cubit.state.esValido, isTrue);
  });

  test('detecta números repetidos y marca la casilla', () {
    final cubit = NumerosInicialesCubit();
    cubit.seleccionar(0, 3);
    cubit.seleccionar(1, 3);
    expect(cubit.state.tieneRepetidos, isTrue);
    expect(cubit.state.casillaRepetida(0), isTrue);
    expect(cubit.state.casillaRepetida(2), isFalse);
  });

  test('con repetidos no es válido aunque esté completo', () {
    final cubit = NumerosInicialesCubit();
    for (var i = 0; i < 6; i++) {
      cubit.seleccionar(i, 1);
    }
    expect(cubit.state.completo, isTrue);
    expect(cubit.state.esValido, isFalse);
  });

  group('Regla de la zona (mapa 4)', () {
    // Estrellas en orden de lectura: 0 = naranja 4-6, 1 morado, 2 rojo,
    // 3 amarillo, 4 azul, 5 = naranja 1-3.
    final vacio = NumerosInicialesEstado.vacio(nivel: nivel4);

    test('la estrella naranja de arriba solo acepta del 4 al 6', () {
      expect([for (var n = 1; n <= 6; n++) vacio.esPosible(0, n)],
          [false, false, false, true, true, true]);
      expect(vacio.reglaDe(0), 'Solo números del 4 al 6');
    });

    test('la estrella naranja de abajo solo acepta del 1 al 3', () {
      expect([for (var n = 1; n <= 6; n++) vacio.esPosible(5, n)],
          [true, true, true, false, false, false]);
      expect(vacio.reglaDe(5), 'Solo números del 1 al 3');
    });

    test('las estrellas de otro color aceptan cualquier número', () {
      for (final i in [1, 2, 3, 4]) {
        for (var n = 1; n <= 6; n++) {
          expect(vacio.esPosible(i, n), isTrue, reason: 'estrella $i, $n');
        }
      }
      expect(vacio.reglaDe(1), Tipo.morado.descripcion);
    });

    test('un número fuera de su rango marca la casilla y no es válido', () {
      final estado = _estado([1, 2, 3, 4, 5, 6], nivel: nivel4);

      expect(estado.completo, isTrue);
      expect(estado.tieneRepetidos, isFalse);
      expect(estado.casillaInvalida(0), isTrue); // 1 en el naranja 4-6
      expect(estado.casillaInvalida(5), isTrue); // 6 en el naranja 1-3
      expect(estado.casillaInvalida(1), isFalse);
      expect(estado.tieneInvalidos, isTrue);
      expect(estado.esValido, isFalse);
    });

    test('4, 5, 6, 1, 2, 3 es una combinación válida', () {
      final estado = _estado([4, 5, 6, 1, 2, 3], nivel: nivel4);

      expect(estado.tieneInvalidos, isFalse);
      for (var i = 0; i < 6; i++) {
        expect(estado.casillaInvalida(i), isFalse);
      }
      expect(estado.esValido, isTrue);
    });

    test('una casilla vacía no es inválida', () {
      expect(vacio.casillaInvalida(0), isFalse);
      expect(vacio.tieneInvalidos, isFalse);
    });
  });

  group('Sin mapa no se validan zonas', () {
    test('cualquier número es posible y no hay regla', () {
      final estado = _estado([1, 2, 3, 4, 5, 6]);
      expect(estado.nivel, isNull);
      expect(estado.esPosible(0, 1), isTrue);
      expect(estado.reglaDe(0), isNull);
      expect(estado.tieneInvalidos, isFalse);
      expect(estado.esValido, isTrue);
    });
  });

  group('Se cuentan los demás números de la misma zona', () {
    test('en una zona roja no se puede repetir lo que ya eligió otra estrella',
        () {
      final estado = _estado([3, null, null, null, null, null],
          nivel: _mapaTodoRojo);

      expect(estado.esPosible(1, 3), isFalse);
      expect(estado.esPosible(1, 4), isTrue);
      // La propia estrella no se cuenta a sí misma.
      expect(estado.esPosible(0, 3), isTrue);
    });
  });

  group('Cubit con mapa', () {
    test('empieza vacío con su mapa y lo conserva al elegir', () {
      final cubit = NumerosInicialesCubit(nivel: nivel4);
      expect(cubit.state.nivel, same(nivel4));

      cubit.seleccionar(0, 1);
      expect(cubit.state.nivel, same(nivel4));
      expect(cubit.state.valores[0], 1);
      expect(cubit.state.casillaInvalida(0), isTrue);
    });

    test('con 4, 5, 6, 1, 2, 3 habilita Inicio; con 1 al 6 no', () {
      final valido = NumerosInicialesCubit(nivel: nivel4);
      final invalido = NumerosInicialesCubit(nivel: nivel4);
      const buenos = [4, 5, 6, 1, 2, 3];
      for (var i = 0; i < 6; i++) {
        valido.seleccionar(i, buenos[i]);
        invalido.seleccionar(i, i + 1);
      }
      expect(valido.state.esValido, isTrue);
      expect(invalido.state.esValido, isFalse);
    });

    test('quitar el número inválido deja de marcarlo', () {
      final cubit = NumerosInicialesCubit(nivel: nivel4);
      cubit.seleccionar(5, 6);
      expect(cubit.state.tieneInvalidos, isTrue);

      cubit.seleccionar(5, null);
      expect(cubit.state.tieneInvalidos, isFalse);
    });
  });
}