import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/tipo.dart';
import 'package:juego_brilliant/juego_cubit.dart';

const _iniciales = [1, 2, 3, 4, 5, 6];

/// Un turno: fija los dados, el primero es el ancla y se coloca en (f, c).
void _jugar(JuegoCubit cubit, int ancla, int valor, int f, int c) {
  cubit.fijarDados(ancla, valor);
  cubit.elegirAncla(0);
  cubit.colocar(f, c);
}

void _saltar(JuegoCubit cubit) {
  cubit.fijarDados(1, 1);
  cubit.pasarTurno();
}

void main() {
  group('Texto de un movimiento', () {
    const colocacion = MovimientoRegistrado.colocacion(
      turno: 3,
      jugador: 1,
      ancla: 2,
      colocado: 5,
      fila: 3,
      columna: 2,
      zona: 'Rojo 1',
    );
    const salto = MovimientoRegistrado.salto(turno: 4, jugador: 1);

    test('modo individual', () {
      expect(
        colocacion.texto(individual: true),
        'Turno 3: colocaste un 5 junto a un 2 en la fila 4, columna 3 '
        '(Rojo 1)',
      );
      expect(salto.texto(individual: true), 'Turno 4: saltaste el turno');
    });

    test('varios jugadores', () {
      expect(
        colocacion.texto(individual: false),
        'Turno 3: J2 colocó un 5 junto a un 2 en la fila 4, columna 3 '
        '(Rojo 1)',
      );
      expect(salto.texto(individual: false), 'Turno 4: J2 saltó el turno');
    });

    test('un salto no tiene colocación', () {
      expect(salto.saltado, isTrue);
      expect(salto.ancla, isNull);
      expect(salto.colocado, isNull);
      expect(salto.fila, isNull);
      expect(salto.zona, isNull);
      expect(colocacion.saltado, isFalse);
    });
  });

  group('Registro en el cubit', () {
    test('la partida empieza sin movimientos', () {
      final cubit = JuegoCubit(iniciales: const [_iniciales]);
      expect(cubit.state.historial, isEmpty);
    });

    test('cada colocación guarda turno, jugador, ancla, número, casilla y '
        'zona', () {
      final cubit = JuegoCubit(iniciales: const [_iniciales], nivel: nivel3);
      _jugar(cubit, 2, 4, 0, 5);

      expect(cubit.state.historial, [
        const MovimientoRegistrado.colocacion(
          turno: 1,
          jugador: 0,
          ancla: 2,
          colocado: 4,
          fila: 0,
          columna: 5,
          zona: 'Amarillo 2',
        ),
      ]);
      expect(
        cubit.state.historial.single.texto(individual: true),
        'Turno 1: colocaste un 4 junto a un 2 en la fila 1, columna 6 '
        '(Amarillo 2)',
      );
    });

    test('saltar el turno también se guarda', () {
      final cubit = JuegoCubit(iniciales: const [_iniciales], nivel: nivel3);
      _jugar(cubit, 2, 4, 0, 5);
      _saltar(cubit);

      final historial = cubit.state.historial;
      expect(historial.length, 2);
      expect(historial.last, const MovimientoRegistrado.salto(turno: 2, jugador: 0));
      expect(historial.last.texto(individual: true), 'Turno 2: saltaste el turno');
    });

    test('se guardan en orden, del más antiguo al más reciente', () {
      final cubit = JuegoCubit(iniciales: const [_iniciales], nivel: nivel3);
      _jugar(cubit, 2, 4, 0, 5);
      _saltar(cubit);
      _jugar(cubit, 4, 5, 0, 6);

      expect([for (final m in cubit.state.historial) m.turno], [1, 2, 3]);
      expect(cubit.state.historial.last.zona, 'Amarillo 2');
    });

    test('las jugadas inválidas no se guardan', () {
      final cubit = JuegoCubit(iniciales: const [_iniciales], nivel: nivel3);
      cubit.pasarTurno(); // sin dados
      cubit.fijarDados(2, 4);
      cubit.colocar(0, 5); // sin ancla
      cubit.elegirAncla(0);
      cubit.colocar(6, 6); // casilla no iluminada

      expect(cubit.state.historial, isEmpty);
    });

    test('el historial no se puede modificar desde fuera', () {
      final cubit = JuegoCubit(iniciales: const [_iniciales], nivel: nivel3);
      _jugar(cubit, 2, 4, 0, 5);

      expect(
        () => cubit.state.historial
            .add(const MovimientoRegistrado.salto(turno: 9, jugador: 0)),
        throwsUnsupportedError,
      );
    });

    test('se conserva al tirar dados, elegir ancla y terminar', () {
      final cubit = JuegoCubit(iniciales: const [_iniciales], nivel: nivel3);
      _jugar(cubit, 2, 4, 0, 5);
      cubit.fijarDados(3, 3);
      cubit.elegirAncla(1);
      expect(cubit.state.historial.length, 1);

      cubit.terminar();
      expect(cubit.state.historial.length, 1);
    });

    test('con varios jugadores guarda quién hizo cada movimiento', () {
      final cubit = JuegoCubit(
        iniciales: const [_iniciales, _iniciales],
        nivel: nivel3,
      );
      _jugar(cubit, 2, 4, 0, 5); // J1
      _saltar(cubit); // J2
      _jugar(cubit, 4, 5, 0, 6); // J1

      final textos = [
        for (final m in cubit.state.historial) m.texto(individual: false),
      ];
      expect(textos, [
        'Turno 1: J1 colocó un 4 junto a un 2 en la fila 1, columna 6 '
            '(Amarillo 2)',
        'Turno 2: J2 saltó el turno',
        'Turno 3: J1 colocó un 5 junto a un 4 en la fila 1, columna 7 '
            '(Amarillo 2)',
      ]);
      expect([for (final m in cubit.state.historial) m.jugador], [0, 1, 0]);
    });

    test('cada partida nueva (cubit nuevo) empieza con el historial vacío',
        () {
      final primera = JuegoCubit(iniciales: const [_iniciales], nivel: nivel3);
      _jugar(primera, 2, 4, 0, 5);
      _saltar(primera);
      expect(primera.state.historial.length, 2);

      final segunda = JuegoCubit(iniciales: const [_iniciales], nivel: nivel3);
      expect(segunda.state.historial, isEmpty);
      // La partida anterior no cambia.
      expect(primera.state.historial.length, 2);
    });
  });
}
