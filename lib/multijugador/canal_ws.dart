import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Una conexión WebSocket abierta. La app usa [conectarWebSocket]; las
/// pruebas usan un canal falso.
abstract interface class CanalWs {
  /// Mensajes de texto del servidor. Termina cuando se cierra la conexión.
  Stream<String> get mensajes;

  void enviar(String texto);

  /// La cierra desde la app.
  void cerrar();

  /// Código y motivo con que la cerró el servidor (null si no se sabe).
  int? get codigoCierre;
  String? get motivoCierre;
}

/// Abre una conexión con [uri]. Lanza si no se puede conectar.
typedef ConectorWs = Future<CanalWs> Function(Uri uri);

/// Abre un WebSocket real (sirve en web, Windows y móviles).
Future<CanalWs> conectarWebSocket(Uri uri) async {
  final canal = WebSocketChannel.connect(uri);
  await canal.ready;
  return _CanalReal(canal);
}

class _CanalReal implements CanalWs {
  final WebSocketChannel _canal;

  _CanalReal(this._canal);

  @override
  Stream<String> get mensajes =>
      _canal.stream.where((dato) => dato is String).cast<String>();

  @override
  void enviar(String texto) => _canal.sink.add(texto);

  @override
  void cerrar() => unawaited(_canal.sink.close());

  @override
  int? get codigoCierre => _canal.closeCode;

  @override
  String? get motivoCierre => _canal.closeReason;
}

/// Dirección del WebSocket a partir de la del servidor HTTP:
/// http://host:8080 → ws://host:8080/ws y https → wss.
Uri urlWebSocket(Uri servidor) => Uri(
  scheme: servidor.scheme == 'https' ? 'wss' : 'ws',
  host: servidor.host,
  port: servidor.hasPort ? servidor.port : null,
  path: '/ws',
);
