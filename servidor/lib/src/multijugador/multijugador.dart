import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:reglas_brilliant/reglas_brilliant.dart';

import '../autenticacion.dart';
import '../limitador.dart';
import '../servicios.dart';
import '../tokens.dart';
import 'canal.dart';
import 'codigos_sala.dart';
import 'partida.dart';
import 'programador.dart';
import 'sala.dart';

/// Tiempos y límites del multijugador. Los valores por defecto son los del
/// juego; las pruebas los pueden cambiar.
class OpcionesMultijugador {
  /// Plazo para que llegue el mensaje "autenticar" con el token.
  final Duration tiempoAutenticacion;

  /// Cada cuánto se manda un ping. Sin pong antes del siguiente = caída.
  final Duration latido;

  final Duration turno;
  final Duration numerosIniciales;

  /// Plazo para volver a una partida después de caerse.
  final Duration reconexion;

  /// Quien se cae en el lobby sale de la sala después de este tiempo.
  final Duration desconexionLobby;

  /// Una sala que no empieza se cierra después de este tiempo.
  final Duration caducidadLobby;

  /// Una partida sin nadie conectado se cierra después de este tiempo.
  final Duration sinNadieConectado;

  final int maximoSaltosPorTiempo;

  /// Tamaño máximo de un mensaje, en bytes UTF-8.
  final int bytesMaximos;

  /// Mensajes mal formados por minuto antes de cerrar la conexión.
  final int malformadosPorMinuto;

  /// Intentos de unirse a una sala por minuto, por usuario y por IP.
  final int unionesPorUsuario;
  final int unionesPorIp;

  const OpcionesMultijugador({
    this.tiempoAutenticacion = const Duration(seconds: 5),
    this.latido = const Duration(seconds: 10),
    this.turno = const Duration(seconds: 60),
    this.numerosIniciales = const Duration(seconds: 90),
    this.reconexion = const Duration(seconds: 60),
    this.desconexionLobby = const Duration(seconds: 15),
    this.caducidadLobby = const Duration(minutes: 15),
    this.sinNadieConectado = const Duration(minutes: 5),
    this.maximoSaltosPorTiempo = 3,
    this.bytesMaximos = 4096,
    this.malformadosPorMinuto = 10,
    this.unionesPorUsuario = 10,
    this.unionesPorIp = 30,
  });
}

/// Acciones del jugador: todas llevan un "id" creciente.
const _accionesConId = {
  'crear_sala',
  'unirse',
  'listo',
  'salir',
  'iniciar',
  'numeros_iniciales',
  'colocar',
  'saltar',
  'rendirse',
};

class _Conexion {
  final CanalCliente canal;
  final String ip;
  final Limitador malformados;

  int? usuario;
  String nombre = '';
  Tarea? tareaAutenticacion;
  Tarea? tareaLatido;
  bool esperandoPong = false;
  bool cerrada = false;
  StreamSubscription<Object?>? suscripcion;

  _Conexion(this.canal, this.ip, this.malformados);
}

/// Salas y partidas en memoria. El servidor es la autoridad: tira los
/// dados, valida cada jugada y difunde el estado completo tras cada cambio.
///
/// Todo vive en memoria: si el servidor se reinicia, las salas se pierden y
/// la app recibe "sala_no_existe" al intentar volver.
class Multijugador {
  final Servicios _servicios;
  final Programador _programador;
  final Random _random;
  final OpcionesMultijugador opciones;

  final Map<int, _Conexion> _conexiones = {};
  final Map<String, Sala> _salas = {};
  final Map<int, String> _salaDe = {};
  final Map<int, int> _ultimaAccion = {};
  final Limitador _unionesUsuario;
  final Limitador _unionesIp;

  /// [random] debe ser seguro (por defecto Random.secure); las pruebas
  /// pasan uno con semilla.
  Multijugador({
    required Servicios servicios,
    Programador programador = const ProgramadorReal(),
    Random? random,
    this.opciones = const OpcionesMultijugador(),
  }) : _servicios = servicios,
       _programador = programador,
       _random = random ?? Random.secure(),
       _unionesUsuario = Limitador(
         reloj: servicios.reloj,
         maximo: opciones.unionesPorUsuario,
         ventana: const Duration(minutes: 1),
       ),
       _unionesIp = Limitador(
         reloj: servicios.reloj,
         maximo: opciones.unionesPorIp,
         ventana: const Duration(minutes: 1),
       );

