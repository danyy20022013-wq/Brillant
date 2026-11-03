import 'dart:async';
import 'dart:io';

import 'package:servidor_brilliant/servidor_brilliant.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Escribe una línea de log en la consola (stdout).
void _log(String linea) => stdout.writeln(linea);

Future<void> main() async {
  final Config config;
  try {
    config = Config.cargar();
  } on ConfigException catch (e) {
    stderr.writeln('No se puede iniciar el servidor: ${e.mensaje}');
    exitCode = 78; // configuración inválida
    return;
  }

  final handler = crearAplicacion(config, registrar: _log);
  final servidor = await shelf_io.serve(handler, config.host, config.puerto);
  _log('Servidor de Brilliant escuchando en '
      'http://${servidor.address.host}:${servidor.port} '
      '(${config.produccion ? 'producción' : 'desarrollo'})');

  // Ctrl+C cierra el servidor de forma ordenada.
  late final StreamSubscription<ProcessSignal> senal;
  senal = ProcessSignal.sigint.watch().listen((_) async {
    _log('Cerrando el servidor…');
    await servidor.close();
    await senal.cancel();
  });
}
