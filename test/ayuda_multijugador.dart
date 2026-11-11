import 'dart:async';
import 'dart:convert';

import 'package:juego_brilliant/multijugador/canal_ws.dart';
import 'package:juego_brilliant/multijugador/conexion_multijugador.dart';
import 'package:juego_brilliant/multijugador/multijugador_cubit.dart';
import 'package:juego_brilliant/multijugador/pantalla_sala.dart';

/// Canal falso: la prueba hace de servidor.
class CanalFalso implements CanalWs {
  final _entrada = StreamController<String>();
  final List<Map<String, Object?>> enviados = [];
  bool cerradoPorLaApp = false;

  @override
  int? codigoCierre;
  @override
  String? motivoCierre;

  @override
  Stream<String> get mensajes => _entrada.stream;

  @override
  void enviar(String texto) =>
      enviados.add(jsonDecode(texto) as Map<String, Object?>);

  @override
  void cerrar() {
    cerradoPorLaApp = true;
    if (!_entrada.isClosed) unawaited(_entrada.close());
  }

  /// El servidor manda [mensaje].
  void recibir(Map<String, Object?> mensaje) {
    if (!_entrada.isClosed) _entrada.add(jsonEncode(mensaje));
  }

  /// El servidor (o la red) corta la conexión.
  void cortar({int? codigo, String? motivo}) {
    codigoCierre = codigo;
    motivoCierre = motivo;
    if (!_entrada.isClosed) unawaited(_entrada.close());
  }

  List<Map<String, Object?>> de(String tipo) =>
      enviados.where((m) => m['tipo'] == tipo).toList();

  Map<String, Object?>? ultimo(String tipo) {
    final lista = de(tipo);
    return lista.isEmpty ? null : lista.last;
  }

  /// Respuesta a "autenticar".
  void autenticado(
    int id,
    String nombre, {
    String? sala,
    int ultimaAccion = 0,
  }) => recibir({
    'tipo': 'autenticado',
    'usuario': {'id': id, 'nombre': nombre},
    'ultimaAccion': ultimaAccion,
    'sala': sala,
  });

  void estado(Map<String, Object?> sala) =>
      recibir({'tipo': 'estado', 'sala': sala});

  void error(String codigo, String mensaje, {int? id}) => recibir({
    'tipo': 'error',
    'codigo': codigo,
    'mensaje': mensaje,
    'id': ?id,
  });
}

/// Servidor falso: entrega un canal nuevo en cada conexión.
class ServidorFalso {
  final List<CanalFalso> canales = [];
  final List<Uri> urls = [];

  /// Si es false, conectarse falla (servidor apagado o sin red).
  bool disponible = true;

  int get intentos => urls.length;

  Future<CanalWs> conectar(Uri uri) async {
    urls.add(uri);
    if (!disponible) throw StateError('sin servidor');
    final canal = CanalFalso();
    canales.add(canal);
    return canal;
  }

  CanalFalso get actual => canales.last;
}

/// Reloj que las pruebas adelantan a mano.
class RelojFalso {
  DateTime ahora = DateTime(2026, 11, 10, 12);

  DateTime call() => ahora;

  void avanzar(Duration d) => ahora = ahora.add(d);
}

final urlDePrueba = Uri.parse('ws://servidor.prueba/ws');

ConexionMultijugador conexionDePrueba(
  ServidorFalso servidor, {
  String? token = 'token-de-prueba',
  List<Duration> esperas = const [Duration.zero],
  int maximoIntentos = 3,
  Duration silencioMaximo = const Duration(hours: 1),
}) => ConexionMultijugador(
  url: urlDePrueba,
  token: () async => token,
  conectar: servidor.conectar,
  esperas: esperas,
  maximoIntentos: maximoIntentos,
  silencioMaximo: silencioMaximo,
);