  DateTime get _ahora => _servicios.reloj();

  /// Para las pruebas y el monitoreo.
  int get cantidadSalas => _salas.length;
  int get cantidadConexiones => _conexiones.length;
  Sala? sala(String codigo) => _salas[codigo];
  String? codigoDeSalaDe(int usuario) => _salaDe[usuario];

  /// Atiende una conexión nueva. [ip] sirve para el límite de intentos.
  void conectar(CanalCliente canal, {required String ip}) {
    final c = _Conexion(
      canal,
      ip,
      Limitador(
        reloj: _servicios.reloj,
        maximo: opciones.malformadosPorMinuto,
        ventana: const Duration(minutes: 1),
      ),
    );
    c.tareaAutenticacion = _programador.despues(
      opciones.tiempoAutenticacion,
      () => _cerrar(c, CierreWs.sinSesion, 'No llegó el token a tiempo'),
    );
    c.suscripcion = canal.mensajes.listen(
      (dato) => _recibir(c, dato),
      onDone: () => _alCerrarse(c),
      onError: (Object _) => _alCerrarse(c),
      cancelOnError: true,
    );
  }

  /// Cierra todas las conexiones y cancela los temporizadores.
  void cerrar() {
    for (final sala in _salas.values) {
      sala.cancelarTareas();
    }
    _salas.clear();
    _salaDe.clear();
    for (final c in _conexiones.values.toList()) {
      _cerrar(c, CierreWs.servidorCerrado, 'El servidor se está cerrando');
    }
  }

  // -----------------------------------------------------------------------
  // Conexión
  // -----------------------------------------------------------------------

  void _enviar(_Conexion c, Map<String, Object?> mensaje) {
    if (!c.cerrada) c.canal.enviar(jsonEncode(mensaje));
  }

  void _cerrar(_Conexion c, int codigo, String motivo) {
    if (c.cerrada) return;
    c.canal.cerrar(codigo, motivo);
    _alCerrarse(c);
  }

  void _alCerrarse(_Conexion c) {
    if (c.cerrada) return;
    c.cerrada = true;
    c.tareaAutenticacion?.cancelar();
    c.tareaLatido?.cancelar();
    unawaited(c.suscripcion?.cancel());
    final id = c.usuario;
    // Si la reemplazó otra conexión de la misma cuenta, no es una caída.
    if (id != null && identical(_conexiones[id], c)) {
      _conexiones.remove(id);
      _miembroDesconectado(id);
    }
  }

  void _programarLatido(_Conexion c) {
    c.tareaLatido = _programador.despues(opciones.latido, () {
      if (c.cerrada) return;
      if (c.esperandoPong) {
        _cerrar(c, CierreWs.sinLatido, 'No respondió a los latidos');
        return;
      }
      c.esperandoPong = true;
      _enviar(c, {'tipo': 'ping'});
      _programarLatido(c);
    });
  }

  void _recibir(_Conexion c, Object? dato) {
    if (c.cerrada) return;
    // Cualquier mensaje demuestra que la conexión sigue viva.
    c.esperandoPong = false;
    final mensaje = _leer(c, dato);
    if (mensaje == null) return;
    final id = c.usuario;
    if (id == null) {
      _autenticar(c, mensaje);
    } else {
      _despachar(c, id, mensaje);
    }
  }

  Map<String, Object?>? _leer(_Conexion c, Object? dato) {
    if (dato is! String) {
      _malformado(c, 'mensaje_invalido', 'Los mensajes deben ser texto JSON');
      return null;
    }
    if (dato.length > opciones.bytesMaximos ||
        utf8.encode(dato).length > opciones.bytesMaximos) {
      _malformado(
        c,
        'mensaje_muy_grande',
        'El mensaje supera el máximo de ${opciones.bytesMaximos} bytes',
      );
      return null;
    }
    Object? json;
    try {
      json = jsonDecode(dato);
    } on FormatException {
      _malformado(c, 'mensaje_invalido', 'El mensaje no es JSON válido');
      return null;
    }
    if (json is! Map<String, Object?> || json['tipo'] is! String) {
      _malformado(
        c,
        'mensaje_invalido',
        'El mensaje debe ser un objeto JSON con el campo "tipo"',
      );
      return null;
    }
    return json;
  }

