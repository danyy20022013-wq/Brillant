import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'conexion_multijugador.dart';
import 'sala_remota.dart';

export 'conexion_multijugador.dart'
    show AvisoMultijugador, EstadoConexion, MensajesMultijugador, TipoAviso;
export 'sala_remota.dart';

/// Lo primero que se hace al conectarse: crear una sala o unirse a una.
class AccionInicial extends Equatable {
  final String tipo;

  const AccionInicial.crear({required int mapa, required int maximo})
    : tipo = 'crear_sala',
      _mapa = mapa,
      _maximo = maximo,
      _codigo = null;

  const AccionInicial.unirse(String codigo)
    : tipo = 'unirse',
      _mapa = null,
      _maximo = null,
      _codigo = codigo;

  final int? _mapa;
  final int? _maximo;
  final String? _codigo;

  Map<String, Object?> get campos => {
    'mapa': ?_mapa,
    'maximo': ?_maximo,
    'codigo': ?_codigo,
  };

  @override
  List<Object?> get props => [tipo, _mapa, _maximo, _codigo];
}

class EstadoMultijugador extends Equatable {
  final EstadoConexion conexion;

  /// Mi id según el servidor (llega al autenticarse).
  final int? miId;

  /// Último estado completo que difundió el servidor.
  final SalaRemota? sala;

  /// Cuándo llegó [sala]: con esto se cuentan los segundos que quedan.
  final DateTime? recibida;

  /// Último error de una acción (lo manda el servidor, en español).
  final String? error;

  /// Cambia con cada error, para mostrar dos iguales seguidos.
  final int numeroError;

  /// Desde cuándo vemos desconectado a cada jugador que sigue en partida.
  final Map<int, DateTime> desconectadosDesde;

  /// La pantalla debe cerrarse y volver al menú. [motivoFin] explica por
  /// qué (null si fue el jugador quien salió).
  final bool fin;
  final String? motivoFin;

  const EstadoMultijugador({
    this.conexion = EstadoConexion.conectando,
    this.miId,
    this.sala,
    this.recibida,
    this.error,
    this.numeroError = 0,
    this.desconectadosDesde = const {},
    this.fin = false,
    this.motivoFin,
  });

  JugadorRemoto? get yo => miId == null ? null : sala?.jugador(miId!);

  bool get soyAnfitrion => miId != null && sala?.anfitrion == miId;

  bool get esMiTurno =>
      sala?.enTurnos == true && miId != null && sala?.turno?.jugador == miId;

  bool get reconectando => conexion == EstadoConexion.reconectando;

  EstadoMultijugador copiar({
    EstadoConexion? conexion,
    int? miId,
    SalaRemota? sala,
    DateTime? recibida,
    String? error,
    bool limpiarError = false,
    int? numeroError,
    Map<int, DateTime>? desconectadosDesde,
    bool? fin,
    String? motivoFin,
  }) => EstadoMultijugador(
    conexion: conexion ?? this.conexion,
    miId: miId ?? this.miId,
    sala: sala ?? this.sala,
    recibida: recibida ?? this.recibida,
    error: limpiarError ? null : (error ?? this.error),
    numeroError: numeroError ?? this.numeroError,
    desconectadosDesde: desconectadosDesde ?? this.desconectadosDesde,
    fin: fin ?? this.fin,
    motivoFin: motivoFin ?? this.motivoFin,
  );

  @override
  List<Object?> get props => [
    conexion,
    miId,
    sala,
    recibida,
    error,
    numeroError,
    desconectadosDesde,
    fin,
    motivoFin,
  ];
}

/// Mensaje si se intenta jugar sin conexión.
const mensajeSinConexionAccion =
    'Sin conexión con el servidor. Espera a que vuelva para seguir.';

/// Plazo que da el servidor para volver tras caerse (SEGUNDOS_RECONEXION,
/// 60 s por defecto). El servidor no lo manda: se usa para la cuenta
/// regresiva que se muestra junto a los desconectados.
const plazoReconexionPorDefecto = Duration(seconds: 60);

/// Multijugador: la app solo manda intenciones y muestra lo que confirma
/// el servidor. Nunca cambia la sala por su cuenta.
class MultijugadorCubit extends Cubit<EstadoMultijugador> {
  final ConexionMultijugador _conexion;
  final DateTime Function() _reloj;
  final Duration plazoReconexion;
  AccionInicial? _pendiente;

  MultijugadorCubit({
    required ConexionMultijugador conexion,
    AccionInicial? accionInicial,
    DateTime Function()? reloj,
    this.plazoReconexion = plazoReconexionPorDefecto,
  }) : _conexion = conexion,
       _pendiente = accionInicial,
       _reloj = reloj ?? DateTime.now,
       super(const EstadoMultijugador()) {
    _conexion
      ..alCambiarEstado = _alCambiarConexion
      ..alMensaje = _alMensaje
      ..alAviso = _alAviso;
  }

