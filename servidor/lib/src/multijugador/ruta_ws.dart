import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../autenticacion.dart';
import '../config.dart';
import '../cors.dart';
import '../respuestas.dart';
import 'canal.dart';
import 'multijugador.dart';

/// GET /ws: abre la conexión del multijugador.
///
/// El token NO va en la URL (quedaría en logs y en el historial): llega en
/// el primer mensaje. Si el navegador manda Origin, debe ser un origen
/// permitido (mismas reglas que CORS); las apps nativas no mandan Origin y
/// se autentican igual con el token.
Handler rutaWebSocket(Config config, Multijugador multijugador) {
  return (Request peticion) {
    final origen = peticion.headers['origin'];
    if (origen != null &&
        !origenPermitido(
          origen,
          produccion: config.produccion,
          permitidos: config.origenesPermitidos,
        )) {
      return respuestaError(403, 'Origen no permitido');
    }
    final ip = ipDe(peticion);
    return webSocketHandler(
      (WebSocketChannel canal, String? _) =>
          multijugador.conectar(CanalWebSocket(canal), ip: ip),
    )(peticion);
  };
}