  /// Responde con un error sin cerrar; si se repite demasiado, cierra.
  /// Antes de autenticarse cualquier mensaje mal formado cierra.
  void _malformado(_Conexion c, String codigo, String mensaje) {
    if (c.usuario == null) {
      _cerrar(c, CierreWs.sinSesion, 'El primer mensaje debe ser autenticar');
      return;
    }
    _enviar(c, {'tipo': 'error', 'codigo': codigo, 'mensaje': mensaje});
    c.malformados.registrar('m');
    if (c.malformados.bloqueo('m') != null) {
      _cerrar(c, CierreWs.abuso, 'Demasiados mensajes no válidos');
    }
  }

  void _autenticar(_Conexion c, Map<String, Object?> mensaje) {
    final token = mensaje['token'];
    if (mensaje['tipo'] != 'autenticar' || token is! String) {
      _cerrar(c, CierreWs.sinSesion, 'El primer mensaje debe ser autenticar');
      return;
    }
    final int id;
    try {
      id = _servicios.tokens.verificar(token);
    } on TokenInvalido {
      _cerrar(c, CierreWs.sinSesion, mensajeSesionInvalida);
      return;
    }
    final usuario = _servicios.usuarios.porId(id);
    if (usuario == null) {
      _cerrar(c, CierreWs.sinSesion, mensajeSesionInvalida);
      return;
    }

    c.tareaAutenticacion?.cancelar();
    c.usuario = id;
    c.nombre = usuario.nombre;

    final vieja = _conexiones[id];
    _conexiones[id] = c;
    if (vieja != null) {
      _enviar(vieja, {
        'tipo': 'sesion_reemplazada',
        'mensaje': 'Abriste Brilliant en otra conexión; esta se cerrará',
      });
      _cerrar(vieja, CierreWs.reemplazada, 'Sesión abierta en otra conexión');
    }

    _enviar(c, {
      'tipo': 'autenticado',
      'usuario': {'id': id, 'nombre': usuario.nombre},
      'ultimaAccion': _ultimaAccion[id] ?? 0,
      'sala': _salaDe[id],
    });
    _programarLatido(c);

    if (_salaDe.containsKey(id)) {
      _miembroConectado(id);
    } else if (mensaje['sala'] != null) {
      // La app creía estar en una sala que ya no existe (por ejemplo, el
      // servidor se reinició).
      _salaNoExiste(c, mensaje['sala']);
    }
  }

  void _salaNoExiste(_Conexion c, Object? codigo) {
    _enviar(c, {
      'tipo': 'sala_no_existe',
      'codigo': codigo is String ? codigo : null,
      'mensaje':
          'La sala ya no existe. Puede que el servidor se haya '
          'reiniciado.',
    });
  }

  // -----------------------------------------------------------------------
  // Mensajes
  // -----------------------------------------------------------------------

  void _despachar(_Conexion c, int usuario, Map<String, Object?> mensaje) {
    final tipo = mensaje['tipo']! as String;
    switch (tipo) {
      case 'pong':
        return;
      case 'autenticar':
        _enviar(c, {
          'tipo': 'error',
          'codigo': 'ya_autenticado',
          'mensaje': 'Esta conexión ya inició sesión',
        });
        return;
      case 'reconectar':
        final codigo = normalizarCodigoSala(mensaje['codigo']);
        final sala = codigo == null ? null : _salas[codigo];
        if (sala != null && _salaDe[usuario] == codigo) {
          _enviar(c, {'tipo': 'estado', 'sala': sala.aJson(_ahora)});
        } else {
          _salaNoExiste(c, mensaje['codigo']);
        }
        return;
    }

    if (!_accionesConId.contains(tipo)) {
      _malformado(c, 'tipo_desconocido', 'No se conoce el mensaje "$tipo"');
      return;
    }
    final accion = mensaje['id'];
    if (accion is! int || accion <= 0) {
      _malformado(
        c,
        'mensaje_invalido',
        'Cada acción debe llevar un "id" entero y creciente',
      );
      return;
    }
    // Repetida o vieja: se ignora sin responder.
    if (accion <= (_ultimaAccion[usuario] ?? 0)) return;
    _ultimaAccion[usuario] = accion;

    try {
      switch (tipo) {
        case 'crear_sala':
          _crearSala(c, usuario, mensaje);
        case 'unirse':
          _unirse(c, usuario, mensaje);
        case 'listo':
          _listo(usuario, mensaje);
        case 'salir':
          _salir(c, usuario);
        case 'iniciar':
          _iniciar(usuario);
        case 'numeros_iniciales':
          final sala = _salaConPartida(usuario);
          sala.partida!.enviarNumeros(usuario, mensaje['numeros']);
          _trasCambio(sala);
        case 'colocar':
          final sala = _salaConPartida(usuario);
          sala.partida!.colocar(
            usuario,
            mensaje['dadoAncla'],
            mensaje['fila'],
            mensaje['columna'],
          );
          _trasCambio(sala);
        case 'saltar':
          final sala = _salaConPartida(usuario);
          sala.partida!.saltar(usuario);
          _trasCambio(sala);
        case 'rendirse':
          final sala = _salaConPartida(usuario);
          sala.partida!.rendirse(usuario);
          _trasCambio(sala);
      }
    } on ErrorJuego catch (e) {
      _enviar(c, {
        'tipo': 'error',
        'codigo': e.codigo,
        'mensaje': e.mensaje,
        'id': accion,
      });
    }
  }

