import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:juego_brilliant/almacen_sesion.dart';
import 'package:juego_brilliant/api_auth_repository.dart';
import 'package:juego_brilliant/auth_cubit.dart';
import 'package:juego_brilliant/auth_repository.dart';
import 'package:juego_brilliant/main.dart';

const _usuarioJson = {'id': 1, 'nombre': 'dany', 'correo': 'dany@correo.com'};
const _token = 'token.de.prueba';
const _dany = Usuario(nombre: 'dany', correo: 'dany@correo.com');

http.Response _json(int estado, Object cuerpo) => http.Response(
  jsonEncode(cuerpo),
  estado,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Servidor falso: /sesion entrega el token; /cuenta responde [cuenta].
MockClient _servidor({http.Response Function()? cuenta}) =>
    MockClient((p) async {
      if (p.url.path == '/sesion') {
        return _json(200, {'token': _token, 'usuario': _usuarioJson});
      }
      if (p.url.path == '/cuenta' && p.method == 'GET') {
        return cuenta?.call() ?? _json(200, {'usuario': _usuarioJson});
      }
      return http.Response('', 204);
    });

ApiAuthRepository _repo(AlmacenSesion almacen, MockClient cliente) =>
    ApiAuthRepository(
      urlBase: 'http://servidor.prueba',
      cliente: cliente,
      almacen: almacen,
    );

/// flutter_secure_storage que siempre falla, como puede pasar en la web.
class _AlmacenQueFalla implements FlutterSecureStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<Never>.error(Exception('WebCrypto no disponible'));
}

