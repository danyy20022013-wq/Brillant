import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../piezas_juego.dart';
import '../reglas.dart';
import '../tipo.dart';
import 'cuenta_regresiva.dart';
import 'multijugador_cubit.dart';

const _panel = Color(0xFF1F2244);
const _dorado = Color(0xFFFFD166);
const _verde = Color(0xFF3FB67A);
const _rojo = Color(0xFFFF8A8A);

/// Rearma el tablero de un jugador (con las reglas compartidas) a partir de
/// lo que mandó el servidor, para iluminar las casillas posibles. La
/// jugada la valida igual el servidor.
Juego? juegoDesdeTablero(Nivel mapa, List<List<int?>> tablero) {
  final iniciales = <int>[];
  for (final p in mapa.estrellas) {
    final v = tablero[p.fila][p.columna];
    if (v == null) return null;
    iniciales.add(v);
  }
  var juego = Juego.inicial(iniciales, nivel: mapa);
  for (var f = 0; f < tablero.length; f++) {
    for (var c = 0; c < tablero[f].length; c++) {
      final v = tablero[f][c];
      if (v != null && !mapa.esEstrella(f, c)) juego = juego.colocar(f, c, v);
    }
  }
  return juego;
}

/// Nombre corto para los chips de zona ("Ana", "Bet…").
String nombreCorto(String nombre) =>
    nombre.length <= 4 ? nombre : '${nombre.substring(0, 3)}…';