  // -----------------------------------------------------------------------
  // Lobby
  // -----------------------------------------------------------------------

  Sala? _salaDeUsuario(int usuario) {
    final codigo = _salaDe[usuario];
    return codigo == null ? null : _salas[codigo];
  }

  Sala _exigirSala(int usuario) =>
      _salaDeUsuario(usuario) ??
      (throw const ErrorJuego('no_en_sala', 'No estás en ninguna sala'));

  Sala _salaEnLobby(int usuario) {
    final sala = _exigirSala(usuario);
    if (!sala.enLobby) {
      throw const ErrorJuego(
        'fase_incorrecta',
        'La partida de esta sala ya empezó',
      );
    }
    return sala;
  }

  Sala _salaConPartida(int usuario) {
    final sala = _exigirSala(usuario);
    if (sala.enLobby) {
      throw const ErrorJuego('fase_incorrecta', 'La partida todavía no empezó');
    }
    return sala;
  }

  /// Si el usuario está en una sala donde ya no juega (terminada, rendido o
  /// abandonó), la deja para poder entrar a otra.
  void _liberarSiYaNoJuega(int usuario) {
    final sala = _salaDeUsuario(usuario);
    final partida = sala?.partida;
    if (sala == null || partida == null) return;
    if (sala.terminada || !partida.jugador(usuario).activo) {
      _quitarDeSala(sala, usuario);
    }
  }

  void _crearSala(_Conexion c, int usuario, Map<String, Object?> mensaje) {
    _liberarSiYaNoJuega(usuario);
    if (_salaDe.containsKey(usuario)) {
      throw const ErrorJuego(
        'ya_en_sala',
        'Ya estás en una sala; sal de ella antes de crear otra',
      );
    }
    final numeroMapa = mensaje['mapa'];
    final nivel = numeroMapa is int ? nivelPorNumero(numeroMapa) : null;
    if (nivel == null) {
      throw ErrorJuego(
        'mapa_invalido',
        'El mapa debe ser uno de: '
            '${nivelesDisponibles.map((n) => n.numero).join(', ')}',
      );
    }
    final maximo = mensaje['maximo'];
    if (maximo is! int || maximo < 2 || maximo > 4) {
      throw const ErrorJuego(
        'maximo_invalido',
        'La sala debe ser de 2 a 4 jugadores',
      );
    }

    String codigo;
    do {
      codigo = generarCodigoSala(_random);
    } while (_salas.containsKey(codigo));

    final sala = Sala(
      codigo: codigo,
      nivel: nivel,
      maximo: maximo,
      creadaEn: _ahora,
    )..miembros.add(MiembroSala(usuario, c.nombre));
    sala.caducaEn = _ahora.add(opciones.caducidadLobby);
    sala.tareaCaducidad = _programador.despues(
      opciones.caducidadLobby,
      () => _cerrarSala(
        sala,
        'caducada',
        'La sala se cerró porque la partida no empezó a tiempo',
      ),
    );
    _salas[codigo] = sala;
    _salaDe[usuario] = codigo;
    _difundir(sala);
  }

