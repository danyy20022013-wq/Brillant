import 'dart:convert';

import 'package:servidor_brilliant/servidor_brilliant.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

Request _peticion(String metodo, String ruta, {Map<String, String>? cabeceras}) =>
    Request(metodo, Uri.parse('http://localhost$ruta'), headers: cabeceras);

void main() {
  final desarrollo = crearAplicacion(const Config());
  final produccion = crearAplicacion(
    const Config(
      produccion: true,
      origenesPermitidos: ['https://brilliant.ejemplo.com'],
    ),
  );

  group('GET /salud', () {
    test('responde 200 con JSON', () async {
      final respuesta = await desarrollo(_peticion('GET', '/salud'));
      expect(respuesta.statusCode, 200);
      expect(respuesta.headers['content-type'], contains('application/json'));
      expect(jsonDecode(await respuesta.readAsString()), {'estado': 'ok'});
    });

    test('una ruta que no existe responde 404 en JSON', () async {
      final respuesta = await desarrollo(_peticion('GET', '/nada'));
      expect(respuesta.statusCode, 404);
      expect(jsonDecode(await respuesta.readAsString()),
          {'error': 'Ruta no encontrada'});
    });
  });

  group('Orígenes permitidos', () {
    bool dev(String origen) =>
        origenPermitido(origen, produccion: false, permitidos: const []);

    test('en desarrollo, cualquier puerto de localhost y 127.0.0.1', () {
      expect(dev('http://localhost:5000'), isTrue);
      expect(dev('http://localhost:61234'), isTrue);
      expect(dev('http://localhost'), isTrue);
      expect(dev('http://127.0.0.1:8080'), isTrue);
    });

    test('en desarrollo, nada más', () {
      expect(dev('http://evil.com'), isFalse);
      expect(dev('http://localhost.evil.com'), isFalse);
      expect(dev('https://localhost:5000'), isFalse);
      expect(dev('http://192.168.0.10:5000'), isFalse);
      expect(dev('http://localhost:5000/ruta'), isFalse);
      expect(dev('null'), isFalse);
    });

    test('en producción, solo los de la lista y exactos', () {
      bool prod(String origen) => origenPermitido(origen,
          produccion: true, permitidos: const ['https://a.com']);
      expect(prod('https://a.com'), isTrue);
      expect(prod('http://a.com'), isFalse);
      expect(prod('https://a.com:8443'), isFalse);
      expect(prod('http://localhost:5000'), isFalse);
    });
  });

  group('CORS', () {
    test('pregunta previa de un origen permitido: 204 con cabeceras',
        () async {
      final respuesta = await desarrollo(_peticion('OPTIONS', '/registro',
          cabeceras: {
            'origin': 'http://localhost:5000',
            'access-control-request-method': 'POST',
            'access-control-request-headers': 'content-type',
          }));
      expect(respuesta.statusCode, 204);
      expect(respuesta.headers['access-control-allow-origin'],
          'http://localhost:5000');
      expect(respuesta.headers['access-control-allow-methods'],
          contains('DELETE'));
      expect(respuesta.headers['access-control-allow-headers'],
          contains('Authorization'));
      expect(respuesta.headers['vary'], 'Origin');
    });

    test('pregunta previa de un origen no permitido: 403 sin cabeceras',
        () async {
      final respuesta = await desarrollo(_peticion('OPTIONS', '/salud',
          cabeceras: {'origin': 'http://evil.com'}));
      expect(respuesta.statusCode, 403);
      expect(respuesta.headers['access-control-allow-origin'], isNull);
    });

    test('petición normal de un origen permitido lleva las cabeceras',
        () async {
      final respuesta = await desarrollo(_peticion('GET', '/salud',
          cabeceras: {'origin': 'http://127.0.0.1:5000'}));
      expect(respuesta.statusCode, 200);
      expect(respuesta.headers['access-control-allow-origin'],
          'http://127.0.0.1:5000');
    });

    test('petición de un origen no permitido sale sin cabeceras CORS',
        () async {
      final respuesta = await desarrollo(
          _peticion('GET', '/salud', cabeceras: {'origin': 'http://evil.com'}));
      expect(respuesta.headers['access-control-allow-origin'], isNull);
    });

    test('sin cabecera Origin (no es un navegador) responde normal',
        () async {
      final respuesta = await desarrollo(_peticion('GET', '/salud'));
      expect(respuesta.statusCode, 200);
      expect(respuesta.headers['access-control-allow-origin'], isNull);
    });

    test('en producción localhost ya no está permitido', () async {
      final previa = await produccion(_peticion('OPTIONS', '/salud',
          cabeceras: {'origin': 'http://localhost:5000'}));
      expect(previa.statusCode, 403);

      final buena = await produccion(_peticion('OPTIONS', '/salud',
          cabeceras: {'origin': 'https://brilliant.ejemplo.com'}));
      expect(buena.statusCode, 204);
      expect(buena.headers['access-control-allow-origin'],
          'https://brilliant.ejemplo.com');
    });
  });

  group('Errores y registro', () {
    test('un error inesperado responde 500 genérico y solo registra el tipo',
        () async {
      final lineas = <String>[];
      final handler = const Pipeline()
          .addMiddleware(manejarErrores(registrar: lineas.add))
          .addHandler((_) => throw StateError('detalle secreto'));

      final respuesta = await handler(_peticion('POST', '/sesion'));
      final cuerpo = await respuesta.readAsString();
      expect(respuesta.statusCode, 500);
      expect(jsonDecode(cuerpo), {'error': 'Error interno del servidor'});
      expect(cuerpo, isNot(contains('secreto')));
      expect(lineas.single, contains('StateError'));
      expect(lineas.single, isNot(contains('secreto')));
    });

    test('el registro de peticiones no incluye cabeceras ni cuerpo', () async {
      final lineas = <String>[];
      final app = crearAplicacion(const Config(), registrar: lineas.add);
      await app(Request(
        'GET',
        Uri.parse('http://localhost/salud'),
        headers: {'authorization': 'Bearer token-de-prueba'},
      ));
      expect(lineas.single, startsWith('GET /salud 200'));
      expect(lineas.single, isNot(contains('token-de-prueba')));
    });
  });
}
