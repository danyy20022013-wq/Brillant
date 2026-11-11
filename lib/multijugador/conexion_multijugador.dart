import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:equatable/equatable.dart';

import 'canal_ws.dart';

/// En qué está la conexión con el servidor.
enum EstadoConexion {
  /// Primer intento de conexión.
  conectando,

  /// Autenticada: se pueden mandar acciones.
  conectado,

  /// Se cortó y se está volviendo a conectar sola.
  reconectando,

  /// Se rindió de reconectar, o el servidor la cerró sin vuelta atrás.
  caido,

  /// La cerró la app.
  cerrado,
}

enum TipoAviso {
  sinConexion,
  servidorNoDisponible,
  sesionReemplazada,
  sesionInvalida,
  salaInexistente,
}

/// Avisos claros en español para el jugador.
abstract final class MensajesMultijugador {
  static const sinConexion =
      'Se perdió la conexión con el servidor. Revisa tu internet e '
      'inténtalo de nuevo.';
  static const servidorNoDisponible =
      'El servidor no está disponible ahora. Inténtalo más tarde.';
  static const sesionReemplazada =
      'Abriste Brilliant en otro lugar, así que esta pantalla se '
      'desconectó.';
  static const sesionInvalida =
      'Tu sesión no es válida o ya venció. Vuelve a iniciar sesión.';
  static const salaInexistente =
      'Esa sala ya no existe. Puede que el servidor se haya reiniciado.';

  static String de(TipoAviso tipo) => switch (tipo) {
    TipoAviso.sinConexion => sinConexion,
    TipoAviso.servidorNoDisponible => servidorNoDisponible,
    TipoAviso.sesionReemplazada => sesionReemplazada,
    TipoAviso.sesionInvalida => sesionInvalida,
    TipoAviso.salaInexistente => salaInexistente,
  };
}

class AvisoMultijugador extends Equatable {
  final TipoAviso tipo;

  const AvisoMultijugador(this.tipo);

  String get mensaje => MensajesMultijugador.de(tipo);

  @override
  List<Object?> get props => [tipo];
}

/// Esperas entre reintentos: 1, 2, 4, 8 y luego 15 s.
const esperasPorDefecto = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8),
  Duration(seconds: 15),
];

/// Códigos de cierre del servidor (ver servidor/README.md).
const _cierreSinSesion = 4001;
const _cierreReemplazada = 4002;

/// Conexión con el multijugador del servidor.
///
/// - Manda el token en el primer mensaje (nunca en la URL).
/// - Contesta los ping del servidor y, si no oye nada en [silencioMaximo],
///   da la conexión por caída.
/// - Si se corta, reintenta sola con espera creciente hasta
///   [maximoIntentos] veces seguidas.
/// - Lleva el id creciente de las acciones y, al reconectarse, sigue desde
///   el último que conoce el servidor.
class ConexionMultijugador {
  final Uri url;
  final Future<String?> Function() _token;
  final ConectorWs _conectar;
  final List<Duration> esperas;
  final int maximoIntentos;
  final Duration silencioMaximo;

  void Function(EstadoConexion estado)? alCambiarEstado;
  void Function(Map<String, Object?> mensaje)? alMensaje;
  void Function(AvisoMultijugador aviso)? alAviso;

  /// Sala en la que la app cree estar: se manda al autenticarse para que
  /// el servidor avise si ya no existe.
  String? salaActual;

  EstadoConexion _estado = EstadoConexion.conectando;
  CanalWs? _canal;
  StreamSubscription<String>? _suscripcion;
  Timer? _reintento;
  Timer? _silencio;
  int _intentos = 0;
  bool _conectoAlgunaVez = false;
  bool _cerradaPorLaApp = false;
  int _siguienteId = 1;

  ConexionMultijugador({
    required this.url,
    required Future<String?> Function() token,
    ConectorWs conectar = conectarWebSocket,
    this.esperas = esperasPorDefecto,
    this.maximoIntentos = 6,
    this.silencioMaximo = const Duration(seconds: 25),
  }) : _token = token,
       _conectar = conectar;

  EstadoConexion get estado => _estado;
  bool get conectada => _estado == EstadoConexion.conectado;

  /// Intentos de reconexión seguidos que lleva (para mostrarlo).
  int get intentos => _intentos;

  Future<void> abrir() => _intentar();

  /// Manda una acción con el siguiente id. Devuelve el id, o null si no
  /// está conectada (la acción no se manda).
  int? enviarAccion(String tipo, [Map<String, Object?> datos = const {}]) {
    final canal = _canal;
    if (!conectada || canal == null) return null;
    final id = _siguienteId++;
    canal.enviar(jsonEncode({'tipo': tipo, 'id': id, ...datos}));
    return id;
  }

