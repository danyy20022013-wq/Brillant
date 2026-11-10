import 'dart:math';

import 'package:reglas_brilliant/reglas_brilliant.dart';
import 'package:servidor_brilliant/servidor_brilliant.dart';
import 'package:test/test.dart';

/// Pruebas del motor de la partida, sin conexiones.
void main() {
  Partida nueva(int jugadores, {int semilla = 1, Nivel? nivel}) => Partida(
    nivel: nivel ?? nivel1,
    jugadores: [for (var i = 1; i <= jugadores; i++) (i, 'J$i')],
    random: Random(semilla),
  );

  void numeros(Partida p) {
    for (final j in p.jugadores) {
      p.enviarNumeros(j.id, const [1, 2, 3, 4, 5, 6]);
    }
  }

  test('empieza en números y pasa a turnos cuando todos mandan', () {
    final p = nueva(3);
    expect(p.fase, FasePartida.numeros);
    p.enviarNumeros(1, const [1, 2, 3, 4, 5, 6]);
    p.enviarNumeros(2, const [1, 2, 3, 4, 5, 6]);
    expect(p.fase, FasePartida.numeros);
    p.enviarNumeros(3, const [1, 2, 3, 4, 5, 6]);
    expect(p.fase, FasePartida.turnos);
    expect(p.orden.toSet(), {1, 2, 3});
    expect(p.turnoDe, p.orden.first);
    expect(p.numeroTurno, 1);
    expect(p.dado1, inInclusiveRange(1, 6));
    expect(p.dado2, inInclusiveRange(1, 6));
  });

  test('el orden se sortea (no siempre es el de llegada)', () {
    final ordenes = <String>{};
    for (var s = 0; s < 20; s++) {
      final p = nueva(4, semilla: s);
      numeros(p);
      ordenes.add(p.orden.join(','));
    }
    expect(ordenes.length, greaterThan(1));
  });

  test('los dados cambian en cada turno y salen todos los valores', () {
    final p = nueva(2);
    numeros(p);
    final vistos = <int>{};
    for (var i = 0; i < 200; i++) {
      vistos
        ..add(p.dado1!)
        ..add(p.dado2!);
      p.saltar(p.turnoDe!);
    }
    expect(vistos, {1, 2, 3, 4, 5, 6});
  });

  test('acciones en la fase equivocada', () {
    final p = nueva(2);
    expect(
      () => p.saltar(1),
      throwsA(
        isA<ErrorJuego>().having((e) => e.codigo, 'codigo', 'fase_incorrecta'),
      ),
    );
    numeros(p);
    expect(
      () => p.enviarNumeros(1, const [1, 2, 3, 4, 5, 6]),
      throwsA(
        isA<ErrorJuego>().having((e) => e.codigo, 'codigo', 'fase_incorrecta'),
      ),
    );
    expect(
      () => p.saltar(99),
      throwsA(
        isA<ErrorJuego>().having((e) => e.codigo, 'codigo', 'no_en_sala'),
      ),
    );
  });

  test('completar una zona suma puntos según el lugar', () {
    final p = nueva(2);
    numeros(p);
    final id = p.turnoDe!;
    // Prepara el tablero para que la próxima jugada complete el azul 1.
    final azul = p.nivel.estructura.indiceZona[0][2];
    p.jugador(id).tablero = p
        .jugador(id)
        .tablero!
        .colocar(1, 2, 1)
        .colocar(1, 3, 1);
    p.dado1 = 1;
    p.dado2 = 1;
    p.colocar(id, 0, 2, 3);
    expect(p.ordenZonas[azul], [id]);
    expect(p.puntajeDe(id), 7);
    final mov = p.ultimoMovimiento!;
    expect(mov['zonaCompletada'], {
      'zona': azul,
      'nombre': 'Azul 1',
      'lugar': 1,
      'puntos': 7,
    });
  });

  test('empates en el resultado: 1, 1, 3', () {
    final p = nueva(3);
    numeros(p);
    final azul1 = p.nivel.estructura.indiceZona[0][2]; // 7, 5, 3
    final azul2 = p.nivel.estructura.indiceZona[4][6]; // 7, 5, 3
    p.ordenZonas[azul1].addAll([2, 1, 3]); // J2 7, J1 5, J3 3
    p.ordenZonas[azul2].addAll([1, 2]); // J1 7, J2 5
    // J1 = 12, J2 = 12, J3 = 3
    expect(p.resultado().map((x) => (x.id, x.posicion, x.puntaje)), [
      (1, 1, 12),
      (2, 1, 12),
      (3, 3, 3),
    ]);
  });

  test('saltar a mano no cuenta para el abandono', () {
    final p = nueva(2);
    numeros(p);
    for (var i = 0; i < 10; i++) {
      p.saltar(p.turnoDe!);
    }
    expect(p.activos.length, 2);
  });

  test('si nadie puede seguir (tableros llenos) termina', () {
    final p = nueva(2);
    numeros(p);
    for (final j in p.jugadores) {
      var t = j.tablero!;
      for (var f = 0; f < 7; f++) {
        for (var c = 0; c < 7; c++) {
          if (t.tablero[f][c] == null) t = t.colocar(f, c, 1);
        }
      }
      j.tablero = t;
    }
    p.saltar(p.turnoDe!);
    expect(p.fase, FasePartida.terminada);
    expect(p.turnoDe, isNull);
    expect(p.dado1, isNull);
  });

  test('quien llena su tablero ya no recibe turnos', () {
    final p = nueva(3);
    numeros(p);
    final lleno = p.orden[1];
    var t = p.jugador(lleno).tablero!;
    for (var f = 0; f < 7; f++) {
      for (var c = 0; c < 7; c++) {
        if (t.tablero[f][c] == null) t = t.colocar(f, c, 1);
      }
    }
    p.jugador(lleno).tablero = t;
    for (var i = 0; i < 10; i++) {
      expect(p.turnoDe, isNot(lleno));
      p.saltar(p.turnoDe!);
    }
    expect(p.fase, FasePartida.turnos);
  });

  test('abandonar dos veces o tras terminar no hace nada', () {
    final p = nueva(3);
    numeros(p);
    p.abandonar(1);
    final salida = p.jugador(1).salida;
    p.abandonar(1);
    expect(p.jugador(1).salida, salida);
    p.abandonar(2);
    expect(p.fase, FasePartida.terminada);
    p.abandonar(3);
    expect(p.jugador(3).activo, isTrue);
    expect(() => p.rendirse(3), throwsA(isA<ErrorJuego>()));
  });

  test('asignar números al azar no toca los que ya llegaron', () {
    final p = nueva(2, nivel: nivel4);
    p.enviarNumeros(1, const [6, 5, 4, 3, 2, 1]);
    p.asignarNumerosFaltantes();
    expect(p.jugador(1).numeros, [6, 5, 4, 3, 2, 1]);
    expect(numerosInicialesValidos(nivel4, p.jugador(2).numeros!), isTrue);
    expect(p.fase, FasePartida.turnos);
    // Fuera de la fase no hace nada.
    p.asignarNumerosFaltantes();
    expect(p.fase, FasePartida.turnos);
  });
}