/// Confirma la rendición explicando qué pasa.
Future<bool> confirmarRendirse(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: const Text('¿Rendirte?'),
      content: const Text(
        'Si te rindes quedarás en último lugar, sin importar tus puntos. '
        'Tu tablero se congela y ya no jugarás esta partida.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogo).pop(false),
          child: const Text('Seguir jugando'),
        ),
        FilledButton(
          key: const Key('confirmar-rendirse'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE5484D),
          ),
          onPressed: () => Navigator.of(dialogo).pop(true),
          child: const Text('Rendirme'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// La partida en línea. Solo manda intenciones; todo lo que muestra
/// (tableros, puntos, turno, dados) es lo último que confirmó el servidor.
class VistaPartidaMulti extends StatefulWidget {
  final EstadoMultijugador estado;

  const VistaPartidaMulti({super.key, required this.estado});

  @override
  State<VistaPartidaMulti> createState() => _VistaPartidaMultiState();
}

class _VistaPartidaMultiState extends State<VistaPartidaMulti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _giro = AnimationController(
    vsync: this,
    duration: duracionGiroDados,
  )..addStatusListener((_) => setState(() {}));

  /// Dado elegido como ancla (0 o 1) en mi turno.
  int? _indiceAncla;

  /// En mi turno, si ya "tiré" (los valores los puso el servidor; tirar
  /// solo los muestra con la animación).
  bool _revelados = false;

  /// Mandé una jugada y espero la respuesta del servidor.
  bool _esperando = false;

  /// De quién es el tablero que se ve (por defecto el mío).
  int? _verId;

  int? _turnoVisto;

  EstadoMultijugador get _estado => widget.estado;
  SalaRemota get _sala => _estado.sala!;

  @override
  void initState() {
    super.initState();
    _alCambiarTurno();
  }

  @override
  void didUpdateWidget(VistaPartidaMulti anterior) {
    super.didUpdateWidget(anterior);
    if (_sala.turno?.numero != _turnoVisto) {
      _alCambiarTurno();
    } else if (anterior.estado.numeroError != _estado.numeroError) {
      // El servidor rechazó la jugada: se puede intentar otra.
      _esperando = false;
    }
  }

  void _alCambiarTurno() {
    _turnoVisto = _sala.turno?.numero;
    _indiceAncla = null;
    _esperando = false;
    if (_estado.esMiTurno) {
      _revelados = false;
    } else {
      _revelados = true;
      if (_sala.turno != null) _giro.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  void _tirar() {
    setState(() => _revelados = true);
    _giro.forward(from: 0);
  }

  bool get _puedoJugar =>
      _estado.esMiTurno &&
      _revelados &&
      !_giro.isAnimating &&
      !_esperando &&
      _estado.conexion == EstadoConexion.conectado;

  int? get _ancla {
    final t = _sala.turno;
    if (t == null || _indiceAncla == null) return null;
    return _indiceAncla == 0 ? t.dado1 : t.dado2;
  }

  int? get _aColocar {
    final t = _sala.turno;
    if (t == null || _indiceAncla == null) return null;
    return _indiceAncla == 0 ? t.dado2 : t.dado1;
  }

  Juego? get _miJuego {
    final tablero = _estado.yo?.tablero;
    return tablero == null ? null : juegoDesdeTablero(_sala.nivel, tablero);
  }

  Set<(int, int)> get _resaltadas {
    final ancla = _ancla;
    final valor = _aColocar;
    if (!_puedoJugar || ancla == null || valor == null) return const {};
    return _miJuego?.jugadasPosibles(ancla: ancla, aColocar: valor) ?? const {};
  }

  bool get _hayJugadas {
    final t = _sala.turno;
    if (t == null) return false;
    return _miJuego?.hayJugadaCon(t.dado1, t.dado2) ?? false;
  }

  void _colocar(int fila, int columna) {
    final ancla = _indiceAncla;
    if (ancla == null) return;
    setState(() => _esperando = true);
    context.read<MultijugadorCubit>().colocar(ancla, fila, columna);
  }

  Future<void> _saltar() async {
    final cubit = context.read<MultijugadorCubit>();
    final aviso = _hayJugadas
        ? 'Todavía tienes jugadas posibles. ¿Quieres saltar el turno?'
        : 'No tienes jugadas posibles con estos dados.';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('¿Saltar el turno?'),
        content: Text(aviso),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirmar-saltar'),
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Saltar'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      setState(() => _esperando = true);
      cubit.saltar();
    }
  }

  Future<void> _rendirse() async {
    final cubit = context.read<MultijugadorCubit>();
    if (await confirmarRendirse(context)) cubit.rendirse();
  }

  String get _instruccion {
    final t = _sala.turno;
    if (t == null) return 'Esperando al servidor…';
    if (!_estado.esMiTurno) {
      return 'Turno de ${_sala.nombreDe(t.jugador)}';
    }
    if (!_revelados) return 'Es tu turno: tira los dados';
    if (_giro.isAnimating) return 'Tirando los dados…';
    if (_esperando) return 'Enviando tu jugada…';
    if (_indiceAncla == null) {
      return _hayJugadas
          ? 'Toca un dado para elegirlo como ancla'
          : 'No hay jugadas posibles con estos dados';
    }
    if (_resaltadas.isEmpty) {
      return 'Con esa ancla no hay lugar, prueba con el otro dado';
    }
    return 'Coloca el $_aColocar junto a un $_ancla (casillas iluminadas)';
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MultijugadorCubit>();
    final sala = _sala;
    final yo = _estado.yo;
    final verId = _verId ?? _estado.miId;
    final visto = verId == null ? null : sala.jugador(verId);
    final tablero = visto?.tablero;
    final turno = sala.turno;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'Mapa ${sala.mapa}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        turno == null
                            ? 'Partida'
                            : _estado.esMiTurno
                            ? 'Tu turno'
                            : 'Turno de ${sala.nombreDe(turno.jugador)}',
                        key: const Key('texto-turno'),
                        style: const TextStyle(
                          color: _dorado,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (turno != null)
                    CuentaRegresiva(
                      key: ValueKey('turno-${turno.numero}'),
                      total: Duration(seconds: turno.segundosRestantes),
                      desde: _estado.recibida ?? cubit.ahora(),
                      reloj: cubit.ahora,
                      constructor: (_, s) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: s <= 10 ? const Color(0x55E5484D) : _panel,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '⏱ $s s',
                          key: const Key('tiempo-turno'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: () => mostrarReglas(context, sala.nivel),
                    tooltip: 'Reglas',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.help_outline_rounded,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              MarcadorMultijugador(
                sala: sala,
                miId: _estado.miId,
                desconectadosDesde: _estado.desconectadosDesde,
                plazoReconexion: cubit.plazoReconexion,
                reloj: cubit.ahora,
                verId: verId,
                alElegir: (id) => setState(() => _verId = id),
              ),
              if (yo != null && !yo.sigueJugando)
                _AvisoFueraDeJuego(jugador: yo),
              const SizedBox(height: 6),
              SizedBox(
                height: 76,
                child: Row(
                  children: [
                    _dado(0, turno?.dado1),
                    const SizedBox(width: 10),
                    _dado(1, turno?.dado2),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _instruccion,
                        key: const Key('instruccion-multi'),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              if (verId != _estado.miId && visto != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Tablero de ${visto.nombre} (toca tu nombre para volver)',
                    key: const Key('viendo-tablero'),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              Expanded(
                child: tablero == null
                    ? const SizedBox.shrink()
                    : TableroPartida(
                        mapa: sala.nivel,
                        tablero: tablero,
                        resaltadas: verId == _estado.miId
                            ? _resaltadas
                            : const {},
                        ancla: verId == _estado.miId ? _ancla : null,
                        sugerido: _aColocar,
                        alTocar: _colocar,
                      ),
              ),
              const SizedBox(height: 8),
              PanelZonas(
                mapa: sala.nivel,
                ordenZonas: sala.ordenZonas,
                individual: false,
                etiqueta: (id) => nombreCorto(sala.nombreDe(id)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 46,
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        key: const Key('boton-accion-turno'),
                        onPressed: !_estado.esMiTurno || _esperando
                            ? null
                            : !_revelados
                            ? _tirar
                            : _puedoJugar
                            ? _saltar
                            : null,
                        child: Text(
                          _estado.esMiTurno && !_revelados
                              ? 'Tirar dados'
                              : 'Saltar turno',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      key: const Key('boton-rendirse'),
                      onPressed: yo != null && yo.sigueJugando
                          ? _rendirse
                          : null,
                      style: OutlinedButton.styleFrom(foregroundColor: _rojo),
                      child: const Text('Rendirse'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dado(int indice, int? valor) {
    final mostrar = _revelados ? valor : null;
    return AnimatedBuilder(
      animation: _giro,
      builder: (context, _) {
        final girando = _giro.isAnimating;
        final etiqueta = girando || _indiceAncla == null || !_estado.esMiTurno
            ? ''
            : _indiceAncla == indice
            ? 'ANCLA'
            : 'A COLOCAR';
        return CaraDado(
          key: Key('dado-$indice'),
          valor: girando ? caraEnGiro(_giro.value, indice) : mostrar,
          angulo: girando ? _giro.value * 4 * pi : 0,
          etiqueta: etiqueta,
          esAncla: !girando && _estado.esMiTurno && _indiceAncla == indice,
          onTap: _puedoJugar
              ? () => setState(() => _indiceAncla = indice)
              : null,
        );
      },
    );
  }
}

class _AvisoFueraDeJuego extends StatelessWidget {
  final JugadorRemoto jugador;

  const _AvisoFueraDeJuego({required this.jugador});

  @override
  Widget build(BuildContext context) {
    final abandono = jugador.abandono;
    return Container(
      key: const Key('aviso-fuera-de-juego'),
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x33E5484D),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              abandono
                  ? 'Se agotó el plazo: abandonaste la partida.'
                  : 'Te rendiste: quedas en último lugar.',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          TextButton(
            key: const Key('volver-menu-fuera'),
            onPressed: () => context.read<MultijugadorCubit>().salir(),
            child: const Text('Volver al menú'),
          ),
        ],
      ),
    );
  }
}

/// Marcador con todos los jugadores: nombre, puntos, turno y si está
/// conectado, desconectado (con cuenta regresiva), rendido o si abandonó.
class MarcadorMultijugador extends StatelessWidget {
  final SalaRemota sala;
  final int? miId;
  final Map<int, DateTime> desconectadosDesde;
  final Duration plazoReconexion;
  final DateTime Function() reloj;
  final int? verId;
  final void Function(int id)? alElegir;

  const MarcadorMultijugador({
    super.key,
    required this.sala,
    required this.miId,
    required this.desconectadosDesde,
    required this.plazoReconexion,
    required this.reloj,
    this.verId,
    this.alElegir,
  });

  @override
  Widget build(BuildContext context) {
    // En el orden de turnos si ya se sorteó; si no, el de la sala.
    final ids = sala.orden.isNotEmpty
        ? [
            ...sala.orden,
            for (final j in sala.jugadores)
              if (!sala.orden.contains(j.id)) j.id,
          ]
        : [for (final j in sala.jugadores) j.id];
    return Row(
      children: [
        for (var i = 0; i < ids.length; i++)
          if (sala.jugador(ids[i]) case final j?)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == ids.length - 1 ? 0 : 6),
                child: _TarjetaJugador(
                  jugador: j,
                  esYo: j.id == miId,
                  tieneTurno: sala.turno?.jugador == j.id,
                  seleccionada: verId == j.id,
                  desconectadoDesde: desconectadosDesde[j.id],
                  plazoReconexion: plazoReconexion,
                  reloj: reloj,
                  alTocar: alElegir == null ? null : () => alElegir!(j.id),
                ),
              ),
            ),
      ],
    );
  }
}

class _TarjetaJugador extends StatelessWidget {
  final JugadorRemoto jugador;
  final bool esYo;
  final bool tieneTurno;
  final bool seleccionada;
  final DateTime? desconectadoDesde;
  final Duration plazoReconexion;
  final DateTime Function() reloj;
  final VoidCallback? alTocar;

  const _TarjetaJugador({
    required this.jugador,
    required this.esYo,
    required this.tieneTurno,
    required this.seleccionada,
    required this.desconectadoDesde,
    required this.plazoReconexion,
    required this.reloj,
    required this.alTocar,
  });

  Widget _estado() {
    if (jugador.rendido) {
      return const Text(
        'Rendido',
        style: TextStyle(color: _rojo, fontSize: 10),
      );
    }
    if (jugador.abandono) {
      return const Text(
        'Abandonó',
        style: TextStyle(color: _rojo, fontSize: 10),
      );
    }
    if (!jugador.conectado) {
      final desde = desconectadoDesde;
      if (desde == null) {
        return const Text(
          'Desconectado',
          style: TextStyle(color: _rojo, fontSize: 10),
        );
      }
      return CuentaRegresiva(
        total: plazoReconexion,
        desde: desde,
        reloj: reloj,
        constructor: (_, s) => Text(
          'Desconectado · $s s',
          style: const TextStyle(color: _rojo, fontSize: 10),
        ),
      );
    }
    if (tieneTurno) {
      return const Text(
        'Su turno',
        style: TextStyle(color: _dorado, fontSize: 10),
      );
    }
    return const Text(
      'Conectado',
      style: TextStyle(color: _verde, fontSize: 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fuera = !jugador.sigueJugando;
    return GestureDetector(
      onTap: alTocar,
      child: Opacity(
        opacity: fuera ? 0.55 : 1,
        child: Container(
          key: Key('marcador-${jugador.id}'),
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: tieneTurno
                  ? _dorado
                  : seleccionada
                  ? Colors.white38
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      esYo ? '${jugador.nombre} (tú)' : jugador.nombre,
                      style: TextStyle(
                        color: tieneTurno ? _dorado : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${jugador.puntaje}',
                      key: Key('puntos-${jugador.id}'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                _estado(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