  /// Manda un mensaje sin id (por ejemplo "reconectar").
  bool enviar(Map<String, Object?> mensaje) {
    final canal = _canal;
    if (!conectada || canal == null) return false;
    canal.enviar(jsonEncode(mensaje));
    return true;
  }

  void cerrar() {
    if (_cerradaPorLaApp) return;
    _cerradaPorLaApp = true;
    _reintento?.cancel();
    _soltarCanal()?.cerrar();
    _cambiar(EstadoConexion.cerrado);
  }

  Future<void> _intentar() async {
    if (_cerradaPorLaApp) return;
    _cambiar(
      _conectoAlgunaVez
          ? EstadoConexion.reconectando
          : EstadoConexion.conectando,
    );
    final token = await _token();
    if (_cerradaPorLaApp) return;
    if (token == null) {
      _terminar(TipoAviso.sesionInvalida);
      return;
    }
    final CanalWs canal;
    try {
      canal = await _conectar(url);
    } catch (_) {
      _programarReintento();
      return;
    }
    if (_cerradaPorLaApp) {
      canal.cerrar();
      return;
    }
    _canal = canal;
    _suscripcion = canal.mensajes.listen(
      _recibir,
      onDone: () => _alCerrarse(canal),
      onError: (Object _) {},
    );
    _vigilarSilencio();
    canal.enviar(
      jsonEncode({
        'tipo': 'autenticar',
        'token': token,
        if (salaActual != null) 'sala': salaActual,
      }),
    );
  }

  void _recibir(String texto) {
    _vigilarSilencio();
    final Object? dato;
    try {
      dato = jsonDecode(texto);
    } on FormatException {
      return;
    }
    if (dato is! Map<String, Object?> || dato['tipo'] is! String) return;

    switch (dato['tipo']) {
      case 'ping':
        _canal?.enviar(jsonEncode({'tipo': 'pong'}));
        return;
      case 'autenticado':
        final ultima = dato['ultimaAccion'];
        if (ultima is int) _siguienteId = max(_siguienteId, ultima + 1);
        _intentos = 0;
        _conectoAlgunaVez = true;
        _cambiar(EstadoConexion.conectado);
      case 'sala_no_existe':
        alAviso?.call(const AvisoMultijugador(TipoAviso.salaInexistente));
    }
    alMensaje?.call(dato);
  }

  void _alCerrarse(CanalWs canal) {
    if (!identical(canal, _canal)) return;
    _soltarCanal();
    if (_cerradaPorLaApp) return;
    switch (canal.codigoCierre) {
      case _cierreReemplazada:
        _terminar(TipoAviso.sesionReemplazada);
      case _cierreSinSesion:
        _terminar(TipoAviso.sesionInvalida);
      default:
        _programarReintento();
    }
  }

  void _vigilarSilencio() {
    _silencio?.cancel();
    _silencio = Timer(silencioMaximo, () {
      // El servidor manda un ping cada 10 s: tanto silencio es una caída.
      final canal = _soltarCanal();
      if (canal == null || _cerradaPorLaApp) return;
      canal.cerrar();
      _programarReintento();
    });
  }

  void _programarReintento() {
    if (_cerradaPorLaApp) return;
    if (_intentos >= maximoIntentos) {
      _terminar(
        _conectoAlgunaVez
            ? TipoAviso.sinConexion
            : TipoAviso.servidorNoDisponible,
      );
      return;
    }
    final espera = esperas[min(_intentos, esperas.length - 1)];
    _intentos++;
    _cambiar(
      _conectoAlgunaVez
          ? EstadoConexion.reconectando
          : EstadoConexion.conectando,
    );
    _reintento?.cancel();
    _reintento = Timer(espera, () => unawaited(_intentar()));
  }

  void _terminar(TipoAviso tipo) {
    _reintento?.cancel();
    _soltarCanal()?.cerrar();
    _cambiar(EstadoConexion.caido);
    alAviso?.call(AvisoMultijugador(tipo));
  }

  CanalWs? _soltarCanal() {
    _silencio?.cancel();
    _silencio = null;
    unawaited(_suscripcion?.cancel());
    _suscripcion = null;
    final canal = _canal;
    _canal = null;
    return canal;
  }

  void _cambiar(EstadoConexion nuevo) {
    if (_estado == nuevo) return;
    _estado = nuevo;
    alCambiarEstado?.call(nuevo);
  }
}
