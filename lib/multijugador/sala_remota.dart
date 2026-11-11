import 'package:equatable/equatable.dart';
import 'package:reglas_brilliant/reglas_brilliant.dart';

/// Lo que el servidor dice de un jugador. La app no inventa nada: solo
/// lee el estado que difunde el servidor (ver servidor/README.md).
class JugadorRemoto extends Equatable {
  final int id;
  final String nombre;
  final bool anfitrion;
  final bool listo;
  final bool enSala;
  final bool conectado;

  /// "jugando", "rendido" o "abandono" (null en el lobby).
  final String? estado;
  final bool numerosEnviados;
  final List<List<int?>>? tablero;
  final int puntaje;
  final int saltosPorTiempo;

  const JugadorRemoto({
    required this.id,
    required this.nombre,
    this.anfitrion = false,
    this.listo = false,
    this.enSala = true,
    this.conectado = true,
    this.estado,
    this.numerosEnviados = false,
    this.tablero,
    this.puntaje = 0,
    this.saltosPorTiempo = 0,
  });

  bool get rendido => estado == 'rendido';
  bool get abandono => estado == 'abandono';
  bool get sigueJugando => estado == null || estado == 'jugando';

  factory JugadorRemoto.desdeJson(Map<String, Object?> j) => JugadorRemoto(
    id: _entero(j['id']),
    nombre: j['nombre'] as String? ?? '',
    anfitrion: j['anfitrion'] == true,
    listo: j['listo'] == true,
    enSala: j['enSala'] != false,
    conectado: j['conectado'] == true,
    estado: j['estado'] as String?,
    numerosEnviados: j['numerosEnviados'] == true,
    tablero: _tablero(j['tablero']),
    puntaje: _entero(j['puntaje']),
    saltosPorTiempo: _entero(j['saltosPorTiempo']),
  );

  @override
  List<Object?> get props => [
    id,
    nombre,
    anfitrion,
    listo,
    enSala,
    conectado,
    estado,
    numerosEnviados,
    tablero,
    puntaje,
    saltosPorTiempo,
  ];
}

class TurnoRemoto extends Equatable {
  final int jugador;
  final int numero;
  final int dado1;
  final int dado2;
  final int segundosRestantes;

  const TurnoRemoto({
    required this.jugador,
    required this.numero,
    required this.dado1,
    required this.dado2,
    required this.segundosRestantes,
  });

  @override
  List<Object?> get props => [jugador, numero, dado1, dado2, segundosRestantes];
}

class PosicionRemota extends Equatable {
  final int id;
  final int posicion;
  final int puntaje;
  final String estado;

  const PosicionRemota(this.id, this.posicion, this.puntaje, this.estado);

  bool get rendido => estado == 'rendido';
  bool get abandono => estado == 'abandono';

  @override
  List<Object?> get props => [id, posicion, puntaje, estado];
}

/// Zona que se llenó en el último movimiento.
class ZonaLlenada extends Equatable {
  final int zona;
  final String nombre;
  final int lugar;
  final int puntos;

  const ZonaLlenada(this.zona, this.nombre, this.lugar, this.puntos);

  @override
  List<Object?> get props => [zona, nombre, lugar, puntos];
}

class MovimientoRemoto extends Equatable {
  /// colocacion, salto, tiempo_agotado, rendicion o abandono.
  final String tipo;
  final int jugador;
  final int turno;
  final ZonaLlenada? zonaCompletada;

  const MovimientoRemoto(
    this.tipo,
    this.jugador,
    this.turno, [
    this.zonaCompletada,
  ]);

  @override
  List<Object?> get props => [tipo, jugador, turno, zonaCompletada];
}

/// El estado COMPLETO de la sala, tal como lo difunde el servidor.
class SalaRemota extends Equatable {
  final String codigo;
  final int mapa;
  final int maximo;

  /// lobby, numeros, turnos o terminada.
  final String fase;
  final int? anfitrion;
  final List<JugadorRemoto> jugadores;
  final int? segundosParaCaducar;
  final int? segundosParaNumeros;
  final List<int> orden;
  final TurnoRemoto? turno;
  final List<List<int>> ordenZonas;
  final MovimientoRemoto? ultimoMovimiento;
  final List<PosicionRemota>? resultado;

