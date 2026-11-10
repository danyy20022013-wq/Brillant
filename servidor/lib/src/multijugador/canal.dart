import 'package:web_socket_channel/web_socket_channel.dart';

/// Códigos de cierre propios (rango 4000-4999 de WebSocket).
abstract final class CierreWs {
  /// No llegó el token a tiempo, o no es válido.
  static const sinSesion = 4001;

  /// La misma cuenta se conectó desde otro lugar.
  static const reemplazada = 4002;

  /// Demasiados mensajes mal formados.
  static const abuso = 4003;

  /// No respondió a los latidos.
  static const sinLatido = 4004;

  /// El servidor se está apagando.
  static const servidorCerrado = 4005;
}

/// Conexión con un cliente. El servidor real usa [CanalWebSocket]; las
/// pruebas usan clientes simulados.
abstract interface class CanalCliente {
  /// Mensajes que manda el cliente (texto o bytes). Termina al cerrarse.
  Stream<Object?> get mensajes;

  void enviar(String texto);

  void cerrar(int codigo, String motivo);
}

class CanalWebSocket implements CanalCliente {
  final WebSocketChannel _canal;

  CanalWebSocket(this._canal);

  @override
  Stream<Object?> get mensajes => _canal.stream;

  @override
  void enviar(String texto) => _canal.sink.add(texto);

  @override
  void cerrar(int codigo, String motivo) {
    // El motivo de cierre de WebSocket admite hasta 123 bytes.
    _canal.sink.close(codigo, motivo);
  }
}
