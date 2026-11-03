import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'config.dart';
import 'cors.dart';
import 'respuestas.dart';
import 'rutas_cuentas.dart';
import 'servicios.dart';

/// Arma el handler completo del servidor. [registrar] recibe las líneas de
/// log (por defecto no se registra nada, útil en las pruebas).
Handler crearAplicacion(
  Config config,
  Servicios servicios, {
  void Function(String)? registrar,
}) {
  final rutas = Router(
    notFoundHandler: (_) => respuestaError(404, 'Ruta no encontrada'),
  )
    ..get('/salud', (Request _) => respuestaJson(200, {'estado': 'ok'}))
    ..post('/registro', (Request p) => rutaRegistro(p, servicios));

  var pipeline = const Pipeline();
  if (registrar != null) {
    pipeline = pipeline.addMiddleware(registrarPeticiones(registrar));
  }
  return pipeline
      .addMiddleware(
        cors(
          produccion: config.produccion,
          permitidos: config.origenesPermitidos,
        ),
      )
      .addMiddleware(manejarErrores(registrar: registrar))
      .addHandler(rutas.call);
}

