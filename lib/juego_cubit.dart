import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'juego.dart';

class JuegoEstado extends Equatable {
  final Juego juego;
  final int? dado1;
  final int? dado2;
  final int? indiceAncla; // 0 = el dado 1 es el ancla, 1 = el dado 2
  final int turno;
  final bool terminado;
  final String mensaje;

  const JuegoEstado({
    required this.juego,
    this.dado1,
    this.dado2,
    this.indiceAncla,
    this.turno = 1,
    this.terminado = false,
    this.mensaje = '',
  });

  bool get hayDados => dado1 != null && dado2 != null;

  int? get ancla =>
      indiceAncla == null ? null : (indiceAncla == 0 ? dado1 : dado2);

  int? get aColocar =>
      indiceAncla == null ? null : (indiceAncla == 0 ? dado2 : dado1);

  /// Casillas que se iluminan según el ancla elegida.
  Set<(int, int)> get jugadasResaltadas {
    final a = ancla;
    final b = aColocar;
    if (a == null || b == null) return {};
    return juego.jugadasPosibles(ancla: a, aColocar: b);
  }

  /// true si con estos dados existe al menos una jugada (con cualquiera
  /// de los dos como ancla).
  bool get hayJugadas {
    if (!hayDados) return false;
    return juego
            .jugadasPosibles(ancla: dado1!, aColocar: dado2!)
            .isNotEmpty ||
        juego.jugadasPosibles(ancla: dado2!, aColocar: dado1!).isNotEmpty;
  }

  @override
  List<Object?> get props =>
      [juego, dado1, dado2, indiceAncla, turno, terminado, mensaje];
}

class JuegoCubit extends Cubit<JuegoEstado> {
  final Random _random;

  JuegoCubit({required List<int> iniciales, Random? random})
      : _random = random ?? Random(),
        super(JuegoEstado(juego: Juego.inicial(iniciales)));

  void tirarDados() {
    fijarDados(_random.nextInt(6) + 1, _random.nextInt(6) + 1);
  }

  /// Pone valores concretos en los dados (lo usan tirarDados y las pruebas).
  void fijarDados(int a, int b) {
    if (state.terminado || state.hayDados) return;
    emit(JuegoEstado(
      juego: state.juego,
      dado1: a,
      dado2: b,
      turno: state.turno,
    ));
  }

  void elegirAncla(int indice) {
    if (state.terminado || !state.hayDados) return;
    emit(JuegoEstado(
      juego: state.juego,
      dado1: state.dado1,
      dado2: state.dado2,
      indiceAncla: indice,
      turno: state.turno,
    ));
  }

  void colocar(int fila, int columna) {
    final valor = state.aColocar;
    if (state.terminado || valor == null) return;
    if (!state.jugadasResaltadas.contains((fila, columna))) return;

    final anterior = state.juego;
    final nuevo = anterior.colocar(fila, columna, valor);
    final z = estructuraNivel1.indiceZona[fila][columna];
    final zona = estructuraNivel1.zonas[z];

    var mensaje = '';
    if (nuevo.completadas[z] > anterior.completadas[z]) {
      final ganados = nuevo.puntos[z] - anterior.puntos[z];
      mensaje = ganados > 0
          ? '¡${zona.nombre} completada! +$ganados puntos'
          : '${zona.nombre} completada (ya no puntúa)';
    }

    emit(JuegoEstado(
      juego: nuevo,
      turno: state.turno + 1,
      terminado: nuevo.todasAgotadas,
      mensaje: mensaje,
    ));
  }

  /// Descarta la tirada cuando no hay jugadas posibles.
  void pasarTurno() {
    if (state.terminado || !state.hayDados) return;
    emit(JuegoEstado(
      juego: state.juego,
      turno: state.turno + 1,
      mensaje: 'Pasaste el turno',
    ));
  }

  void terminar() {
    if (state.terminado) return;
    emit(JuegoEstado(
      juego: state.juego,
      dado1: state.dado1,
      dado2: state.dado2,
      indiceAncla: state.indiceAncla,
      turno: state.turno,
      terminado: true,
      mensaje: state.mensaje,
    ));
  }
}