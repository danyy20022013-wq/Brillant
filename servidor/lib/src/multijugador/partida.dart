import 'dart:math';

import 'package:reglas_brilliant/reglas_brilliant.dart';

/// Una acción no se puede hacer. [codigo] es estable (para la app) y
/// [mensaje] está en español para mostrarse al jugador.
class ErrorJuego implements Exception {
  final String codigo;
  final String mensaje;

  const ErrorJuego(this.codigo, this.mensaje);

  @override
  String toString() => 'ErrorJuego($codigo)';
}

/// Situación de un jugador dentro de la partida.
enum EstadoJugador {
  jugando,

  /// Se rindió: queda último, su tablero se congela.
  rendido,

  /// Se cayó y no volvió a tiempo, o se le acabó el tiempo 3 veces seguidas.
  abandono,
}

enum FasePartida { numeros, turnos, terminada }

class JugadorPartida {
  final int id;
  final String nombre;
  List<int>? numeros;
  Juego? tablero;
  EstadoJugador estado = EstadoJugador.jugando;

  /// Turnos seguidos que se le acabó el tiempo.
  int saltosPorTiempo = 0;

  /// En qué orden dejó la partida (1 = el primero). null si sigue.
  int? salida;

  JugadorPartida(this.id, this.nombre);

  bool get activo => estado == EstadoJugador.jugando;
}

/// Lugar final de un jugador.
class Posicion {
  final int id;
  final int posicion;
  final int puntaje;
  final EstadoJugador estado;

  const Posicion(this.id, this.posicion, this.puntaje, this.estado);

  Map<String, Object?> aJson() => {
    'id': id,
    'posicion': posicion,
    'puntaje': puntaje,
    'estado': estado.name,
  };
}

/// La partida de una sala. El servidor es la autoridad: tira los dados,
/// sortea el orden y valida cada jugada con las reglas compartidas.
class Partida {
  final Nivel nivel;
  final Random _random;

  /// Turnos seguidos agotados que cuentan como abandono.
  final int maximoSaltosPorTiempo;

  /// En el orden de la sala.
  final List<JugadorPartida> jugadores;

  FasePartida fase = FasePartida.numeros;

  /// Ids en el orden de turnos (sorteado). Los que ya no juegan se saltan.
  List<int> orden = const [];

  /// Id del jugador que tiene el turno.
  int? turnoDe;

  /// Cuenta los turnos desde 1; cambia en cada turno nuevo.
  int numeroTurno = 0;

  int? dado1;
  int? dado2;

  /// Por cada zona del mapa, los ids de quienes la llenaron, en orden.
  late final List<List<int>> ordenZonas = List.generate(
    nivel.estructura.zonas.length,
    (_) => <int>[],
  );

  /// Lo último que pasó, para que la app lo muestre.
  Map<String, Object?>? ultimoMovimiento;

  int _salidas = 0;

  Partida({
    required this.nivel,
    required List<(int, String)> jugadores,
    required Random random,
    this.maximoSaltosPorTiempo = 3,
  }) : _random = random,
       jugadores = [
         for (final (id, nombre) in jugadores) JugadorPartida(id, nombre),
       ];

  JugadorPartida jugador(int id) => jugadores.firstWhere((j) => j.id == id);

  bool participa(int id) => jugadores.any((j) => j.id == id);

  Iterable<JugadorPartida> get activos => jugadores.where((j) => j.activo);

  int puntajeDe(int id) => puntajeTotal(nivel.estructura, ordenZonas, id);

  // ---------------------------------------------------------------------
  // Fase de números iniciales
  // ---------------------------------------------------------------------

  void enviarNumeros(int id, Object? numeros) {
    _exigirFase(FasePartida.numeros);
    final j = _exigirActivo(id);
    if (j.numeros != null) {
      throw const ErrorJuego(
        'numeros_ya_enviados',
        'Ya enviaste tus números iniciales',
      );
    }
    final lista = numeros is List && numeros.every((n) => n is int)
        ? numeros.cast<int>().toList()
        : null;
    if (lista == null || !numerosInicialesValidos(nivel, lista)) {
      throw const ErrorJuego(
        'numeros_invalidos',
        'Los números iniciales deben ser 6 números del 1 al 6, sin repetir, '
            'que respeten la regla de la zona de cada estrella',
      );
    }
    j.numeros = List.unmodifiable(lista);
    _empezarTurnosSiTodosListos();
  }