  const SalaRemota({
    required this.codigo,
    required this.mapa,
    required this.maximo,
    required this.fase,
    this.anfitrion,
    this.jugadores = const [],
    this.segundosParaCaducar,
    this.segundosParaNumeros,
    this.orden = const [],
    this.turno,
    this.ordenZonas = const [],
    this.ultimoMovimiento,
    this.resultado,
  });

  bool get enLobby => fase == 'lobby';
  bool get enNumeros => fase == 'numeros';
  bool get enTurnos => fase == 'turnos';
  bool get terminada => fase == 'terminada';

  Nivel get nivel => nivelPorNumero(mapa) ?? nivelesDisponibles.first;

  JugadorRemoto? jugador(int id) {
    for (final j in jugadores) {
      if (j.id == id) return j;
    }
    return null;
  }

  String nombreDe(int id) => jugador(id)?.nombre ?? 'Jugador';

  /// Jugadores que siguen en la sala (los que salieron quedan para el
  /// resultado pero no se listan en el lobby).
  List<JugadorRemoto> get presentes =>
      jugadores.where((j) => j.enSala).toList();

  /// El anfitrión puede iniciar: 2 o más jugadores y todos listos.
  bool get sePuedeIniciar =>
      presentes.length >= 2 && presentes.every((j) => j.listo);

  factory SalaRemota.desdeJson(Map<String, Object?> s) {
    final turno = s['turno'];
    final movimiento = s['ultimoMovimiento'];
    final resultado = s['resultado'];
    return SalaRemota(
      codigo: s['codigo'] as String? ?? '',
      mapa: _entero(s['mapa'], 1),
      maximo: _entero(s['maximo'], 2),
      fase: s['fase'] as String? ?? 'lobby',
      anfitrion: s['anfitrion'] as int?,
      jugadores: [
        for (final j in (s['jugadores'] as List?) ?? const [])
          if (j is Map<String, Object?>) JugadorRemoto.desdeJson(j),
      ],
      segundosParaCaducar: s['segundosParaCaducar'] as int?,
      segundosParaNumeros: s['segundosParaNumeros'] as int?,
      orden: [
        for (final id in (s['orden'] as List?) ?? const [])
          if (id is int) id,
      ],
      turno: turno is Map<String, Object?> ? _turno(turno) : null,
      ordenZonas: [
        for (final z in (s['ordenZonas'] as List?) ?? const [])
          [
            for (final id in (z as List?) ?? const [])
              if (id is int) id,
          ],
      ],
      ultimoMovimiento: movimiento is Map<String, Object?>
          ? _movimiento(movimiento)
          : null,
      resultado: resultado is List
          ? [
              for (final r in resultado)
                if (r is Map<String, Object?>)
                  PosicionRemota(
                    _entero(r['id']),
                    _entero(r['posicion']),
                    _entero(r['puntaje']),
                    r['estado'] as String? ?? 'jugando',
                  ),
            ]
          : null,
    );
  }

  @override
  List<Object?> get props => [
    codigo,
    mapa,
    maximo,
    fase,
    anfitrion,
    jugadores,
    segundosParaCaducar,
    segundosParaNumeros,
    orden,
    turno,
    ordenZonas,
    ultimoMovimiento,
    resultado,
  ];
}

int _entero(Object? valor, [int porDefecto = 0]) =>
    valor is int ? valor : porDefecto;

List<List<int?>>? _tablero(Object? valor) {
  if (valor is! List) return null;
  return [
    for (final fila in valor)
      [
        for (final celda in (fila as List?) ?? const [])
          celda is int ? celda : null,
      ],
  ];
}

TurnoRemoto? _turno(Map<String, Object?> t) {
  final dados = t['dados'];
  if (dados is! List || dados.length != 2) return null;
  final d1 = dados[0];
  final d2 = dados[1];
  if (d1 is! int || d2 is! int) return null;
  return TurnoRemoto(
    jugador: _entero(t['jugador']),
    numero: _entero(t['numero']),
    dado1: d1,
    dado2: d2,
    segundosRestantes: _entero(t['segundosRestantes']),
  );
}

MovimientoRemoto _movimiento(Map<String, Object?> m) {
  final z = m['zonaCompletada'];
  return MovimientoRemoto(
    m['tipo'] as String? ?? '',
    _entero(m['jugador']),
    _entero(m['turno']),
    z is Map<String, Object?>
        ? ZonaLlenada(
            _entero(z['zona']),
            z['nombre'] as String? ?? '',
            _entero(z['lugar']),
            _entero(z['puntos']),
          )
        : null,
  );
}
