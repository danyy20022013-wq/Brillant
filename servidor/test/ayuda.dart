import 'dart:convert';
import 'dart:io';

import 'package:servidor_brilliant/servidor_brilliant.dart';
import 'package:shelf/shelf.dart';

/// Costo bajo para que las pruebas sean rápidas (en producción es 10+).
const costoDePrueba = 4;

/// Reloj que las pruebas pueden adelantar sin esperar.
class RelojDePrueba {
  DateTime ahora = DateTime.utc(2026, 11, 3, 12);

  DateTime call() => ahora;

  void avanzar(Duration tiempo) => ahora = ahora.add(tiempo);
}

/// Respuesta ya leída: estado, cabeceras y cuerpo JSON.
class Respuesta {
  final int estado;
  final Map<String, String> cabeceras;
  final Object? cuerpo;

  const Respuesta(this.estado, this.cabeceras, this.cuerpo);

  Map<String, Object?> get json => cuerpo! as Map<String, Object?>;
  String? get error => json['error'] as String?;
}

/// IP falsa para las pruebas del límite por IP.
class _Conexion implements HttpConnectionInfo {
  @override
  final InternetAddress remoteAddress;

  _Conexion(String ip) : remoteAddress = InternetAddress(ip);

  @override
  int get localPort => 8080;

  @override
  int get remotePort => 50000;
}

/// Un servidor completo en memoria, sin abrir puertos.
class ServidorDePrueba {
  final reloj = RelojDePrueba();
  final usuarios = RepositorioUsuarios.enMemoria();
  late final Servicios servicios;
  late final Handler handler;

  ServidorDePrueba({Config config = const Config()}) {
    servicios = Servicios(
      usuarios: usuarios,
      contrasenas: const Contrasenas(costo: costoDePrueba),
      reloj: reloj.call,
    );
    handler = crearAplicacion(config, servicios);
  }

  /// Hace una petición. [cuerpo] puede ser un mapa (se manda como JSON) o
  /// un texto (se manda tal cual).
  Future<Respuesta> pedir(
    String metodo,
    String ruta, {
    Object? cuerpo,
    String? token,
    String ip = '10.0.0.1',
    Map<String, String> cabeceras = const {},
  }) async {
    final respuesta = await handler(Request(
      metodo,
      Uri.parse('http://localhost$ruta'),
      body: cuerpo is String ? cuerpo : (cuerpo == null ? null : jsonEncode(cuerpo)),
      headers: {
        if (cuerpo != null) 'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
        ...cabeceras,
      },
      context: {'shelf.io.connection_info': _Conexion(ip)},
    ));
    final texto = await respuesta.readAsString();
    return Respuesta(
      respuesta.statusCode,
      respuesta.headers,
      texto.isEmpty ? null : jsonDecode(texto),
    );
  }

  Future<Respuesta> registrar({
    String nombre = 'dany',
    String correo = 'dany@correo.com',
    String contrasena = 'secreta1',
    String ip = '10.0.0.1',
  }) =>
      pedir('POST', '/registro', ip: ip, cuerpo: {
        'nombre': nombre,
        'correo': correo,
        'contrasena': contrasena,
      });

  void cerrar() => usuarios.cerrar();
}
