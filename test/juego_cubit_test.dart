import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/tipo.dart';
import 'package:juego_brilliant/juego_cubit.dart';

const _iniciales = [1, 2, 3, 4, 5, 6];

/// Un turno: dados 1 y 1, el 1 es el ancla y se coloca en (f, c).
void _jugar(JuegoCubit cubit, int f, int c) {
  cubit.fijarDados(1, 1);
  cubit.elegirAncla(0);
  cubit.colocar(f, c);
}

JuegoCubit _individual() => JuegoCubit(iniciales: [_iniciales]);

void main() {
  test('tirarDados deja dos valores entre 1 y 6', () {
    final cubit = _individual();
    cubit.tirarDados();

    expect(cubit.state.hayDados, isTrue);
    expect(cubit.state.dado1, inInclusiveRange(1, 6));
    expect(cubit.state.dado2, inInclusiveRange(1, 6));
  });

  test('no se pueden tirar los dados dos veces en el mismo turno', () {
    final cubit = _individual();
    cubit.fijarDados(1, 5);
    cubit.fijarDados(2, 3);

    expect(cubit.state.dado1, 1);
    expect(cubit.state.dado2, 5);
  });

  test('sin dados no se puede elegir ancla', () {
    final cubit = _individual();
    cubit.elegirAncla(0);

    expect(cubit.state.indiceAncla, isNull);
  });

  test('sin ancla no se puede colocar ningún número', () {
    final cubit = _individual();
    cubit.fijarDados(1, 5);
    cubit.colocar(0, 1);

    expect(cubit.state.juego.tablero[0][1], isNull);
    expect(cubit.state.hayDados, isTrue);
  });

  test('al elegir ancla el otro dado es el que se coloca', () {
    final cubit = _individual();
    cubit.fijarDados(1, 5);

    cubit.elegirAncla(1); // ahora el 5 es el ancla
    expect(cubit.state.ancla, 5);
    expect(cubit.state.aColocar, 1);
  });

  test('en modo individual eres el primero en llenar cada zona', () {
    final cubit = _individual();
    final azul1 = nivel1.estructura.indiceZona[0][2];

    _jugar(cubit, 1, 2);
    _jugar(cubit, 1, 3);
    expect(cubit.state.puntajeDe(0), 0); // aún no se llena
    _jugar(cubit, 2, 3);

    expect(cubit.state.ordenZonas[azul1], [0]);
    expect(cubit.state.puntosEn(0, azul1), 7);
    expect(cubit.state.puntajeDe(0), 7);
    expect(cubit.state.mensaje, contains('+7'));
    expect(cubit.state.terminado, isFalse);
    expect(cubit.state.jugador, 0);
  });

  test('una zona llena no se vacía', () {
    final cubit = _individual();

    _jugar(cubit, 1, 2);
    _jugar(cubit, 1, 3);
    _jugar(cubit, 2, 3);

    final tablero = cubit.state.juego.tablero;
    expect(tablero[1][2], 1);
    expect(tablero[1][3], 1);
    expect(tablero[2][3], 1);
  });

  test('terminar la partida bloquea los dados', () {
    final cubit = _individual();
    cubit.terminar();
    expect(cubit.state.terminado, isTrue);

    cubit.tirarDados();
    expect(cubit.state.hayDados, isFalse);
  });

  test('pasar el turno descarta los dados y avanza el turno', () {
    final cubit = _individual();
    cubit.fijarDados(6, 6);
    cubit.pasarTurno();

    expect(cubit.state.hayDados, isFalse);
    expect(cubit.state.jugador, 0);
    expect(cubit.state.turno, 2);
    expect(cubit.state.mensaje, 'Saltaste el turno');
  });
}