  DateTime ahora() => _reloj();

  /// Abre la conexión; al autenticarse manda la acción inicial.
  Future<void> conectar() => _conexion.abrir();

  // ---------------------------------------------------------------------
  // Intenciones del jugador
  // ---------------------------------------------------------------------

  void listo(bool listo) => _accion('listo', {'listo': listo});

  void iniciar() => _accion('iniciar');

  void enviarNumeros(List<int> numeros) =>
      _accion('numeros_iniciales', {'numeros': numeros});

  /// [dadoAncla] es 0 (dado 1) o 1 (dado 2). Los valores de los dados los
  /// pone el servidor.
  void colocar(int dadoAncla, int fila, int columna) => _accion('colocar', {
    'dadoAncla': dadoAncla,
    'fila': fila,
    'columna': columna,
  });

  void saltar() => _accion('saltar');

  void rendirse() => _accion('rendirse');

  /// Sale de la sala. Si no hay conexión o la sala ya no sigue, vuelve al
  /// menú igual.
  void salir() {
    if (_accion('salir', const {}, false)) return;
    _terminar(null);
  }

  /// Olvida el último error (por ejemplo, al cerrar su aviso).
  void limpiarError() {
    if (state.error != null) emit(state.copiar(limpiarError: true));
  }

  bool _accion(
    String tipo, [
    Map<String, Object?> datos = const {},
    bool avisar = true,
  ]) {
    final id = _conexion.enviarAccion(tipo, datos);
    if (id != null) return true;
    if (avisar) {
      emit(
        state.copiar(
          error: mensajeSinConexionAccion,
          numeroError: state.numeroError + 1,
        ),
      );
    }
    return false;
  }

  // ---------------------------------------------------------------------
  // Lo que llega del servidor
  // ---------------------------------------------------------------------

  void _alCambiarConexion(EstadoConexion conexion) {
    if (isClosed) return;
    emit(state.copiar(conexion: conexion));
  }

  void _alMensaje(Map<String, Object?> mensaje) {
    if (isClosed || state.fin) return;
    switch (mensaje['tipo']) {
      case 'autenticado':
        final usuario = mensaje['usuario'];
        final id = usuario is Map ? usuario['id'] : null;
        emit(state.copiar(miId: id is int ? id : null));
        // Si el servidor ya me tiene en una sala, la restauro en lugar de
        // crear o unirme a otra.
        final pendiente = _pendiente;
        if (mensaje['sala'] == null &&
            state.sala == null &&
            pendiente != null) {
          _pendiente = null;
          _conexion.enviarAccion(pendiente.tipo, pendiente.campos);
        } else {
          _pendiente = null;
        }
      case 'estado':
        final datos = mensaje['sala'];
        if (datos is! Map<String, Object?>) return;
        final sala = SalaRemota.desdeJson(datos);
        _conexion.salaActual = sala.codigo;
        emit(
          state.copiar(
            sala: sala,
            recibida: _reloj(),
            desconectadosDesde: _desconectados(sala),
          ),
        );
      case 'error':
        final texto = mensaje['mensaje'] as String? ?? 'No se pudo hacer eso';
        if (state.sala == null) {
          // Falló crear la sala o unirse: no hay a qué volver.
          _terminar(texto);
          return;
        }
        emit(state.copiar(error: texto, numeroError: state.numeroError + 1));
      case 'saliste':
        _terminar(null);
      case 'sala_cerrada':
        _terminar(mensaje['mensaje'] as String? ?? 'La sala se cerró.');
    }
  }

  void _alAviso(AvisoMultijugador aviso) {
    if (isClosed || state.fin) return;
    _terminar(aviso.mensaje);
  }

  void _terminar(String? motivo) {
    _conexion.salaActual = null;
    _conexion.cerrar();
    if (isClosed) return;
    emit(state.copiar(fin: true, motivoFin: motivo));
  }

  /// Guarda desde cuándo vemos caído a cada jugador que sigue en partida
  /// (para la cuenta regresiva). Si vuelve, se olvida.
  Map<int, DateTime> _desconectados(SalaRemota sala) {
    if (sala.enLobby || sala.terminada) return const {};
    final antes = state.desconectadosDesde;
    return {
      for (final j in sala.jugadores)
        if (!j.conectado && j.enSala && j.sigueJugando)
          j.id: antes[j.id] ?? _reloj(),
    };
  }

  @override
  Future<void> close() {
    _conexion.cerrar();
    return super.close();
  }
}
