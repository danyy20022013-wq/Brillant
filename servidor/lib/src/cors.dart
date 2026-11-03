import 'package:shelf/shelf.dart';

const _metodos = 'GET, POST, DELETE, OPTIONS';
const _cabeceras = 'Authorization, Content-Type';

/// true si [origen] puede llamar al servidor desde el navegador.
///
/// En desarrollo se acepta cualquier puerto de http://localhost y
/// http://127.0.0.1 (Flutter web usa un puerto al azar). En producción solo
/// los orígenes exactos de [permitidos].
bool origenPermitido(
  String origen, {
  required bool produccion,
  required List<String> permitidos,
}) {
  if (produccion) return permitidos.contains(origen);
  final uri = Uri.tryParse(origen);
  if (uri == null || uri.scheme != 'http') return false;
  if (uri.path.isNotEmpty || uri.hasQuery || uri.hasFragment) return false;
  return uri.host == 'localhost' || uri.host == '127.0.0.1';
}

/// Middleware CORS propio.
///
/// - Pregunta previa (OPTIONS) de un origen permitido: 204 con las cabeceras.
/// - Pregunta previa de un origen no permitido: 403 sin cabeceras CORS.
/// - Resto de peticiones: si el origen está permitido se agregan las
///   cabeceras; si no, la respuesta sale sin ellas y el navegador la bloquea.
Middleware cors({required bool produccion, required List<String> permitidos}) {
  Map<String, String> cabecerasPara(String origen) => {
    'Access-Control-Allow-Origin': origen,
    'Access-Control-Allow-Methods': _metodos,
    'Access-Control-Allow-Headers': _cabeceras,
    'Access-Control-Max-Age': '600',
    'Vary': 'Origin',
  };

  return (Handler interno) {
    return (Request peticion) async {
      final origen = peticion.headers['origin'];
      final permitido =
          origen != null &&
          origenPermitido(
            origen,
            produccion: produccion,
            permitidos: permitidos,
          );

      if (peticion.method == 'OPTIONS') {
        if (!permitido) return Response.forbidden(null);
        return Response(204, headers: cabecerasPara(origen));
      }

      final respuesta = await interno(peticion);
      if (!permitido) return respuesta;
      return respuesta.change(headers: cabecerasPara(origen));
    };
  };
}
