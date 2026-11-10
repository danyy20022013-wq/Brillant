import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:reglas_brilliant/reglas_brilliant.dart';
import 'package:servidor_brilliant/servidor_brilliant.dart';

import 'ayuda.dart';

/// Programador con tiempo falso: las tareas se ejecutan al adelantar el
/// reloj con [avanzar], en orden de vencimiento.
class ProgramadorDePrueba implements Programador {
  final RelojDePrueba reloj;
  final List<_TareaDePrueba> _tareas = [];
  int _secuencia = 0;

  ProgramadorDePrueba(this.reloj);

  @override
  Tarea despues(Duration espera, void Function() accion) {
    final tarea = _TareaDePrueba(reloj.ahora.add(espera), _secuencia++, accion);
    _tareas.add(tarea);
    return tarea;
  }

  /// Tareas que todavía no se ejecutaron ni se cancelaron.
  int get pendientes => _tareas.where((t) => !t.cancelada).length;

  /// Adelanta el reloj [tiempo], ejecutando lo que venza en el camino.
  void avanzar(Duration tiempo) {
    final destino = reloj.ahora.add(tiempo);
    while (true) {
      _tareas.removeWhere((t) => t.cancelada);
      final listas = _tareas.where((t) => !t.vence.isAfter(destino)).toList()
        ..sort((a, b) {
          final c = a.vence.compareTo(b.vence);
          return c != 0 ? c : a.orden.compareTo(b.orden);
        });
      if (listas.isEmpty) break;
      final tarea = listas.first;
      _tareas.remove(tarea);
      if (tarea.vence.isAfter(reloj.ahora)) reloj.ahora = tarea.vence;
      tarea.accion();
    }
    reloj.ahora = destino;
  }
}

class _TareaDePrueba implements Tarea {
  final DateTime vence;
  final int orden;
  final void Function() accion;
  bool cancelada = false;

  _TareaDePrueba(this.vence, this.orden, this.accion);

  @override
  void cancelar() => cancelada = true;
}

/// Cliente WebSocket simulado: lo que manda llega al servidor en el acto y
/// guarda todo lo que el servidor le contesta.
class ClienteSimulado implements CanalCliente {
  final _salida = StreamController<Object?>(sync: true);
  final List<Map<String, Object?>> recibidos = [];
  int? codigoCierre;
  String? motivoCierre;

  /// Responde solo a los ping (como haría la app).
  bool responderPings = true;

  int _siguienteId = 1;

  @override
  Stream<Object?> get mensajes => _salida.stream;

  @override
  void enviar(String texto) {
    final mensaje = jsonDecode(texto) as Map<String, Object?>;
    recibidos.add(mensaje);
    // Como la app: al reconectarse sigue desde la última acción que el
    // servidor ya conoce.
    if (mensaje['tipo'] == 'autenticado') {
      _siguienteId = max(_siguienteId, (mensaje['ultimaAccion']! as int) + 1);
    }
    if (responderPings && mensaje['tipo'] == 'ping' && !cerrado) {
      mandar({'tipo': 'pong'});
    }
  }

  @override
  void cerrar(int codigo, String motivo) {
    codigoCierre = codigo;
    motivoCierre = motivo;
    unawaited(_salida.close());
  }

  bool get cerrado => codigoCierre != null || _salida.isClosed;

  /// El cliente corta la conexión (se cae la red, cierra la app...).
  void cortar() => unawaited(_salida.close());

  void mandarTexto(Object? dato) => _salida.add(dato);

  void mandar(Map<String, Object?> mensaje) => mandarTexto(jsonEncode(mensaje));

  /// Manda una acción con el siguiente id creciente y devuelve ese id.
  int accion(String tipo, [Map<String, Object?> datos = const {}]) {
    final id = _siguienteId++;
    mandar({'tipo': tipo, 'id': id, ...datos});
    return id;
  }

  /// Fija el próximo id (para simular repetidos o viejos).
  set siguienteId(int id) => _siguienteId = id;

  List<Map<String, Object?>> de(String tipo) =>
      recibidos.where((m) => m['tipo'] == tipo).toList();

  Map<String, Object?>? ultimo(String tipo) {
    final lista = de(tipo);
    return lista.isEmpty ? null : lista.last;
  }

  /// Último estado de sala recibido.
  Map<String, Object?> get sala =>
      ultimo('estado')!['sala']! as Map<String, Object?>;

  Map<String, Object?>? get ultimoError => ultimo('error');

  void olvidar() => recibidos.clear();
}

/// Servidor multijugador completo en memoria, con tiempo falso.
class Mesa {
  final reloj = RelojDePrueba();
  late final programador = ProgramadorDePrueba(reloj);
  final usuarios = RepositorioUsuarios.enMemoria();
  late final Servicios servicios;
  late final Multijugador mj;
  final Map<String, int> _ids = {};

