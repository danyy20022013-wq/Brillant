import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:reglas_brilliant/reglas_brilliant.dart';

import 'movimiento_registrado.dart';

export 'movimiento_registrado.dart';

/// Evento: un jugador acaba de completar una zona. Viaja en el estado solo
/// en la jugada que la completó (la siguiente acción lo limpia).
class ZonaCompletada extends Equatable {
  /// Índice de la zona en la estructura del mapa.
  final int zona;
  final String nombre;
  final Tipo tipo;

  /// Jugador que la completó (0 = el primero).
  final int jugador;

  /// Lugar en que la completó (0 = 1.º, 1 = 2.º...).
  final int lugar;

  /// Puntos ganados; 0 si ya no puntúa (4.º jugador o más).
  final int puntos;

  /// Turno de la jugada, para distinguir dos avisos iguales seguidos.
  final int turno;

  const ZonaCompletada({
    required this.zona,
    required this.nombre,
    required this.tipo,
    required this.jugador,
    required this.lugar,
    required this.puntos,
    required this.turno,
  });

  bool get puntua => puntos > 0;

  @override
  List<Object?> get props =>
      [zona, nombre, tipo, jugador, lugar, puntos, turno];
}

class JuegoEstado extends Equatable {
  /// Un tablero por jugador.
  final List<Juego> tableros;

  /// Por cada zona, los jugadores que la completaron, en orden.
  final List<List<int>> ordenZonas;

  final int jugador; // jugador al que le toca
  final int? dado1;
  final int? dado2;
  final int? indiceAncla; // 0 = el dado 1 es el ancla, 1 = el dado 2
  final int turno;
  final bool terminado;
  final String mensaje;

  /// La zona que se completó en la última jugada (null si ninguna).
  final ZonaCompletada? zonaCompletada;

  /// Todos los movimientos de la partida, del más antiguo al más reciente.
  /// Es una lista inmutable; cada partida empieza con un cubit nuevo.
  final List<MovimientoRegistrado> historial;

  final Nivel? _nivel;

  /// Mapa de la partida (por defecto el 1).
  Nivel get nivel => _nivel ?? nivel1;

  const JuegoEstado({
    required this.tableros,
    required this.ordenZonas,
    Nivel? nivel,
    this.jugador = 0,
    this.dado1,
    this.dado2,
    this.indiceAncla,
    this.turno = 1,
    this.terminado = false,
    this.mensaje = '',
    this.zonaCompletada,
    this.historial = const [],
  }) : _nivel = nivel;

  Juego get juego => tableros[jugador];
  int get totalJugadores => tableros.length;
  bool get esIndividual => tableros.length == 1;
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

  /// true si con estos dados hay al menos una jugada.
  bool get hayJugadas {
    if (!hayDados) return false;
    return juego.hayJugadaCon(dado1!, dado2!);
  }

  /// Puntos que [jugadorIdx] obtuvo en la zona [zona], según el lugar
  /// en que la completó.
  int puntosEn(int jugadorIdx, int zona) =>
      puntosEnZona(nivel.estructura, ordenZonas, jugadorIdx, zona);

  int puntajeDe(int jugadorIdx) =>
      puntajeTotal(nivel.estructura, ordenZonas, jugadorIdx);

  /// Copia el estado. Los dados, el ancla, el mensaje y la zona completada
  /// NO se conservan salvo que se pasen.
  JuegoEstado copiar({
    List<Juego>? tableros,
    List<List<int>>? ordenZonas,
    int? jugador,
    int? dado1,
    int? dado2,
    int? indiceAncla,
    int? turno,
    bool? terminado,
    String? mensaje,
    ZonaCompletada? zonaCompletada,
    List<MovimientoRegistrado>? historial,
  }) {
    return JuegoEstado(
      tableros: tableros ?? this.tableros,
      ordenZonas: ordenZonas ?? this.ordenZonas,
      nivel: nivel,
      jugador: jugador ?? this.jugador,
      dado1: dado1,
      dado2: dado2,
      indiceAncla: indiceAncla,
      turno: turno ?? this.turno,
      terminado: terminado ?? this.terminado,
      mensaje: mensaje ?? '',
      zonaCompletada: zonaCompletada,
      historial: historial ?? this.historial,
    );
  }

  /// Historial nuevo (inmutable) con [movimiento] al final.
  List<MovimientoRegistrado> conMovimiento(MovimientoRegistrado movimiento) =>
      List.unmodifiable([...historial, movimiento]);

  @override
  List<Object?> get props => [
        tableros,
        nivel.numero,
        ordenZonas,
        jugador,
        dado1,
        dado2,
        indiceAncla,
        turno,
        terminado,
        mensaje,
        zonaCompletada,
        historial,
      ];
}

