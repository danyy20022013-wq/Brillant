import 'dart:async';
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

/// Repositorio del servidor cuando el servidor está apagado.
ApiAuthRepository _sinServidor({AlmacenSesion? almacen}) => ApiAuthRepository(
  urlBase: 'http://servidor.prueba',
  almacen: almacen,
  cliente: MockClient((_) => throw http.ClientException('Connection refused')),
);

/// Servidor que contesta "correo o contraseña incorrectos".
ApiAuthRepository _credencialesMalas() => ApiAuthRepository(
  urlBase: 'http://servidor.prueba',
  cliente: MockClient(
    (_) async => http.Response(
      jsonEncode({'error': 'Correo o contraseña incorrectos'}),
      401,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ),
  ),
);

final _aviso = find.byKey(const Key('aviso-sin-servidor'));

Future<void> _abrir(
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
}

Future<void> _tocar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _escribir(WidgetTester tester, String clave, String texto) async {
  final campo = find.byKey(Key(clave));
  await tester.ensureVisible(campo);
  await tester.enterText(campo, texto);
  await tester.pump();
}

Future<void> _intentarEntrar(WidgetTester tester) async {
  await _escribir(tester, 'campo-correo', 'dany@correo.com');
  await _escribir(tester, 'campo-contrasena', 'secreta1');
  await _tocar(tester, find.widgetWithText(FilledButton, 'Iniciar sesión'));
}

Future<void> _intentarRegistrar(WidgetTester tester) async {
  await _tocar(tester, find.text('Crear cuenta'));
  await _escribir(tester, 'campo-nombre', 'dany');
  await _escribir(tester, 'campo-correo', 'dany@correo.com');
  await _escribir(tester, 'campo-contrasena', 'secreta1');
  await _escribir(tester, 'campo-confirmacion', 'secreta1');
  await _tocar(tester, find.widgetWithText(FilledButton, 'Registrarme'));
}

void main() {
  group('AuthCubit marca cuando el servidor no está', () {
    test(
      'al iniciar sesión sin servidor: sinServidor y mensaje claro',
      () async {
        final cubit = AuthCubit(_sinServidor());
        await cubit.iniciar();
        await cubit.iniciarSesion(correo: 'a@b.co', contrasena: 'secreta1');

        expect(
          cubit.state,
          const AuthSinSesion(
            error: MensajesServidor.sinConexion,
            sinServidor: true,
          ),
        );
      },
    );

    test('un error normal no es "sin servidor"', () async {
      final cubit = AuthCubit(_credencialesMalas());
      await cubit.iniciar();
      await cubit.iniciarSesion(correo: 'a@b.co', contrasena: 'secreta1');

      expect(
        cubit.state,
        const AuthSinSesion(error: 'Correo o contraseña incorrectos'),
      );
    });

    test('al registrarse sin servidor también', () async {
      final cubit = AuthCubit(_sinServidor());
      await cubit.iniciar();
      await cubit.registrar(
        nombre: 'dany',
        correo: 'a@b.co',
        contrasena: 'secreta1',
      );

      expect((cubit.state as AuthSinSesion).sinServidor, isTrue);
    });

    test('tiempo agotado también cuenta como sin servidor', () async {
      final cubit = AuthCubit(
        ApiAuthRepository(
          urlBase: 'http://servidor.prueba',
          tiempoLimite: const Duration(milliseconds: 20),
          cliente: MockClient((_) => Completer<http.Response>().future),
        ),
      );
      await cubit.iniciar();
      await cubit.iniciarSesion(correo: 'a@b.co', contrasena: 'secreta1');

      expect(
        cubit.state,
        const AuthSinSesion(
          error: MensajesServidor.tiempoAgotado,
          sinServidor: true,
        ),
      );
    });
  });

  group('Aviso amable en pantalla', () {
    testWidgets('inicio de sesión sin servidor', (tester) async {
      await _abrir(tester, _sinServidor());
      expect(_aviso, findsNothing);

      await _intentarEntrar(tester);

      expect(_aviso, findsOneWidget);
      expect(find.text('El servidor no está disponible ahora'), findsOneWidget);
      expect(find.text(MensajesServidor.sinConexion), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      // Sigue en el login y se puede volver a intentar.
      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Iniciar sesión'),
      );
      expect(boton.onPressed, isNotNull);
    });

    testWidgets('registro sin servidor', (tester) async {
      await _abrir(tester, _sinServidor());

      await _intentarRegistrar(tester);

      expect(find.text('Registro'), findsOneWidget);
      expect(_aviso, findsOneWidget);
      expect(find.text(MensajesServidor.sinConexion), findsOneWidget);
    });

    testWidgets('al abrir con sesión guardada y sin servidor', (tester) async {
      final almacen = AlmacenSesionEnMemoria('token.de.prueba');
      await _abrir(tester, _sinServidor(almacen: almacen));

      expect(
        find.widgetWithText(FilledButton, 'Iniciar sesión'),
        findsOneWidget,
      );
      expect(_aviso, findsOneWidget);
      // El token no se borra: cuando vuelva el servidor se podrá restaurar.
      expect(await almacen.leerToken(), 'token.de.prueba');
    });

    testWidgets('un error normal se ve como siempre, sin el aviso', (
      tester,
    ) async {
      await _abrir(tester, _credencialesMalas());

      await _intentarEntrar(tester);

      expect(_aviso, findsNothing);
      expect(find.text('Correo o contraseña incorrectos'), findsOneWidget);
    });

    const pantallas = [Size(320, 568), Size(360, 640), Size(411, 891)];
    for (final tamano in pantallas) {
      testWidgets(
        'el aviso cabe en ${tamano.width.toInt()}x${tamano.height.toInt()}',
        (tester) async {
          await _abrir(tester, _sinServidor(), tamano: tamano);
          await _intentarEntrar(tester);
          expect(tester.takeException(), isNull);
          expect(_aviso, findsOneWidget);

          await _intentarRegistrar(tester);
          expect(tester.takeException(), isNull);
          expect(_aviso, findsOneWidget);
        },
      );
    }
  });
}
