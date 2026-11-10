import 'dart:convert';
import 'dart:math';

import 'package:servidor_brilliant/servidor_brilliant.dart';
import 'package:test/test.dart';

import 'ayuda_multijugador.dart';

void main() {
  late Mesa mesa;

  setUp(() => mesa = Mesa());
  tearDown(() => mesa.cerrar());

  group('códigos de sala', () {
    test('el alfabeto no tiene caracteres ambiguos', () {
      for (final c in ['0', 'O', '1', 'I', 'L']) {
        expect(alfabetoCodigoSala.contains(c), isFalse, reason: c);
      }
    });

    test('se generan de 6 caracteres del alfabeto', () {
      final random = Random(3);
      for (var i = 0; i < 200; i++) {
        final codigo = generarCodigoSala(random);
        expect(codigo.length, 6);
        expect(normalizarCodigoSala(codigo), codigo);
      }
    });

    test('normalizar acepta minúsculas y espacios, y rechaza el resto', () {
      expect(normalizarCodigoSala(' abc234 '), 'ABC234');
      expect(normalizarCodigoSala('ABC23'), isNull);
      expect(normalizarCodigoSala('ABC2340'), isNull);
      expect(normalizarCodigoSala('ABCO23'), isNull); // O no existe
      expect(normalizarCodigoSala(123456), isNull);
      expect(normalizarCodigoSala(null), isNull);
    });
  });

  group('autenticación', () {
    test('el token en el primer mensaje inicia la sesión', () {
      final c = mesa.entrar('ana');
      final ok = c.ultimo('autenticado')!;
      expect(ok['usuario'], {'id': mesa.idDe('ana'), 'nombre': 'ana'});
      expect(ok['ultimaAccion'], 0);
      expect(ok['sala'], isNull);
      expect(c.cerrado, isFalse);
      expect(mesa.mj.cantidadConexiones, 1);
    });

    test('si no llega en 5 segundos se cierra con motivo', () {
      final c = mesa.abrir();
      mesa.programador.avanzar(const Duration(milliseconds: 4900));
      expect(c.cerrado, isFalse);
      mesa.programador.avanzar(const Duration(milliseconds: 100));
      expect(c.codigoCierre, CierreWs.sinSesion);
      expect(c.motivoCierre, 'No llegó el token a tiempo');
    });

    test('un token inválido cierra la conexión', () {
      final c = mesa.abrir();
      c.mandar({'tipo': 'autenticar', 'token': 'esto.no.sirve'});
      expect(c.codigoCierre, CierreWs.sinSesion);
      expect(c.motivoCierre, mensajeSesionInvalida);
      expect(c.recibidos, isEmpty);
    });

    test('un token vencido cierra la conexión', () {
      final token = mesa.tokenDe('ana');
      mesa.reloj.avanzar(const Duration(hours: 2));
      final c = mesa.abrir();
      c.mandar({'tipo': 'autenticar', 'token': token});
      expect(c.codigoCierre, CierreWs.sinSesion);
    });

    test('un token de una cuenta borrada cierra la conexión', () {
      final token = mesa.tokenDe('ana');
      mesa.usuarios.borrar(mesa.idDe('ana'));
      final c = mesa.abrir();
      c.mandar({'tipo': 'autenticar', 'token': token});
      expect(c.codigoCierre, CierreWs.sinSesion);
    });

    test('si el primer mensaje no es autenticar se cierra', () {
      final c = mesa.abrir();
      c.mandar({'tipo': 'crear_sala', 'id': 1, 'mapa': 1, 'maximo': 2});
      expect(c.codigoCierre, CierreWs.sinSesion);
      expect(c.motivoCierre, 'El primer mensaje debe ser autenticar');
    });

    test('un primer mensaje mal formado también cierra', () {
      final c = mesa.abrir();
      c.mandarTexto('no es json');
      expect(c.codigoCierre, CierreWs.sinSesion);
    });

    test('autenticarse dos veces da error sin cerrar', () {
      final c = mesa.entrar('ana');
      c.mandar({'tipo': 'autenticar', 'token': mesa.tokenDe('ana')});
      expect(c.ultimoError!['codigo'], 'ya_autenticado');
      expect(c.cerrado, isFalse);
    });
  });

  group('mensajes mal formados', () {
    test('reciben error y la conexión sigue abierta', () {
      final c = mesa.entrar('ana');
      c.mandarTexto('{esto no es json');
      expect(c.ultimoError!['codigo'], 'mensaje_invalido');
      c.mandarTexto('[1, 2, 3]');
      expect(c.ultimoError!['codigo'], 'mensaje_invalido');
      c.mandar({'sin': 'tipo'});
      expect(c.ultimoError!['codigo'], 'mensaje_invalido');
      c.mandarTexto(utf8.encode('{"tipo":"pong"}'));
      expect(c.ultimoError!['codigo'], 'mensaje_invalido');
      c.mandar({'tipo': 'volar', 'id': 1});
      expect(c.ultimoError!['codigo'], 'tipo_desconocido');
      c.mandar({'tipo': 'crear_sala', 'mapa': 1, 'maximo': 2});
      expect(c.ultimoError!['codigo'], 'mensaje_invalido');
      expect(c.cerrado, isFalse);

      // Sigue funcionando.
      c.accion('crear_sala', {'mapa': 1, 'maximo': 2});
      expect(c.sala['fase'], 'lobby');
    });

    test('más de 4 KB recibe error sin cerrar', () {
      final c = mesa.entrar('ana');
      c.mandar({'tipo': 'pong', 'relleno': 'x' * 4096});
      expect(c.ultimoError!['codigo'], 'mensaje_muy_grande');
      expect(c.cerrado, isFalse);
    });

    test('el límite cuenta bytes, no caracteres', () {
      final c = mesa.entrar('ana');
      // 2100 eñes son 4200 bytes en UTF-8 aunque sean 2100 caracteres.
      c.mandar({'tipo': 'pong', 'relleno': 'ñ' * 2100});
      expect(c.ultimoError!['codigo'], 'mensaje_muy_grande');
    });

    test('justo en 4 KB se acepta', () {
      final c = mesa.entrar('ana');
      const base = '{"tipo":"pong","r":""}';
      c.mandarTexto(base.replaceFirst('""', '"${'x' * (4096 - base.length)}"'));
      expect(c.ultimoError, isNull);
    });

    test('el abuso repetido cierra la conexión', () {
      final c = mesa.entrar('ana');
      for (var i = 0; i < 9; i++) {
        c.mandarTexto('basura');
      }
      expect(c.cerrado, isFalse);
      c.mandarTexto('basura');
      expect(c.codigoCierre, CierreWs.abuso);
      expect(mesa.mj.cantidadConexiones, 0);
    });

    test('los errores espaciados en el tiempo no cuentan como abuso', () {
      final c = mesa.entrar('ana');
      for (var i = 0; i < 30; i++) {
        c.mandarTexto('basura');
        mesa.programador.avanzar(const Duration(seconds: 7));
      }
      expect(c.cerrado, isFalse);
    });
  });

  group('latidos', () {
    test('manda ping cada 10 s y quien contesta sigue conectado', () {
      final c = mesa.entrar('ana');
      mesa.programador.avanzar(const Duration(seconds: 35));
      expect(c.de('ping').length, 3);
      expect(c.cerrado, isFalse);
    });

    test('sin respuesta al ping la conexión se da por caída', () {
      final c = mesa.entrar('ana')..responderPings = false;
      mesa.programador.avanzar(const Duration(seconds: 10));
      expect(c.de('ping').length, 1);
      expect(c.cerrado, isFalse);
      mesa.programador.avanzar(const Duration(seconds: 10));
      expect(c.codigoCierre, CierreWs.sinLatido);
      expect(mesa.mj.cantidadConexiones, 0);
    });

    test('cualquier mensaje cuenta como respuesta', () {
      final c = mesa.entrar('ana')..responderPings = false;
      for (var i = 0; i < 5; i++) {
        mesa.programador.avanzar(const Duration(seconds: 10));
        c.accion('listo', {'listo': true}); // da error (no está en sala)
      }
      expect(c.cerrado, isFalse);
    });
  });

  group('doble conexión', () {
    test('la nueva reemplaza a la vieja, que recibe aviso y se cierra', () {
      final vieja = mesa.entrar('ana');
      final nueva = mesa.entrar('ana');

      expect(vieja.ultimo('sesion_reemplazada'), isNotNull);
      expect(vieja.codigoCierre, CierreWs.reemplazada);
      // El aviso llega antes del cierre.
      expect(vieja.recibidos.last['tipo'], 'sesion_reemplazada');
      expect(nueva.cerrado, isFalse);
      expect(nueva.ultimo('autenticado'), isNotNull);
      expect(mesa.mj.cantidadConexiones, 1);
    });

    test('en una sala, la nueva recibe el estado y no cuenta como caída', () {
      final ana = mesa.entrar('ana');
      final beto = mesa.entrar('beto');
      final codigo = mesa.salaCon([ana, beto]);

      final ana2 = mesa.entrar('ana');
      expect(ana.codigoCierre, CierreWs.reemplazada);
      expect(ana2.sala['codigo'], codigo);
      expect(ana2.sala.jugador(mesa.idDe('ana'))['conectado'], isTrue);
      // No se programó la salida del lobby por desconexión.
      mesa.programador.avanzar(const Duration(seconds: 20));
      expect(mesa.mj.sala(codigo)!.miembros.length, 2);
    });

    test('los ids de acción siguen entre conexiones', () {
      final ana = mesa.entrar('ana');
      ana.siguienteId = 41;
      ana.accion('crear_sala', {'mapa': 1, 'maximo': 2});
      final ana2 = mesa.entrar('ana');
      expect(ana2.ultimo('autenticado')!['ultimaAccion'], 41);
    });
  });

  group('servidor reiniciado', () {
    test('al volver con una sala que ya no existe llega sala_no_existe', () {
      final ana = mesa.entrar('ana');
      final codigo = mesa.salaCon([ana, mesa.entrar('beto')]);

      // Servidor nuevo: las salas en memoria se perdieron.
      final otra = Mesa();
      addTearDown(otra.cerrar);
      final ana2 = otra.entrar('ana', sala: codigo);
      expect(ana2.ultimo('autenticado')!['sala'], isNull);
      expect(ana2.ultimo('sala_no_existe')!['codigo'], codigo);
    });

    test('reconectar con un código desconocido responde sala_no_existe', () {
      final ana = mesa.entrar('ana');
      ana.mandar({'tipo': 'reconectar', 'codigo': 'ABCDEF'});
      expect(ana.ultimo('sala_no_existe')!['codigo'], 'ABCDEF');
    });

    test('reconectar a la propia sala devuelve el estado completo', () {
      final ana = mesa.entrar('ana');
      final codigo = mesa.salaCon([ana, mesa.entrar('beto')]);
      ana.olvidar();
      ana.mandar({'tipo': 'reconectar', 'codigo': codigo.toLowerCase()});
      expect(ana.sala['codigo'], codigo);
    });
  });

  test('cerrar el servidor cierra conexiones y temporizadores', () {
    final ana = mesa.entrar('ana');
    mesa.salaCon([ana, mesa.entrar('beto')]);
    mesa.mj.cerrar();
    expect(ana.codigoCierre, CierreWs.servidorCerrado);
    expect(mesa.mj.cantidadSalas, 0);
    expect(mesa.mj.cantidadConexiones, 0);
    expect(mesa.programador.pendientes, 0);
  });
}