void main() {
  group('AlmacenSesionEnMemoria', () {
    test('guarda, lee y borra el token', () async {
      final almacen = AlmacenSesionEnMemoria();
      expect(await almacen.leerToken(), isNull);
      await almacen.guardarToken('abc');
      expect(await almacen.leerToken(), 'abc');
      await almacen.borrarToken();
      expect(await almacen.leerToken(), isNull);
    });
  });

  group('AlmacenSesionSegura', () {
    test(
      'si flutter_secure_storage falla, no lanza: no hay sesión guardada',
      () async {
        final almacen = AlmacenSesionSegura(_AlmacenQueFalla());
        await almacen.guardarToken('abc');
        expect(await almacen.leerToken(), isNull);
        await almacen.borrarToken();
      },
    );

    test('sin el plugin (como en las pruebas) tampoco lanza', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final almacen = AlmacenSesionSegura();
      await almacen.guardarToken('abc');
      expect(await almacen.leerToken(), isNull);
      await almacen.borrarToken();
    });
  });

  group('ApiAuthRepository con sesión guardada', () {
    test('al iniciar sesión guarda el token en el almacén', () async {
      final almacen = AlmacenSesionEnMemoria();
      await _repo(
        almacen,
        _servidor(),
      ).iniciarSesion(correo: 'dany@correo.com', contrasena: 'secreta1');
      expect(await almacen.leerToken(), _token);
    });

    test('al abrir la app usa el token guardado', () async {
      final peticiones = <http.Request>[];
      final cliente = MockClient((p) async {
        peticiones.add(p);
        return _json(200, {'usuario': _usuarioJson});
      });

      final usuario = await _repo(
        AlmacenSesionEnMemoria(_token),
        cliente,
      ).restaurarSesion();

      expect(usuario, _dany);
      expect(peticiones.single.headers['authorization'], 'Bearer $_token');
    });

    test('cerrar sesión borra el token guardado', () async {
      final almacen = AlmacenSesionEnMemoria(_token);
      await _repo(almacen, _servidor()).cerrarSesion();
      expect(await almacen.leerToken(), isNull);
    });

    test('borrar la cuenta borra el token guardado', () async {
      final almacen = AlmacenSesionEnMemoria(_token);
      await _repo(almacen, _servidor()).borrarCuenta('secreta1');
      expect(await almacen.leerToken(), isNull);
    });

    test(
      'si guardar falla, la sesión sigue funcionando mientras está abierta',
      () async {
        final repo = _repo(
          AlmacenSesionSegura(_AlmacenQueFalla()),
          _servidor(),
        );

        final usuario = await repo.iniciarSesion(
          correo: 'dany@correo.com',
          contrasena: 'secreta1',
        );

        expect(usuario, _dany);
        expect(repo.tieneToken, isTrue);
        expect(await repo.restaurarSesion(), _dany);
      },
    );
  });

  group('AuthCubit.iniciar', () {
    test('con un token guardado válido entra directo con sesión', () async {
      final cubit = AuthCubit(
        _repo(AlmacenSesionEnMemoria(_token), _servidor()),
      );
      expect(cubit.state, const AuthComprobando());

      await cubit.iniciar();

      expect(cubit.state, const AuthConSesion(_dany));
    });

    test('con 401 vuelve al login y borra el token guardado', () async {
      final almacen = AlmacenSesionEnMemoria(_token);
      final cubit = AuthCubit(
        _repo(
          almacen,
          _servidor(
            cuenta: () =>
                _json(401, {'error': 'Tu sesión no es válida o ya venció'}),
          ),
        ),
      );

      await cubit.iniciar();

      expect(cubit.state, const AuthSinSesion());
      expect(await almacen.leerToken(), isNull);
    });

    test(
      'sin servidor va al login con un mensaje claro y conserva el token',
      () async {
        final almacen = AlmacenSesionEnMemoria(_token);
        final cubit = AuthCubit(
          _repo(
            almacen,
            MockClient((_) => throw http.ClientException('sin red')),
          ),
        );

        await cubit.iniciar();

        expect(
          cubit.state,
          const AuthSinSesion(error: MensajesServidor.sinConexion),
        );
        expect(await almacen.leerToken(), _token);
      },
    );

    test('solo comprueba una vez', () async {
      var llamadas = 0;
      final cubit = AuthCubit(
        _repo(
          AlmacenSesionEnMemoria(_token),
          MockClient((_) async {
            llamadas++;
            return _json(200, {'usuario': _usuarioJson});
          }),
        ),
      );

      await cubit.iniciar();
      await cubit.iniciar();

      expect(llamadas, 1);
    });

    test('cerrar sesión desde el cubit borra el token guardado', () async {
      final almacen = AlmacenSesionEnMemoria(_token);
      final cubit = AuthCubit(_repo(almacen, _servidor()));
      await cubit.iniciar();

      await cubit.cerrarSesion();

      expect(cubit.state, const AuthSinSesion());
      expect(await almacen.leerToken(), isNull);
    });
  });

  group('Al abrir la app', () {
    testWidgets('muestra "Comprobando tu sesión" y luego el login', (
      tester,
    ) async {
      await tester.pumpWidget(
        BrilliantApp(
          repositorio: InMemoryAuthRepository(retraso: Duration.zero),
        ),
      );

      expect(find.text('Comprobando tu sesión…'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Iniciar sesión'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('Comprobando tu sesión…'), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Iniciar sesión'),
        findsOneWidget,
      );
    });

    testWidgets(
      'con una sesión guardada válida entra directo a Buscar partida',
      (tester) async {
        await tester.pumpWidget(
          BrilliantApp(
            repositorio: _repo(AlmacenSesionEnMemoria(_token), _servidor()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hola, dany'), findsOneWidget);
      },
    );

    testWidgets('con un token vencido muestra el login', (tester) async {
      final almacen = AlmacenSesionEnMemoria(_token);
      await tester.pumpWidget(
        BrilliantApp(
          repositorio: _repo(
            almacen,
            _servidor(cuenta: () => _json(401, {'error': 'vencida'})),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(FilledButton, 'Iniciar sesión'),
        findsOneWidget,
      );
      expect(await almacen.leerToken(), isNull);
    });
  });
}
