import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/juego.dart';
import 'package:juego_brilliant/juego_cubit.dart';
import 'package:juego_brilliant/tipo.dart';

void main() {
  test('hay 9 zonas: 2 de cada color y 1 amarilla de 5 casillas', () {
    final zonas = estructuraNivel1.zonas;
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
    final juego = Juego.inicial([1, 2, 3, 4, 5, 6]);
    expect(juego.tablero[0][2], 1);
    expect(juego.tablero[1][5], 2);
    expect(juego.tablero[6][4], 6);
  });

  test('las jugadas son solo arriba, abajo, izquierda o derecha', () {
    final juego = Juego.inicial([1, 2, 3, 4, 5, 6]);

    // El 5 junto al 1: el azul no deja (exige iguales), verde y morado sí.
    expect(
      juego.jugadasPosibles(ancla: 1, aColocar: 5),
      {(0, 1), (0, 3)},
    );
    // El 1 junto al 1: ahora el azul sí lo deja.
    expect(
      juego.jugadasPosibles(ancla: 1, aColocar: 1),
      {(0, 1), (0, 3), (1, 2)},
    );
  });

  test('una zona puntúa 7, 5 y 3 en el azul y luego ya no suma', () {
    var juego = Juego.inicial([1, 2, 3, 4, 5, 6]);
    final z = estructuraNivel1.indiceZona[0][2]; // zona azul 1

    void llenar() {
      juego = juego.colocar(1, 2, 1);
      juego = juego.colocar(1, 3, 1);
      juego = juego.colocar(2, 3, 1);
    }

    llenar();
    expect(juego.puntos[z], 7);
    expect(juego.completadas[z], 1);
    expect(juego.tablero[1][2], isNull); // se vació para volver a llenar
    expect(juego.tablero[0][2], 1); // la estrella se conserva

    llenar();
    expect(juego.puntos[z], 12);
    llenar();
    expect(juego.puntos[z], 15);
    llenar();
    expect(juego.puntos[z], 15);
    expect(juego.completadas[z], 4);
  });

  test('las dos zonas del mismo color puntúan por separado', () {
    var juego = Juego.inicial([1, 2, 3, 4, 5, 6]);
    final azul1 = estructuraNivel1.indiceZona[0][2];
    final azul2 = estructuraNivel1.indiceZona[4][6];

    juego = juego.colocar(1, 2, 1);
    juego = juego.colocar(1, 3, 1);
    juego = juego.colocar(2, 3, 1);

    expect(juego.puntos[azul1], 7);
    expect(juego.puntos[azul2], 0);
    expect(juego.puntajeTotal, 7);
  });

  test('el cubit usa el ancla y solo deja colocar en casillas iluminadas', () {
    final cubit = JuegoCubit(iniciales: const [1, 2, 3, 4, 5, 6]);

    cubit.fijarDados(1, 5);
    cubit.elegirAncla(0); // el 1 es el ancla, se coloca el 5
    expect(cubit.state.ancla, 1);
    expect(cubit.state.aColocar, 5);
    expect(cubit.state.jugadasResaltadas, {(0, 1), (0, 3)});

    cubit.colocar(6, 6); // no está iluminada: se ignora
    expect(cubit.state.juego.tablero[6][6], isNull);

    cubit.colocar(0, 1);
    expect(cubit.state.juego.tablero[0][1], 5);
    expect(cubit.state.hayDados, isFalse);
    expect(cubit.state.turno, 2);
  });

  test('se puede pasar el turno', () {
    final cubit = JuegoCubit(iniciales: const [1, 2, 3, 4, 5, 6]);
    cubit.fijarDados(6, 6);
    cubit.pasarTurno();
    expect(cubit.state.hayDados, isFalse);
    expect(cubit.state.turno, 2);
  });
}