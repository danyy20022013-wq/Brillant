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

  final usuarios = RepositorioUsuarios.abrir(config.rutaBaseDatos);
  final servicios = Servicios(
    usuarios: usuarios,
    contrasenas: Contrasenas(costo: config.costoBcrypt),
    secretoJwt: config.jwtSecreto,
  );
  // Prepara el hash de relleno antes de recibir el primer inicio de sesión.
  await servicios.contrasenas.hashDeRelleno;

  final handler = crearAplicacion(config, servicios, registrar: _log);
  final servidor = await shelf_io.serve(handler, config.host, config.puerto);
  _log(
    'Servidor de Brilliant escuchando en '
    'http://${servidor.address.host}:${servidor.port} '
    '(${config.produccion ? 'producción' : 'desarrollo'})',
  );

  // Ctrl+C cierra el servidor y la base de datos de forma ordenada.
  late final StreamSubscription<ProcessSignal> senal;
  senal = ProcessSignal.sigint.watch().listen((_) async {
    _log('Cerrando el servidor…');
    await servidor.close();
    usuarios.cerrar();
    await senal.cancel();
  });
}