class JuegoCubit extends Cubit<JuegoEstado> {
  final Random _random;

  /// [iniciales] trae los 6 números iniciales de cada jugador.
  /// [nivel] es el mapa que se juega (por defecto el 1).
  JuegoCubit({
    required List<List<int>> iniciales,
    Nivel? nivel,
    Random? random,
  }) : this._(iniciales, nivel ?? nivel1, random);

  JuegoCubit._(List<List<int>> iniciales, Nivel mapa, Random? random)
      : _random = random ?? Random(),
        super(JuegoEstado(
          tableros: [
            for (final i in iniciales) Juego.inicial(i, nivel: mapa),
          ],
          ordenZonas: List.generate(
            mapa.estructura.zonas.length,
            (_) => <int>[],
          ),
          nivel: mapa,
        ));

  void tirarDados() {
    fijarDados(_random.nextInt(6) + 1, _random.nextInt(6) + 1);
  }

  /// Pone valores concretos en los dados (lo usan tirarDados y las pruebas).
  void fijarDados(int a, int b) {
    if (state.terminado || state.hayDados) return;
    emit(state.copiar(dado1: a, dado2: b));
  }

  void elegirAncla(int indice) {
    if (state.terminado || !state.hayDados) return;
    emit(state.copiar(
      dado1: state.dado1,
      dado2: state.dado2,
      indiceAncla: indice,
    ));
  }

  /// Siguiente jugador que todavía tiene espacio en su tablero,
  /// o null si todos los tableros están llenos.
  int? _siguiente(int actual, List<Juego> tableros) {
    final n = tableros.length;
    for (var i = 1; i <= n; i++) {
      final idx = (actual + i) % n;
      if (!tableros[idx].estaLleno) return idx;
    }
    return null;
  }

  void colocar(int fila, int columna) {
    final valor = state.aColocar;
    if (state.terminado || valor == null) return;
    if (!state.jugadasResaltadas.contains((fila, columna))) return;

    final j = state.jugador;
    final antes = state.tableros[j];
    final despues = antes.colocar(fila, columna, valor);

    final orden = [for (final o in state.ordenZonas) [...o]];
    var mensaje = '';
    ZonaCompletada? evento;
    final estructura = state.nivel.estructura;
    final z = estructura.indiceZona[fila][columna];
    if (!antes.zonaLlena(z) && despues.zonaLlena(z)) {
      orden[z].add(j);
      final lugar = orden[z].length - 1;
      final puntos = puntosPorLugar(estructura.zonas[z].puntos, lugar);
      final nombre = estructura.zonas[z].nombre;
      final quien = state.esIndividual ? 'Completaste' : 'J${j + 1} completó';
      mensaje = puntos > 0
          ? '$quien $nombre: +$puntos puntos'
          : '$quien $nombre (ya no puntúa)';
      evento = ZonaCompletada(
        zona: z,
        nombre: nombre,
        tipo: estructura.zonas[z].tipo,
        jugador: j,
        lugar: lugar,
        puntos: puntos,
        turno: state.turno,
      );
    }

    final tableros = [...state.tableros];
    tableros[j] = despues;
    final siguiente = _siguiente(j, tableros);

    emit(state.copiar(
      tableros: tableros,
      ordenZonas: orden,
      jugador: siguiente ?? j,
      turno: state.turno + 1,
      terminado: siguiente == null,
      mensaje: mensaje,
      zonaCompletada: evento,
      historial: state.conMovimiento(MovimientoRegistrado.colocacion(
        turno: state.turno,
        jugador: j,
        ancla: state.ancla!,
        colocado: valor,
        fila: fila,
        columna: columna,
        zona: estructura.zonas[z].nombre,
      )),
    ));
  }

  /// Descarta la tirada y le pasa el turno al siguiente jugador.
  void pasarTurno() {
    if (state.terminado || !state.hayDados) return;
    final siguiente = _siguiente(state.jugador, state.tableros);
    emit(state.copiar(
      jugador: siguiente ?? state.jugador,
      turno: state.turno + 1,
      mensaje: state.esIndividual
          ? 'Saltaste el turno'
          : 'J${state.jugador + 1} saltó el turno',
      historial: state.conMovimiento(MovimientoRegistrado.salto(
        turno: state.turno,
        jugador: state.jugador,
      )),
    ));
  }

  void terminar() {
    if (state.terminado) return;
    emit(state.copiar(
      dado1: state.dado1,
      dado2: state.dado2,
      indiceAncla: state.indiceAncla,
      terminado: true,
      mensaje: state.mensaje,
    ));
  }
}