import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:servidor_brilliant/servidor_brilliant.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'ayuda.dart';
import 'ayuda_multijugador.dart';

/// Servidor real en un puerto libre de 127.0.0.1, con WebSocket de verdad.
/// Los temporizadores usan el programador de prueba (no corren solos).
class _ServidorReal {
  final Mesa mesa = Mesa();
  late final HttpServer http;

  Future<void> iniciar({Config config = const Config()}) async {
    http = await shelf_io.serve(
      crearAplicacion(config, mesa.servicios, multijugador: mesa.mj),
      '127.0.0.1',
      0,
    );
  }

  Uri get uri => Uri.parse('ws://127.0.0.1:${http.port}/ws');

  Future<void> cerrar() async {
    mesa.cerrar();
    await http.close(force: true);
  }
}

Future<Map<String, Object?>> _siguiente(StreamIterator<Object?> it) async {
  final hay = await it.moveNext().timeout(const Duration(seconds: 5));
  expect(hay, isTrue);
  return jsonDecode(it.current! as String) as Map<String, Object?>;
}

void main() {
  late _ServidorReal servidor;

  setUp(() async {
    servidor = _ServidorReal();
    await servidor.iniciar();
  });
  tearDown(() => servidor.cerrar());

  test('conecta por /ws, se autentica con el primer mensaje y juega', () async {
    final canal = IOWebSocketChannel.connect(servidor.uri);
    await canal.ready;
    final it = StreamIterator(canal.stream);

    canal.sink.add(
      jsonEncode({'tipo': 'autenticar', 'token': servidor.mesa.tokenDe('ana')}),
    );
    final ok = await _siguiente(it);
    expect(ok['tipo'], 'autenticado');

    canal.sink.add(
      jsonEncode({'tipo': 'crear_sala', 'id': 1, 'mapa': 2, 'maximo': 3}),
    );
    final estado = await _siguiente(it);
    expect(estado['tipo'], 'estado');
    expect((estado['sala']! as Map)['mapa'], 2);

    // Mal formado: error y la conexión sigue.
    canal.sink.add('no es json');
    expect((await _siguiente(it))['codigo'], 'mensaje_invalido');
    canal.sink.add(jsonEncode({'tipo': 'pong', 'r': 'x' * 5000}));
    expect((await _siguiente(it))['codigo'], 'mensaje_muy_grande');

    await canal.sink.close();
    await it.cancel();
  });

  test('un token inválido cierra con código y motivo', () async {
    final canal = IOWebSocketChannel.connect(servidor.uri);
    await canal.ready;
    canal.sink.add(jsonEncode({'tipo': 'autenticar', 'token': 'x.y.z'}));
    await canal.stream.drain<void>().timeout(const Duration(seconds: 5));
    expect(canal.closeCode, CierreWs.sinSesion);
    expect(canal.closeReason, mensajeSesionInvalida);
  });

  test('el token en la URL no sirve: hay que mandarlo en el mensaje', () async {
    final token = servidor.mesa.tokenDe('ana');
    final canal = IOWebSocketChannel.connect(
      servidor.uri.replace(queryParameters: {'token': token}),
    );
    await canal.ready;
    canal.sink.add(jsonEncode({'tipo': 'pong'}));
    await canal.stream.drain<void>().timeout(const Duration(seconds: 5));
    expect(canal.closeCode, CierreWs.sinSesion);
  });

  test('rechaza un origen no permitido', () async {
    final canal = IOWebSocketChannel.connect(
      servidor.uri,
      headers: {'Origin': 'https://sitio-malo.com'},
    );
    await expectLater(canal.ready, throwsA(isA<WebSocketChannelException>()));
  });

  test('acepta un origen permitido (localhost en desarrollo)', () async {
    final canal = IOWebSocketChannel.connect(
      servidor.uri,
      headers: {'Origin': 'http://localhost:5000'},
    );
    await canal.ready;
    await canal.sink.close();
  });

  test('en producción solo los orígenes configurados', () async {
    final prod = _ServidorReal();
    await prod.iniciar(
      config: const Config(
        produccion: true,
        origenesPermitidos: ['https://brilliant.ejemplo.com'],
      ),
    );
    addTearDown(prod.cerrar);

    final local = IOWebSocketChannel.connect(
      prod.uri,
      headers: {'Origin': 'http://localhost:5000'},
    );
    await expectLater(local.ready, throwsA(isA<WebSocketChannelException>()));

    final bueno = IOWebSocketChannel.connect(
      prod.uri,
      headers: {'Origin': 'https://brilliant.ejemplo.com'},
    );
    await bueno.ready;
    await bueno.sink.close();
  });

  test('sin multijugador, /ws no existe', () async {
    final s = ServidorDePrueba();
    addTearDown(s.cerrar);
    final r = await s.pedir('GET', '/ws');
    expect(r.estado, 404);
  });

  test('una petición HTTP normal a /ws no abre nada', () async {
    final cliente = HttpClient();
    addTearDown(cliente.close);
    final peticion = await cliente.getUrl(
      Uri.parse('http://127.0.0.1:${servidor.http.port}/ws'),
    );
    final respuesta = await peticion.close();
    await respuesta.drain<void>();
    expect(respuesta.statusCode, 404);
    expect(servidor.mesa.mj.cantidadConexiones, 0);
  });
}