/// Abre salas contra el servidor falso (para BrilliantApp y la pantalla).
AbrirSala abrirSalaDePrueba(
  ServidorFalso servidor, {
  RelojFalso? reloj,
  List<Duration> esperas = const [Duration(seconds: 1)],
  int maximoIntentos = 3,
}) =>
    (accion) => MultijugadorCubit(
      conexion: conexionDePrueba(
        servidor,
        esperas: esperas,
        maximoIntentos: maximoIntentos,
      ),
      accionInicial: accion,
      reloj: reloj?.call,
    );

/// Deja correr los microtasks (mensajes del canal falso) en pruebas sin
/// widgets.
Future<void> pasar() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

// -------------------------------------------------------------------------
// JSON igual al que difunde el servidor (ver servidor/README.md).
// -------------------------------------------------------------------------

Map<String, Object?> jugadorJson(
  int id,
  String nombre, {
  bool anfitrion = false,
  bool listo = false,
  bool conectado = true,
  bool enSala = true,
  String? estado,
  bool numerosEnviados = false,
  List<List<int?>>? tablero,
  int puntaje = 0,
}) => {
  'id': id,
  'nombre': nombre,
  'anfitrion': anfitrion,
  'listo': listo,
  'enSala': enSala,
  'conectado': conectado,
  if (estado != null) ...{
    'estado': estado,
    'numerosEnviados': numerosEnviados,
    'tablero': tablero,
    'puntaje': puntaje,
    'saltosPorTiempo': 0,
  },
};

Map<String, Object?> lobbyJson({
  String codigo = 'K7M2QX',
  int mapa = 1,
  int maximo = 2,
  required List<Map<String, Object?>> jugadores,
  int segundosParaCaducar = 900,
}) => {
  'codigo': codigo,
  'mapa': mapa,
  'maximo': maximo,
  'fase': 'lobby',
  'anfitrion': jugadores.firstWhere((j) => j['anfitrion'] == true)['id'],
  'jugadores': jugadores,
  'caducaEn': '2026-11-10T12:15:00.000Z',
  'segundosParaCaducar': segundosParaCaducar,
};

/// Tablero del mapa 1 con los números 1..6 en las estrellas.
List<List<int?>> tableroInicial() {
  final t = List.generate(7, (_) => List<int?>.filled(7, null));
  const estrellas = [(0, 2), (1, 5), (3, 1), (3, 4), (5, 2), (6, 4)];
  for (var i = 0; i < estrellas.length; i++) {
    t[estrellas[i].$1][estrellas[i].$2] = i + 1;
  }
  return t;
}

Map<String, Object?> partidaJson({
  String codigo = 'K7M2QX',
  int mapa = 1,
  String fase = 'turnos',
  required List<Map<String, Object?>> jugadores,
  List<int>? orden,
  int? turnoDe,
  int numeroTurno = 1,
  List<int> dados = const [1, 5],
  int segundosRestantes = 60,
  Map<String, Object?>? ultimoMovimiento,
  List<Map<String, Object?>>? resultado,
  List<List<int>>? ordenZonas,
  int? segundosParaNumeros,
}) {
  final ids = [for (final j in jugadores) j['id']! as int];
  return {
    'codigo': codigo,
    'mapa': mapa,
    'maximo': jugadores.length,
    'fase': fase,
    'anfitrion': ids.first,
    'jugadores': jugadores,
    'vencenNumeros': null,
    'segundosParaNumeros': segundosParaNumeros,
    'orden': fase == 'numeros' ? <int>[] : (orden ?? ids),
    'turno': fase == 'turnos'
        ? {
            'jugador': turnoDe ?? (orden ?? ids).first,
            'numero': numeroTurno,
            'dados': dados,
            'venceEn': '2026-11-10T12:01:00.000Z',
            'segundosRestantes': segundosRestantes,
          }
        : null,
    'ordenZonas': ordenZonas ?? List.generate(9, (_) => <int>[]),
    'ultimoMovimiento': ultimoMovimiento,
    'resultado': resultado,
  };
}
