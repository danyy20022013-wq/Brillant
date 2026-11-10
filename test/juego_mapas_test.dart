import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/tipo.dart';
import 'package:juego_brilliant/juego_cubit.dart';

/// Un turno: fija los dados, el primero es el ancla y se coloca en (f, c).
void _jugar(JuegoCubit cubit, int ancla, int valor, int f, int c) {
  cubit.fijarDados(ancla, valor);
  cubit.elegirAncla(0);
  cubit.colocar(f, c);
}

int _zonaEn(Nivel mapa, int f, int c) => mapa.estructura.indiceZona[f][c];

void main() {
  group('El juego usa el mapa elegido', () {
    test('sin mapa se juega el mapa 1', () {
      final cubit = JuegoCubit(iniciales: const [
        [1, 2, 3, 4, 5, 6],
      ]);
      expect(cubit.state.nivel, same(nivel1));
      expect(cubit.state.juego.nivel, same(nivel1));
      expect(cubit.state.ordenZonas.length, 9);
    });

    for (final mapa in nivelesDisponibles) {
      test('mapa ${mapa.numero}: los números iniciales van a sus estrellas',
          () {
        final cubit = JuegoCubit(
          iniciales: const [
            [1, 2, 3, 4, 5, 6],
          ],
          nivel: mapa,
        );
        final juego = cubit.state.juego;

        expect(cubit.state.nivel, same(mapa));
        expect(juego.nivel, same(mapa));
        expect(cubit.state.ordenZonas.length, mapa.estructura.zonas.length);
        for (var i = 0; i < 6; i++) {
          final p = mapa.estrellas[i];
          expect(juego.tablero[p.fila][p.columna], i + 1);
        }
        var ocupadas = 0;
        for (final fila in juego.tablero) {
          ocupadas += fila.whereType<int>().length;
        }
        expect(ocupadas, 6);
      });
    }
  });

  group('Mapa 2', () {
    // Estrellas: (0,4)=1 verde, ..., (6,4)=6 morado.
    final inicial = Juego.inicial(const [1, 2, 3, 4, 5, 6], nivel: nivel2);

    test('el blanco de arriba y el de abajo son la misma zona', () {
      // Sin nada en el blanco, abajo se puede poner cualquier número.
      expect(inicial.jugadasPosibles(ancla: 6, aColocar: 2), contains((6, 3)));

      // Con un 3 arriba, abajo solo cabe otro 3.
      final conTres = inicial.colocar(0, 3, 3);
      expect(conTres.jugadasPosibles(ancla: 6, aColocar: 3), contains((6, 3)));
      expect(
        conTres.jugadasPosibles(ancla: 6, aColocar: 2),
        isNot(contains((6, 3))),
      );
    });
  });

  group('Mapa 3', () {
    // (1,5) es la estrella de Amarillo 2 y recibe el 2.
    const iniciales = [1, 2, 3, 4, 5, 6];
    final amarillo2 = _zonaEn(nivel3, 0, 6);

    test('llenar Amarillo 2 da los puntos del mapa 3 (+7, no +8)', () {
      final cubit = JuegoCubit(iniciales: const [iniciales], nivel: nivel3);

      _jugar(cubit, 2, 4, 0, 5);
      expect(cubit.state.juego.tablero[0][5], 4);
      expect(cubit.state.puntajeDe(0), 0);

      _jugar(cubit, 4, 5, 0, 6);
      expect(cubit.state.juego.zonaLlena(amarillo2), isTrue);
      expect(cubit.state.puntosEn(0, amarillo2), 7);
      expect(cubit.state.puntajeDe(0), 7);
      expect(cubit.state.mensaje, 'Completaste Amarillo 2: +7 puntos');
    });

    test('con 4 jugadores el orden de llenado da 7, 5, 3 y 0', () {
      final cubit = JuegoCubit(
        iniciales: List.filled(4, iniciales),
        nivel: nivel3,
      );

      for (var j = 0; j < 4; j++) {
        _jugar(cubit, 2, 4, 0, 5);
      }
      final avisos = <String>[];
      for (var j = 0; j < 4; j++) {
        _jugar(cubit, 4, 5, 0, 6);
        avisos.add(cubit.state.mensaje);
      }

      final estado = cubit.state;
      expect(estado.ordenZonas[amarillo2], [0, 1, 2, 3]);
      expect(
        [for (var j = 0; j < 4; j++) estado.puntosEn(j, amarillo2)],
        [7, 5, 3, 0],
      );
      expect(avisos, [
        'J1 completó Amarillo 2: +7 puntos',
        'J2 completó Amarillo 2: +5 puntos',
        'J3 completó Amarillo 2: +3 puntos',
        'J4 completó Amarillo 2 (ya no puntúa)',
      ]);
    });
  });

  group('Mapa 4', () {
    // Estrellas: (0,4)=5 naranja 4-6, (5,4)=6 azul, (6,1)=2 naranja 1-3.
    final inicial = Juego.inicial(const [5, 1, 3, 4, 6, 2], nivel: nivel4);

    test('el naranja de arriba solo acepta del 4 al 6', () {
      expect(inicial.jugadasPosibles(ancla: 5, aColocar: 1), isEmpty);
      expect(
        inicial.jugadasPosibles(ancla: 5, aColocar: 4),
        {(0, 3), (0, 5)},
      );
    });

    test('el naranja de abajo solo acepta del 1 al 3', () {
      expect(
        inicial.jugadasPosibles(ancla: 2, aColocar: 3),
        {(6, 0), (6, 2), (5, 1)},
      );
      // El 5 no entra en el naranja; solo en el rojo de arriba.
      expect(inicial.jugadasPosibles(ancla: 2, aColocar: 5), {(5, 1)});
    });

    test('el azul separado es una sola zona: debe repetir el 6', () {
      // (1,4) es azul y está pegado a la estrella (0,4)=5.
      expect(
        inicial.jugadasPosibles(ancla: 5, aColocar: 6),
        containsAll([(0, 3), (0, 5), (1, 4)]),
      );
      expect(
        inicial.jugadasPosibles(ancla: 5, aColocar: 4),
        isNot(contains((1, 4))),
      );
    });

    test('llenar una zona roja da los puntos del rojo en el mapa 4', () {
      // Rojo 2: (1,5), (2,5) estrella con 3, (2,6).
      final cubit = JuegoCubit(
        iniciales: const [
          [5, 1, 3, 4, 6, 2],
        ],
        nivel: nivel4,
      );
      final rojo2 = _zonaEn(nivel4, 2, 5);

      _jugar(cubit, 3, 1, 1, 5);
      _jugar(cubit, 3, 2, 2, 6);

      expect(cubit.state.juego.zonaLlena(rojo2), isTrue);
      expect(cubit.state.puntosEn(0, rojo2), 6);
      expect(cubit.state.mensaje, 'Completaste Rojo 2: +6 puntos');
    });
  });
}
