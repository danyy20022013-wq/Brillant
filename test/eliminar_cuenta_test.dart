import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:juego_brilliant/almacen_sesion.dart';
import 'package:juego_brilliant/api_auth_repository.dart';
import 'package:juego_brilliant/auth_cubit.dart';
import 'package:juego_brilliant/auth_repository.dart';
import 'package:juego_brilliant/main.dart';

const _usuarioJson = {'id': 1, 'nombre': 'dany', 'correo': 'dany@correo.com'};
const _dany = Usuario(nombre: 'dany', correo: 'dany@correo.com');

/// Repositorio en memoria con la cuenta de Dany y la sesión iniciada.
Future<InMemoryAuthRepository> _repoConSesion() async {
  final repo = InMemoryAuthRepository(retraso: Duration.zero);
  await repo.registrar(
    nombre: 'dany',
    correo: 'dany@correo.com',
    contrasena: 'secreta1',
  );
  return repo;
}

/// Repositorio del servidor con un token guardado; DELETE /cuenta responde
/// [borrar].
ApiAuthRepository _repoApi(
  http.Response Function() borrar, {
  AlmacenSesion? almacen,
}) => ApiAuthRepository(
  urlBase: 'http://servidor.prueba',
  almacen: almacen ?? AlmacenSesionEnMemoria('token.de.prueba'),
  cliente: MockClient((p) async {
    if (p.method == 'DELETE') return borrar();
    return http.Response(
      jsonEncode({'usuario': _usuarioJson}),
      200,
      headers: {'content-type': 'application/json'},
    );
  }),
);

http.Response _error(int estado, String mensaje, [Map<String, String>? cab]) =>
    http.Response(
      jsonEncode({'error': mensaje}),
      estado,
      headers: {'content-type': 'application/json; charset=utf-8', ...?cab},
    );

Future<AuthCubit> _cubitConSesion(AuthRepository repo) async {
  final cubit = AuthCubit(repo);
  await cubit.iniciar();
  expect(cubit.state, const AuthConSesion(_dany));
  return cubit;
}

// ───────────── ayudas de widget ─────────────