  /// Se acabó el tiempo de la fase de números: a quien no los mandó se le
  /// asignan unos válidos al azar.
  void asignarNumerosFaltantes() {
    if (fase != FasePartida.numeros) return;
    for (final j in activos) {
      j.numeros ??= numerosInicialesAlAzar(nivel, _random);
    }
    _empezarTurnosSiTodosListos();
  }

  void _empezarTurnosSiTodosListos() {
    if (activos.any((j) => j.numeros == null)) return;
    if (_terminarSiQuedaUno()) return;
    for (final j in jugadores) {
      if (j.numeros != null) {
        j.tablero = Juego.inicial(j.numeros!, nivel: nivel);
      }
    }
    final ids = [for (final j in activos) j.id]..shuffle(_random);
    orden = List.unmodifiable(ids);
    fase = FasePartida.turnos;
    _empezarTurno(ids.first);
  }

  // ---------------------------------------------------------------------
  // Turnos
  // ---------------------------------------------------------------------

  void _empezarTurno(int id) {
    turnoDe = id;
    numeroTurno++;
    dado1 = _random.nextInt(6) + 1;
    dado2 = _random.nextInt(6) + 1;
  }

  /// Coloca el otro dado junto a un número igual al dado [dadoAncla]
  /// (0 = dado 1, 1 = dado 2), en la casilla ([fila], [columna]).
  void colocar(int id, Object? dadoAncla, Object? fila, Object? columna) {
    final j = _exigirTurno(id);
    if (dadoAncla is! int ||
        (dadoAncla != 0 && dadoAncla != 1) ||
        fila is! int ||
        columna is! int) {
      throw const ErrorJuego(
        'jugada_invalida',
        'La jugada debe indicar el dado ancla (0 o 1), la fila y la columna',
      );
    }
    final ancla = dadoAncla == 0 ? dado1! : dado2!;
    final valor = dadoAncla == 0 ? dado2! : dado1!;
    final antes = j.tablero!;
    if (!antes.jugadasPosibles(ancla: ancla, aColocar: valor).contains((
      fila,
      columna,
    ))) {
      throw const ErrorJuego(
        'jugada_invalida',
        'No puedes colocar ese número en esa casilla',
      );
    }

    final despues = antes.colocar(fila, columna, valor);
    j.tablero = despues;
    j.saltosPorTiempo = 0;

    final estructura = nivel.estructura;
    final z = estructura.indiceZona[fila][columna];
    Map<String, Object?>? completada;
    if (!antes.zonaLlena(z) && despues.zonaLlena(z)) {
      ordenZonas[z].add(id);
      final lugar = ordenZonas[z].length - 1;
      completada = {
        'zona': z,
        'nombre': estructura.zonas[z].nombre,
        'lugar': lugar + 1,
        'puntos': puntosPorLugar(estructura.zonas[z].puntos, lugar),
      };
    }
    ultimoMovimiento = {
      'tipo': 'colocacion',
      'jugador': id,
      'turno': numeroTurno,
      'ancla': ancla,
      'colocado': valor,
      'fila': fila,
      'columna': columna,
      'zona': estructura.zonas[z].nombre,
      'zonaCompletada': completada,
    };
    _pasarTurno();
  }

  /// Descarta la tirada. Con [porTiempo] cuenta para el abandono.
  void saltar(int id, {bool porTiempo = false}) {
    final j = _exigirTurno(id);
    ultimoMovimiento = {
      'tipo': porTiempo ? 'tiempo_agotado' : 'salto',
      'jugador': id,
      'turno': numeroTurno,
    };
    if (!porTiempo) {
      j.saltosPorTiempo = 0;
      _pasarTurno();
      return;
    }
    j.saltosPorTiempo++;
    if (j.saltosPorTiempo >= maximoSaltosPorTiempo) {
      _dejar(j, EstadoJugador.abandono);
    } else {
      _pasarTurno();
    }
  }