  void _unirse(_Conexion c, int usuario, Map<String, Object?> mensaje) {
    for (final (limitador, clave) in [
      (_unionesUsuario, '$usuario'),
      (_unionesIp, c.ip),
    ]) {
      final falta = limitador.bloqueo(clave);
      if (falta != null) {
        throw ErrorJuego(
          'demasiados_intentos',
          'Demasiados intentos de unirte a una sala. Espera '
              '${segundosParaReintentar(falta)} segundos.',
        );
      }
    }
    _unionesUsuario.registrar('$usuario');
    _unionesIp.registrar(c.ip);

    _liberarSiYaNoJuega(usuario);
    final codigo = normalizarCodigoSala(mensaje['codigo']);
    final actual = _salaDe[usuario];
    if (actual != null) {
      if (actual == codigo) {
        _difundir(_salas[actual]!);
        return;
      }
      throw const ErrorJuego(
        'ya_en_sala',
        'Ya estás en otra sala; sal de ella antes de unirte a esta',
      );
    }
    final sala = codigo == null ? null : _salas[codigo];
    if (sala == null) {
      throw const ErrorJuego(
        'sala_inexistente',
        'No existe una sala con ese código',
      );
    }
    if (!sala.enLobby) {
      throw const ErrorJuego(
        'sala_iniciada',
        'La partida de esa sala ya empezó',
      );
    }
    if (sala.llena) {
      throw const ErrorJuego('sala_llena', 'La sala está llena');
    }
    sala.miembros.add(MiembroSala(usuario, c.nombre));
    _salaDe[usuario] = sala.codigo;
    _difundir(sala);
  }

  void _listo(int usuario, Map<String, Object?> mensaje) {
    final sala = _salaEnLobby(usuario);
    final listo = mensaje['listo'];
    if (listo is! bool) {
      throw const ErrorJuego(
        'mensaje_invalido',
        'El campo "listo" debe ser true o false',
      );
    }
    sala.miembro(usuario)!.listo = listo;
    _difundir(sala);
  }

  void _salir(_Conexion c, int usuario) {
    final sala = _exigirSala(usuario);
    final partida = sala.partida;
    if (partida != null && !sala.terminada && partida.jugador(usuario).activo) {
      throw const ErrorJuego(
        'fase_incorrecta',
        'Para dejar una partida en curso usa "rendirse"',
      );
    }
    _quitarDeSala(sala, usuario);
    _enviar(c, {'tipo': 'saliste', 'codigo': sala.codigo});
  }

  void _iniciar(int usuario) {
    final sala = _salaEnLobby(usuario);
    if (sala.anfitrion!.id != usuario) {
      throw const ErrorJuego(
        'no_eres_anfitrion',
        'Solo el anfitrión puede iniciar la partida',
      );
    }
    if (sala.miembros.length < 2) {
      throw const ErrorJuego(
        'faltan_jugadores',
        'Se necesitan al menos 2 jugadores',
      );
    }
    if (sala.miembros.any((m) => !m.listo)) {
      throw const ErrorJuego(
        'no_todos_listos',
        'Todos los jugadores deben estar listos',
      );
    }

    sala.tareaCaducidad?.cancelar();
    sala.caducaEn = null;
    final partida = Partida(
      nivel: sala.nivel,
      jugadores: [for (final m in sala.miembros) (m.id, m.nombre)],
      random: _random,
      maximoSaltosPorTiempo: opciones.maximoSaltosPorTiempo,
    );
    sala.partida = partida;
    sala.vencenNumeros = _ahora.add(opciones.numerosIniciales);
    sala.tareaNumeros = _programador.despues(opciones.numerosIniciales, () {
      partida.asignarNumerosFaltantes();
      _trasCambio(sala);
    });
    // Quien estaba caído en el lobby ahora tiene el plazo de reconexión.
    for (final m in sala.miembros.where((m) => !m.conectado)) {
      _programarAbandono(sala, m);
    }
    _trasCambio(sala);
  }

  void _quitarDeSala(Sala sala, int usuario) {
    final m = sala.miembro(usuario);
    if (m == null) return;
    m.tareaDesconexion?.cancelar();
    sala.miembros.remove(m);
    if (_salaDe[usuario] == sala.codigo) _salaDe.remove(usuario);
    if (sala.vacia) {
      _borrarSala(sala);
      return;
    }
    _revisarSinNadie(sala);
    _difundir(sala);
  }