Future<void> _abrirApp(
  WidgetTester tester,
  AuthRepository repo, {
  Size? tamano,
}) async {
  if (tamano != null) {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(BrilliantApp(repositorio: repo));
  await tester.pumpAndSettle();
  expect(find.text('Hola, dany'), findsOneWidget);
}

final _opcion = find.byKey(const Key('opcion-eliminar-cuenta'));
final _campo = find.byKey(const Key('campo-contrasena-eliminar'));
final _boton = find.byKey(const Key('boton-eliminar-cuenta'));

Future<void> _abrirDialogo(WidgetTester tester) async {
  await tester.ensureVisible(_opcion);
  await tester.pumpAndSettle();
  await tester.tap(_opcion);
  await tester.pumpAndSettle();
}

Future<void> _confirmar(WidgetTester tester, String contrasena) async {
  await tester.enterText(_campo, contrasena);
  await tester.pump();
  await tester.tap(_boton);
  await tester.pumpAndSettle();
}

bool _botonHabilitado(WidgetTester tester) =>
    tester.widget<FilledButton>(_boton).onPressed != null;

void main() {
  group('AuthCubit.borrarCuenta', () {
    test('con la contraseña correcta borra y vuelve al login', () async {
      final repo = await _repoConSesion();
      final cubit = await _cubitConSesion(repo);

      expect(await cubit.borrarCuenta('secreta1'), isNull);

      expect(cubit.state, const AuthSinSesion());
      expect(await repo.restaurarSesion(), isNull);
    });

    test(
      'contraseña incorrecta (403): devuelve el error y NO cierra la sesión',
      () async {
        final almacen = AlmacenSesionEnMemoria('token.de.prueba');
        final cubit = await _cubitConSesion(
          _repoApi(
            () => _error(403, 'La contraseña no es correcta'),
            almacen: almacen,
          ),
        );

        expect(
          await cubit.borrarCuenta('mala12'),
          'La contraseña no es correcta',
        );

        expect(cubit.state, const AuthConSesion(_dany));
        expect(await almacen.leerToken(), 'token.de.prueba');
      },
    );

    test(
      'sesión vencida (401): vuelve al login con el aviso y borra el token',
      () async {
        final almacen = AlmacenSesionEnMemoria('token.de.prueba');
        final cubit = await _cubitConSesion(
          _repoApi(
            () => _error(401, 'Tu sesión no es válida o ya venció'),
            almacen: almacen,
          ),
        );

        expect(await cubit.borrarCuenta('secreta1'), isNull);

        expect(
          cubit.state,
          const AuthSinSesion(
            error: 'Tu sesión venció. Vuelve a iniciar sesión.',
          ),
        );
        expect(await almacen.leerToken(), isNull);
      },
    );

    test(
      'demasiados intentos (429): mensaje con segundos y sigue la sesión',
      () async {
        final cubit = await _cubitConSesion(
          _repoApi(() => _error(429, 'x', {'retry-after': '120'})),
        );

        expect(
          await cubit.borrarCuenta('mala12'),
          'Demasiados intentos. Espera 120 segundos e inténtalo de nuevo.',
        );
        expect(cubit.state, isA<AuthConSesion>());
      },
    );

    test('sin conexión: mensaje claro y sigue la sesión', () async {
      final cubit = await _cubitConSesion(
        _repoApi(() => throw http.ClientException('sin red')),
      );

      expect(
        await cubit.borrarCuenta('secreta1'),
        MensajesServidor.sinConexion,
      );
      expect(cubit.state, isA<AuthConSesion>());
    });

    test('sin sesión no hace nada', () async {
      final cubit = AuthCubit(InMemoryAuthRepository(retraso: Duration.zero));
      await cubit.iniciar();
      expect(await cubit.borrarCuenta('secreta1'), isNull);
      expect(cubit.state, const AuthSinSesion());
    });
  });

  group('Opción y diálogo "Eliminar cuenta"', () {
    testWidgets('la opción está separada de "Cerrar sesión"', (tester) async {
      await _abrirApp(tester, await _repoConSesion());

      expect(_opcion, findsOneWidget);
      expect(find.text('Eliminar cuenta'), findsOneWidget);
      expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
      // Son botones distintos y lejanos: uno arriba, el otro abajo.
      final cerrar = tester.getCenter(find.byTooltip('Cerrar sesión'));
      final eliminar = tester.getCenter(_opcion);
      expect(eliminar.dy - cerrar.dy, greaterThan(200));
    });

    testWidgets('explica que es permanente y exige la contraseña', (
      tester,
    ) async {
      await _abrirApp(tester, await _repoConSesion());
      await _abrirDialogo(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('permanente'), findsOneWidget);
      expect(find.textContaining('no se puede deshacer'), findsOneWidget);
      expect(
        find.text('Escribe tu contraseña para confirmar.'),
        findsOneWidget,
      );
      expect(_botonHabilitado(tester), isFalse);

      await tester.enterText(_campo, 'algo');
      await tester.pump();
      expect(_botonHabilitado(tester), isTrue);
    });

    testWidgets('Cancelar cierra el diálogo y no borra nada', (tester) async {
      final repo = await _repoConSesion();
      await _abrirApp(tester, repo);
      await _abrirDialogo(tester);
      await tester.enterText(_campo, 'secreta1');

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Hola, dany'), findsOneWidget);
      expect(await repo.restaurarSesion(), _dany);
    });

    testWidgets('contraseña incorrecta: muestra el error y sigue la sesión', (
      tester,
    ) async {
      final repo = await _repoConSesion();
      await _abrirApp(tester, repo);
      await _abrirDialogo(tester);

      await _confirmar(tester, 'mala12');

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byKey(const Key('error-eliminar')), findsOneWidget);
      expect(find.text('La contraseña no es correcta'), findsOneWidget);
      expect(_botonHabilitado(tester), isTrue);
      expect(await repo.restaurarSesion(), _dany);

      // Corrige la contraseña y ahora sí se borra.
      await _confirmar(tester, 'secreta1');
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Iniciar sesión'),
        findsOneWidget,
      );
    });

    testWidgets('con la contraseña correcta vuelve al inicio de sesión', (
      tester,
    ) async {
      final repo = await _repoConSesion();
      await _abrirApp(tester, repo);
      await _abrirDialogo(tester);

      await _confirmar(tester, 'secreta1');

      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Iniciar sesión'),
        findsOneWidget,
      );
      expect(find.text('Hola, dany'), findsNothing);
      expect(await repo.restaurarSesion(), isNull);
    });

    testWidgets('403 del servidor: error en el diálogo, no saca al login', (
      tester,
    ) async {
      await _abrirApp(
        tester,
        _repoApi(() => _error(403, 'La contraseña no es correcta')),
      );
      await _abrirDialogo(tester);

      await _confirmar(tester, 'mala12');

      expect(find.text('La contraseña no es correcta'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Iniciar sesión'), findsNothing);
    });

    testWidgets('401 del servidor: cierra el diálogo y muestra el login', (
      tester,
    ) async {
      await _abrirApp(
        tester,
        _repoApi(() => _error(401, 'Tu sesión no es válida o ya venció')),
      );
      await _abrirDialogo(tester);

      await _confirmar(tester, 'secreta1');

      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Iniciar sesión'),
        findsOneWidget,
      );
      expect(
        find.text('Tu sesión venció. Vuelve a iniciar sesión.'),
        findsOneWidget,
      );
    });

    const pantallas = [Size(320, 568), Size(360, 640), Size(411, 891)];
    for (final tamano in pantallas) {
      testWidgets('cabe en ${tamano.width.toInt()}x${tamano.height.toInt()} '
          '(pantalla, diálogo y error)', (tester) async {
        await _abrirApp(tester, await _repoConSesion(), tamano: tamano);
        expect(tester.takeException(), isNull);

        await _abrirDialogo(tester);
        expect(tester.takeException(), isNull);

        await _confirmar(tester, 'mala12');
        expect(tester.takeException(), isNull);
        expect(find.text('La contraseña no es correcta'), findsOneWidget);

        final dialogo = tester.getRect(find.byType(AlertDialog));
        expect(dialogo.left, greaterThanOrEqualTo(0));
        expect(dialogo.right, lessThanOrEqualTo(tamano.width));
        expect(dialogo.top, greaterThanOrEqualTo(0));
        expect(dialogo.bottom, lessThanOrEqualTo(tamano.height));
      });
    }
  });
}
