import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/juego.dart';
import 'package:juego_brilliant/juego_cubit.dart';
import 'package:juego_brilliant/tipo.dart';

const _iniciales = [1, 2, 3, 4, 5, 6];

/// Un turno completo: dados 1 y 1, el 1 de ancla, y se coloca en (f, c).
void _jugar(JuegoCubit cubit, int f, int c) {
  cubit.fijarDados(1, 1);
  cubit.elegirAncla(0);
  cubit.colocar(f, c);
}

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

    expect(
      juego.jugadasPosibles(ancla: 1, aColocar: 5),
      {(0, 1), (0, 3)},
    );
    expect(
      juego.jugadasPosibles(ancla: 1, aColocar: 1),
      {(0, 1), (0, 3), (1, 2)},
    );
  });

  test('al llenar una zona ya no se vacía', () {
    var juego = Juego.inicial(_iniciales);
    final z = nivel1.estructura.indiceZona[0][2]; // azul 1

    expect(juego.zonaLlena(z), isFalse);
    juego = juego.colocar(1, 2, 1).colocar(1, 3, 1).colocar(2, 3, 1);
    expect(juego.zonaLlena(z), isTrue);
    expect(juego.tablero[1][2], 1);
  });

  test('el puntaje depende del orden en que los jugadores llenan la zona', () {
    final cubit = JuegoCubit(iniciales: List.filled(4, _iniciales));
    final azul1 = nivel1.estructura.indiceZona[0][2];
    final azul2 = nivel1.estructura.indiceZona[4][6];

    // Cada casilla la ponen los 4 jugadores en orden: J1 termina primero,
    // luego J2, J3 y J4.
    for (final (f, c) in [(1, 2), (1, 3), (2, 3)]) {
      for (var p = 0; p < 4; p++) {
        _jugar(cubit, f, c);
      }
    }

    final estado = cubit.state;
    expect(estado.ordenZonas[azul1], [0, 1, 2, 3]);
    expect(estado.puntosEn(0, azul1), 7);
    expect(estado.puntosEn(1, azul1), 5);
    expect(estado.puntosEn(2, azul1), 3);
    expect(estado.puntosEn(3, azul1), 0); // el cuarto ya no puntúa

    // La otra zona azul no se mezcla.
    expect(estado.ordenZonas[azul2], isEmpty);
    expect(estado.puntajeDe(0), 7);
  });

  test('el cubit usa el ancla y solo deja colocar en casillas iluminadas', () {
    final cubit = JuegoCubit(iniciales: [_iniciales, _iniciales]);

    cubit.fijarDados(1, 5);
    cubit.elegirAncla(0); // el 1 es el ancla, se coloca el 5
    expect(cubit.state.ancla, 1);
    expect(cubit.state.aColocar, 5);
    expect(cubit.state.jugadasResaltadas, {(0, 1), (0, 3)});

    cubit.colocar(6, 6); // no está iluminada: se ignora
    expect(cubit.state.tableros[0].tablero[6][6], isNull);

    cubit.colocar(0, 1);
    expect(cubit.state.tableros[0].tablero[0][1], 5);
    expect(cubit.state.tableros[1].tablero[0][1], isNull); // otro tablero
    expect(cubit.state.hayDados, isFalse);
    expect(cubit.state.jugador, 1); // ahora le toca al jugador 2
    expect(cubit.state.turno, 2);
  });

  test('pasar el turno cambia de jugador', () {
    final cubit = JuegoCubit(iniciales: [_iniciales, _iniciales]);
    cubit.fijarDados(6, 6);
    cubit.pasarTurno();
    expect(cubit.state.hayDados, isFalse);
    expect(cubit.state.jugador, 1);
    expect(cubit.state.turno, 2);
  });
}