  void _cerrarSala(Sala sala, String motivo, String mensaje) {
    for (final m in sala.miembros) {
      final c = _conexiones[m.id];
      if (c != null) {
        _enviar(c, {
          'tipo': 'sala_cerrada',
          'codigo': sala.codigo,
          'motivo': motivo,
          'mensaje': mensaje,
        });
      }
    }
    _borrarSala(sala);
  }

  void _borrarSala(Sala sala) {
    sala.cancelarTareas();
    _salas.remove(sala.codigo);
    for (final m in sala.miembros) {
      if (_salaDe[m.id] == sala.codigo) _salaDe.remove(m.id);
    }
  }

  // -----------------------------------------------------------------------
  // Partida y temporizadores
  // -----------------------------------------------------------------------

  /// Ajusta los temporizadores al estado de la partida y difunde.
  void _trasCambio(Sala sala) {
    final partida = sala.partida!;
    if (partida.fase != FasePartida.numeros) {
      sala.tareaNumeros?.cancelar();
      sala.vencenNumeros = null;
    }
    if (partida.fase == FasePartida.turnos) {
      if (sala.turnoProgramado != partida.numeroTurno) {
        sala.tareaTurno?.cancelar();
        final turno = partida.numeroTurno;
        sala.turnoProgramado = turno;
        sala.venceTurno = _ahora.add(opciones.turno);
        sala.tareaTurno = _programador.despues(opciones.turno, () {
          if (partida.fase != FasePartida.turnos ||
              partida.numeroTurno != turno) {
            return;
          }
          partida.saltar(partida.turnoDe!, porTiempo: true);
          _trasCambio(sala);
        });
      }
    } else {
      sala.tareaTurno?.cancelar();
      sala.venceTurno = null;
    }
    // Quien ya no juega no necesita plazo de reconexión.
    for (final m in sala.miembros) {
      if (partida.fase == FasePartida.terminada ||
          !partida.jugador(m.id).activo) {
        m.tareaDesconexion?.cancelar();
        m.tareaDesconexion = null;
      }
    }
    _revisarSinNadie(sala);
    _difundir(sala);
  }

  void _programarAbandono(Sala sala, MiembroSala m) {
    m.tareaDesconexion?.cancelar();
    m.tareaDesconexion = _programador.despues(opciones.reconexion, () {
      m.tareaDesconexion = null;
      sala.partida!.abandonar(m.id);
      _trasCambio(sala);
    });
  }

  /// Una partida (o sala terminada) sin nadie conectado se cierra después
  /// de un rato.
  void _revisarSinNadie(Sala sala) {
    if (!sala.enLobby && sala.nadieConectado) {
      sala.tareaSinNadie ??= _programador.despues(
        opciones.sinNadieConectado,
        () => _borrarSala(sala),
      );
    } else {
      sala.tareaSinNadie?.cancelar();
      sala.tareaSinNadie = null;
    }
  }

  void _miembroDesconectado(int usuario) {
    final sala = _salaDeUsuario(usuario);
    final m = sala?.miembro(usuario);
    if (sala == null || m == null) return;
    m.conectado = false;
    final partida = sala.partida;
    if (partida == null) {
      m.tareaDesconexion?.cancelar();
      m.tareaDesconexion = _programador.despues(
        opciones.desconexionLobby,
        () => _quitarDeSala(sala, usuario),
      );
    } else if (!sala.terminada && partida.jugador(usuario).activo) {
      // Si era su turno, el temporizador del turno sigue corriendo.
      _programarAbandono(sala, m);
    }
    _revisarSinNadie(sala);
    _difundir(sala);
  }

  void _miembroConectado(int usuario) {
    final sala = _salaDeUsuario(usuario);
    final m = sala?.miembro(usuario);
    if (sala == null || m == null) return;
    m.conectado = true;
    m.tareaDesconexion?.cancelar();
    m.tareaDesconexion = null;
    _revisarSinNadie(sala);
    _difundir(sala);
  }

  /// Manda el estado completo de la sala a todos sus miembros conectados.
  void _difundir(Sala sala) {
    final texto = jsonEncode({'tipo': 'estado', 'sala': sala.aJson(_ahora)});
    for (final m in sala.miembros) {
      final c = _conexiones[m.id];
      if (c != null && !c.cerrada) c.canal.enviar(texto);
    }
  }
}