  void rendirse(int id) {
    if (fase == FasePartida.terminada) {
      throw const ErrorJuego('partida_terminada', 'La partida ya terminó');
    }
    _dejar(_exigirActivo(id), EstadoJugador.rendido);
  }

  /// Se cayó y no volvió a tiempo.
  void abandonar(int id) {
    if (fase == FasePartida.terminada || !participa(id)) return;
    final j = jugador(id);
    if (!j.activo) return;
    _dejar(j, EstadoJugador.abandono);
  }

  void _dejar(JugadorPartida j, EstadoJugador estado) {
    j.estado = estado;
    j.salida = ++_salidas;
    ultimoMovimiento = {
      'tipo': estado == EstadoJugador.rendido ? 'rendicion' : 'abandono',
      'jugador': j.id,
      'turno': numeroTurno,
    };
    if (_terminarSiQuedaUno()) return;
    if (fase == FasePartida.numeros) {
      _empezarTurnosSiTodosListos();
      return;
    }
    if (turnoDe == j.id) _pasarTurno();
  }

  /// Le da el turno al siguiente jugador activo con espacio en su tablero.
  /// Si no queda ninguno, la partida termina.
  void _pasarTurno() {
    if (_terminarSiQuedaUno()) return;
    final actual = orden.indexOf(turnoDe!);
    for (var i = 1; i <= orden.length; i++) {
      final j = jugador(orden[(actual + i) % orden.length]);
      if (j.activo && !j.tablero!.estaLleno) {
        _empezarTurno(j.id);
        return;
      }
    }
    _terminar();
  }

  bool _terminarSiQuedaUno() {
    if (activos.length > 1) return false;
    _terminar();
    return true;
  }

  void _terminar() {
    fase = FasePartida.terminada;
    turnoDe = null;
    dado1 = null;
    dado2 = null;
  }

  /// Posiciones finales: los activos por puntaje (con empates: 1, 1, 3) y
  /// después los que se rindieron o abandonaron, sin importar su puntaje
  /// (el último en irse queda mejor).
  List<Posicion> resultado() {
    // Con el mismo puntaje se ordena por id para que el resultado sea
    // siempre igual (comparten la posición igual).
    final siguen = [...activos]
      ..sort((a, b) {
        final c = puntajeDe(b.id).compareTo(puntajeDe(a.id));
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    final resultado = <Posicion>[];
    for (var i = 0; i < siguen.length; i++) {
      final puntos = puntajeDe(siguen[i].id);
      final posicion = i > 0 && puntos == resultado[i - 1].puntaje
          ? resultado[i - 1].posicion
          : i + 1;
      resultado.add(Posicion(siguen[i].id, posicion, puntos, siguen[i].estado));
    }
    final fuera = jugadores.where((j) => !j.activo).toList()
      ..sort((a, b) => b.salida!.compareTo(a.salida!));
    for (final j in fuera) {
      resultado.add(
        Posicion(j.id, resultado.length + 1, puntajeDe(j.id), j.estado),
      );
    }
    return resultado;
  }

  // ---------------------------------------------------------------------

  void _exigirFase(FasePartida esperada) {
    if (fase == esperada) return;
    throw ErrorJuego(
      fase == FasePartida.terminada ? 'partida_terminada' : 'fase_incorrecta',
      fase == FasePartida.terminada
          ? 'La partida ya terminó'
          : 'Esa acción no corresponde a esta fase de la partida',
    );
  }

  JugadorPartida _exigirActivo(int id) {
    if (!participa(id)) {
      throw const ErrorJuego('no_en_sala', 'No estás en esta partida');
    }
    final j = jugador(id);
    if (!j.activo) {
      throw const ErrorJuego(
        'ya_no_juegas',
        'Ya no participas en esta partida',
      );
    }
    return j;
  }

  JugadorPartida _exigirTurno(int id) {
    _exigirFase(FasePartida.turnos);
    final j = _exigirActivo(id);
    if (turnoDe != id) {
      throw const ErrorJuego('fuera_de_turno', 'No es tu turno');
    }
    return j;
  }
}