  Mesa({
    OpcionesMultijugador opciones = const OpcionesMultijugador(),
    int semilla = 1,
  }) {
    servicios = Servicios(
      usuarios: usuarios,
      contrasenas: Contrasenas(costo: costoDePrueba),
      secretoJwt: secretoDePrueba,
      reloj: reloj.call,
    );
    mj = Multijugador(
      servicios: servicios,
      programador: programador,
      random: Random(semilla),
      opciones: opciones,
    );
  }

  /// Id del usuario [nombre] (lo crea la primera vez).
  int idDe(String nombre) => _ids[nombre] ??= usuarios
      .crear(
        nombre: nombre,
        correo: '$nombre@correo.com',
        hash: 'sin-hash-en-pruebas',
        creadoEn: reloj.ahora,
      )
      .id;

  String tokenDe(String nombre) => servicios.tokens.emitir(idDe(nombre)).token;

  /// Conecta un cliente sin autenticarse todavía.
  ClienteSimulado abrir({String ip = '10.0.0.1'}) {
    final cliente = ClienteSimulado();
    mj.conectar(cliente, ip: ip);
    return cliente;
  }

  /// Conecta y se autentica como [nombre].
  ClienteSimulado entrar(
    String nombre, {
    String ip = '10.0.0.1',
    String? sala,
  }) {
    final cliente = abrir(ip: ip);
    cliente.mandar({
      'tipo': 'autenticar',
      'token': tokenDe(nombre),
      'sala': ?sala,
    });
    return cliente;
  }

  /// Crea una sala con [anfitrion] y une al resto. Devuelve el código.
  String salaCon(List<ClienteSimulado> clientes, {int mapa = 1, int? maximo}) {
    clientes.first.accion('crear_sala', {
      'mapa': mapa,
      'maximo': maximo ?? max(2, clientes.length),
    });
    final codigo = clientes.first.sala['codigo']! as String;
    for (final c in clientes.skip(1)) {
      c.accion('unirse', {'codigo': codigo});
    }
    return codigo;
  }

  /// Sala con todos listos y la partida iniciada (fase de números).
  String partidaCon(List<ClienteSimulado> clientes, {int mapa = 1}) {
    final codigo = salaCon(clientes, mapa: mapa);
    for (final c in clientes) {
      c.accion('listo', {'listo': true});
    }
    clientes.first.accion('iniciar');
    return codigo;
  }

  /// Todos mandan números válidos: empiezan los turnos.
  void mandarNumeros(List<ClienteSimulado> clientes, {Nivel? nivel}) {
    final mapa = nivel ?? nivel1;
    final numeros = combinacionesIniciales(mapa).first;
    for (final c in clientes) {
      c.accion('numeros_iniciales', {'numeros': numeros});
    }
  }

  void cerrar() {
    mj.cerrar();
    usuarios.cerrar();
  }
}

/// Atajos para leer el estado de la sala.
extension LeerSala on Map<String, Object?> {
  List<Map<String, Object?>> get jugadores =>
      (this['jugadores']! as List).cast<Map<String, Object?>>();

  Map<String, Object?> jugador(int id) =>
      jugadores.firstWhere((j) => j['id'] == id);

  Map<String, Object?>? get turno => this['turno'] as Map<String, Object?>?;

  int? get turnoDe => turno?['jugador'] as int?;

  List<int> get dados => (turno!['dados']! as List).cast<int>();

  List<Map<String, Object?>> get resultado =>
      (this['resultado']! as List).cast<Map<String, Object?>>();
}

/// El jugador del turno hace una jugada válida si la hay; si no, salta.
/// Devuelve true si colocó.
bool jugarTurno(Mesa mesa, String codigo, Map<int, ClienteSimulado> clientes) {
  final p = mesa.mj.sala(codigo)!.partida!;
  final id = p.turnoDe!;
  final tablero = p.jugador(id).tablero!;
  for (final dadoAncla in [0, 1]) {
    final ancla = dadoAncla == 0 ? p.dado1! : p.dado2!;
    final valor = dadoAncla == 0 ? p.dado2! : p.dado1!;
    final jugadas = tablero.jugadasPosibles(ancla: ancla, aColocar: valor);
    if (jugadas.isNotEmpty) {
      final (fila, columna) = jugadas.first;
      clientes[id]!.accion('colocar', {
        'dadoAncla': dadoAncla,
        'fila': fila,
        'columna': columna,
      });
      return true;
    }
  }
  clientes[id]!.accion('saltar');
  return false;
}

/// Juega turnos hasta que la partida termina. Devuelve cuántos turnos fueron.
int jugarHastaTerminar(
  Mesa mesa,
  String codigo,
  Map<int, ClienteSimulado> clientes, {
  int limite = 50000,
}) {
  var turnos = 0;
  while (mesa.mj.sala(codigo)!.partida!.fase != FasePartida.terminada) {
    jugarTurno(mesa, codigo, clientes);
    if (++turnos % 200 == 0) {
      for (final c in clientes.values) {
        c.recibidos.removeRange(0, c.recibidos.length - 1);
      }
    }
    if (turnos > limite) throw StateError('La partida no terminó');
  }
  return turnos;
}
