import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/juego.dart';
import 'package:juego_brilliant/juego_cubit.dart';
import 'package:juego_brilliant/tipo.dart';

const _iniciales = [1, 2, 3, 4, 5, 6];

/// Un turno: fija los dados, el primero es el ancla y se coloca en (f, c).
void _jugar(JuegoCubit cubit, int ancla, int valor, int f, int c) {
  cubit.fijarDados(ancla, valor);
  cubit.elegirAncla(0);
  cubit.colocar(f, c);
}

/// Juega solo (siempre la primera jugada posible) hasta llenar el tablero
/// y devuelve todos los eventos de zona completada.
List<ZonaCompletada> _jugarHastaElFinal(JuegoCubit cubit) {
  final eventos = <ZonaCompletada>[];
  for (var turno = 0; turno < 200 && !cubit.state.terminado; turno++) {
    (int, int, (int, int))? jugada;
    for (var a = 1; a <= 6 && jugada == null; a++) {
      for (var b = 1; b <= 6 && jugada == null; b++) {
        final posibles =
            cubit.state.juego.jugadasPosibles(ancla: a, aColocar: b);
        if (posibles.isNotEmpty) jugada = (a, b, posibles.first);
      }
    }
    if (jugada == null) break;
    final (a, b, (f, c)) = jugada;
    _jugar(cubit, a, b, f, c);
    final evento = cubit.state.zonaCompletada;
    if (evento != null) eventos.add(evento);
  }
  return eventos;
}

void main() {
  test('al empezar no hay zona completada', () {
    final cubit = JuegoCubit(iniciales: const [_iniciales], nivel: nivel3);
    expect(cubit.state.zonaCompletada, isNull);
  });

  test('una jugada que no completa zona no emite el evento', () {
    final cubit = JuegoCubit(iniciales: const [_iniciales], nivel: nivel3);
    _jugar(cubit, 2, 4, 0, 5);
    expect(cubit.state.zonaCompletada, isNull);
  });

  test('completar Amarillo 2 del mapa 3 emite el evento con +7', () {
    final cubit = JuegoCubit(iniciales: const [_iniciales], nivel: nivel3);
    _jugar(cubit, 2, 4, 0, 5);
    _jugar(cubit, 4, 5, 0, 6);

    final evento = cubit.state.zonaCompletada!;
    expect(evento.nombre, 'Amarillo 2');
    expect(evento.tipo, Tipo.amarillo);
    expect(evento.zona, nivel3.estructura.indiceZona[0][6]);
    expect(evento.jugador, 0);
    expect(evento.lugar, 0);
    expect(evento.puntos, 7);
    expect(evento.puntua, isTrue);
    expect(evento.turno, 2);
    // Se conserva la línea de texto junto a los dados.
    expect(cubit.state.mensaje, 'Completaste Amarillo 2: +7 puntos');
  });

  test('la siguiente acción limpia el evento', () {
    final cubit = JuegoCubit(iniciales: const [_iniciales], nivel: nivel3);
    _jugar(cubit, 2, 4, 0, 5);
    _jugar(cubit, 4, 5, 0, 6);
    expect(cubit.state.zonaCompletada, isNotNull);

    cubit.fijarDados(1, 1);
    expect(cubit.state.zonaCompletada, isNull);
  });

  test('con 4 jugadores: 7, 5, 3 y el 4.º ya no puntúa', () {
    final cubit = JuegoCubit(
      iniciales: List.filled(4, _iniciales),
      nivel: nivel3,
    );
    for (var j = 0; j < 4; j++) {
      _jugar(cubit, 2, 4, 0, 5);
    }
    final eventos = <ZonaCompletada>[];
    for (var j = 0; j < 4; j++) {
      _jugar(cubit, 4, 5, 0, 6);
      eventos.add(cubit.state.zonaCompletada!);
    }

    expect([for (final e in eventos) e.jugador], [0, 1, 2, 3]);
    expect([for (final e in eventos) e.lugar], [0, 1, 2, 3]);
    expect([for (final e in eventos) e.puntos], [7, 5, 3, 0]);
    expect([for (final e in eventos) e.puntua], [true, true, true, false]);
    // Dos avisos de la misma zona son distintos (turnos distintos).
    expect(eventos.toSet().length, 4);
  });

  test('mapa 4: completar Rojo 2 emite +6 con tipo rojo', () {
    final cubit = JuegoCubit(
      iniciales: const [
        [5, 1, 3, 4, 6, 2],
      ],
      nivel: nivel4,
    );
    _jugar(cubit, 3, 1, 1, 5);
    _jugar(cubit, 3, 2, 2, 6);

    final evento = cubit.state.zonaCompletada!;
    expect(evento.nombre, 'Rojo 2');
    expect(evento.tipo, Tipo.rojo);
    expect(evento.puntos, 6);
  });

  for (final mapa in nivelesDisponibles) {
    test('mapa ${mapa.numero}: cada evento trae nombre, tipo y puntos de '
        'su zona', () {
      final cubit = JuegoCubit(iniciales: const [_iniciales], nivel: mapa);
      final eventos = _jugarHastaElFinal(cubit);

      expect(eventos, isNotEmpty);
      for (final e in eventos) {
        final zona = mapa.estructura.zonas[e.zona];
        expect(e.nombre, zona.nombre);
        expect(e.tipo, zona.tipo);
        // En modo individual siempre eres el primero.
        expect(e.lugar, 0, reason: zona.nombre);
        expect(e.puntos, zona.puntos.first, reason: zona.nombre);
        expect(cubit.state.ordenZonas[e.zona], [0]);
      }
      // Ninguna zona se completa dos veces.
      expect({for (final e in eventos) e.zona}.length, eventos.length);
    });
  }
}
