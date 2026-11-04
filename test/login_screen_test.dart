import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/auth_repository.dart';
import 'package:juego_brilliant/main.dart';

InMemoryAuthRepository _repo() =>
    InMemoryAuthRepository(retraso: Duration.zero);

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

Finder get _botonEntrar => find.widgetWithText(FilledButton, 'Iniciar sesión');
Finder get _botonRegistro => find.widgetWithText(FilledButton, 'Registrarme');

Future<void> _llenarRegistro(
  WidgetTester tester, {
  String nombre = 'dany',
  String correo = 'dany@correo.com',
  String contrasena = '123456',
  String confirmacion = '123456',
}) async {
  await _escribir(tester, 'campo-nombre', nombre);
  await _escribir(tester, 'campo-correo', correo);
  await _escribir(tester, 'campo-contrasena', contrasena);
  await _escribir(tester, 'campo-confirmacion', confirmacion);
}

void main() {
  group('Inicio de sesión', () {
    testWidgets('la app abre en el inicio de sesión', (tester) async {
      await tester.pumpWidget(BrilliantApp(repositorio: _repo()));
      // Espera a que termine de comprobar la sesión guardada.
      await tester.pumpAndSettle();

      expect(find.text('BRILLIANT'), findsOneWidget);
      expect(find.byKey(const Key('campo-correo')), findsOneWidget);
      expect(find.byKey(const Key('campo-contrasena')), findsOneWidget);
      expect(_botonEntrar, findsOneWidget);
      expect(find.text('Crear cuenta'), findsOneWidget);
      expect(find.text('Buscar partida'), findsNothing);
    });

    testWidgets('con los campos vacíos muestra los errores', (tester) async {
      await tester.pumpWidget(BrilliantApp(repositorio: _repo()));
      // Espera a que termine de comprobar la sesión guardada.
      await tester.pumpAndSettle();

      await _tocar(tester, _botonEntrar);

      expect(find.text('Escribe tu correo'), findsOneWidget);
      expect(find.text('Escribe tu contraseña'), findsOneWidget);
    });

    testWidgets('un correo mal escrito se rechaza', (tester) async {
      await tester.pumpWidget(BrilliantApp(repositorio: _repo()));
      // Espera a que termine de comprobar la sesión guardada.
      await tester.pumpAndSettle();

      await _escribir(tester, 'campo-correo', 'dany');
      await _escribir(tester, 'campo-contrasena', '123456');
      await _tocar(tester, _botonEntrar);

      expect(find.text('Correo no válido'), findsOneWidget);
    });

    testWidgets('una cuenta que no existe muestra el error', (tester) async {
      await tester.pumpWidget(BrilliantApp(repositorio: _repo()));
      // Espera a que termine de comprobar la sesión guardada.
      await tester.pumpAndSettle();

      await _escribir(tester, 'campo-correo', 'nadie@correo.com');
      await _escribir(tester, 'campo-contrasena', '123456');
      await _tocar(tester, _botonEntrar);

      expect(find.text('Correo o contraseña incorrectos'), findsOneWidget);
      expect(find.text('Buscar partida'), findsNothing);
    });

    testWidgets('una cuenta existente entra a Buscar partida', (tester) async {
      final repo = _repo();
      await repo.registrar(
        nombre: 'dany',
        correo: 'dany@correo.com',
        contrasena: '123456',
      );
      // La cuenta existe, pero nadie tiene la sesión iniciada.
      await repo.cerrarSesion();
      await tester.pumpWidget(BrilliantApp(repositorio: repo));
      // Espera a que termine de comprobar la sesión guardada.
      await tester.pumpAndSettle();

      await _escribir(tester, 'campo-correo', 'dany@correo.com');
      await _escribir(tester, 'campo-contrasena', '123456');
      await _tocar(tester, _botonEntrar);

      expect(find.text('Hola, dany'), findsOneWidget);
      expect(
        find.text('Elige el mapa en el que quieres jugar'),
        findsOneWidget,
      );
    });

    testWidgets('el ojito muestra y oculta la contraseña', (tester) async {
      await tester.pumpWidget(BrilliantApp(repositorio: _repo()));
      // Espera a que termine de comprobar la sesión guardada.
      await tester.pumpAndSettle();

      bool oculta() => tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('campo-contrasena')),
              matching: find.byType(EditableText),
            ),
          )
          .obscureText;

      expect(oculta(), isTrue);

      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.pump();
      expect(oculta(), isFalse);

      await tester.tap(find.byTooltip('Ocultar contraseña'));
      await tester.pump();
      expect(oculta(), isTrue);
    });
  });

  group('Registro', () {
    testWidgets('Crear cuenta abre el registro y se puede volver', (
      tester,
    ) async {
      await tester.pumpWidget(BrilliantApp(repositorio: _repo()));
      // Espera a que termine de comprobar la sesión guardada.
      await tester.pumpAndSettle();

      await _tocar(tester, find.text('Crear cuenta'));
      expect(find.text('Registro'), findsOneWidget);
      expect(find.byKey(const Key('campo-nombre')), findsOneWidget);
      expect(find.byKey(const Key('campo-confirmacion')), findsOneWidget);
      expect(_botonRegistro, findsOneWidget);

      await _tocar(tester, find.text('Ya tengo cuenta'));
      expect(find.text('Registro'), findsNothing);
      expect(_botonEntrar, findsOneWidget);
    });

    testWidgets('valida cada campo', (tester) async {
      await tester.pumpWidget(BrilliantApp(repositorio: _repo()));
      // Espera a que termine de comprobar la sesión guardada.
      await tester.pumpAndSettle();
      await _tocar(tester, find.text('Crear cuenta'));

      await _llenarRegistro(
        tester,
        nombre: 'ab',
        correo: 'mal',
        contrasena: '123',
        confirmacion: '456',
      );
      await _tocar(tester, _botonRegistro);

      expect(find.text('Mínimo 3 caracteres'), findsOneWidget);
      expect(find.text('Correo no válido'), findsOneWidget);
      expect(find.text('Mínimo 6 caracteres'), findsOneWidget);
      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    });

    testWidgets('si las contraseñas no coinciden no crea la cuenta', (
      tester,
    ) async {
      await tester.pumpWidget(BrilliantApp(repositorio: _repo()));
      // Espera a que termine de comprobar la sesión guardada.
      await tester.pumpAndSettle();
      await _tocar(tester, find.text('Crear cuenta'));

      await _llenarRegistro(tester, confirmacion: '654321');
      await _tocar(tester, _botonRegistro);

      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
      expect(find.text('Buscar partida'), findsNothing);
    });

    testWidgets('un registro correcto entra directo a Buscar partida', (
      tester,
    ) async {
      await tester.pumpWidget(BrilliantApp(repositorio: _repo()));
      // Espera a que termine de comprobar la sesión guardada.
      await tester.pumpAndSettle();
      await _tocar(tester, find.text('Crear cuenta'));

      await _llenarRegistro(tester);
      await _tocar(tester, _botonRegistro);

      expect(find.text('Hola, dany'), findsOneWidget);
      expect(find.text('Registro'), findsNothing);
    });

    testWidgets('un correo repetido muestra el error', (tester) async {
      final repo = _repo();
      await repo.registrar(
        nombre: 'otro',
        correo: 'dany@correo.com',
        contrasena: '123456',
      );
      // La cuenta existe, pero nadie tiene la sesión iniciada.
      await repo.cerrarSesion();
      await tester.pumpWidget(BrilliantApp(repositorio: repo));
      // Espera a que termine de comprobar la sesión guardada.
      await tester.pumpAndSettle();
      await _tocar(tester, find.text('Crear cuenta'));

      await _llenarRegistro(tester);
      await _tocar(tester, _botonRegistro);

      expect(find.text('Ese correo ya está registrado'), findsOneWidget);
      expect(find.text('Registro'), findsOneWidget);
    });

    testWidgets('un nombre repetido muestra el error', (tester) async {
      final repo = _repo();
      await repo.registrar(
        nombre: 'dany',
        correo: 'otro@correo.com',
        contrasena: '123456',
      );
      // La cuenta existe, pero nadie tiene la sesión iniciada.
      await repo.cerrarSesion();
      await tester.pumpWidget(BrilliantApp(repositorio: repo));
      // Espera a que termine de comprobar la sesión guardada.
      await tester.pumpAndSettle();
      await _tocar(tester, find.text('Crear cuenta'));

      await _llenarRegistro(tester);
      await _tocar(tester, _botonRegistro);

      expect(find.text('Ese nombre de usuario ya está en uso'), findsOneWidget);
    });
  });

  group('Cerrar sesión', () {
    testWidgets('cerrar sesión vuelve al inicio y se puede entrar de nuevo', (
      tester,
    ) async {
      await tester.pumpWidget(BrilliantApp(repositorio: _repo()));
      // Espera a que termine de comprobar la sesión guardada.
      await tester.pumpAndSettle();
      await _tocar(tester, find.text('Crear cuenta'));
      await _llenarRegistro(tester);
      await _tocar(tester, _botonRegistro);
      expect(find.text('Hola, dany'), findsOneWidget);

      await _tocar(tester, find.byTooltip('Cerrar sesión'));
      expect(_botonEntrar, findsOneWidget);
      expect(find.text('Hola, dany'), findsNothing);

      await _escribir(tester, 'campo-correo', 'dany@correo.com');
      await _escribir(tester, 'campo-contrasena', '123456');
      await _tocar(tester, _botonEntrar);
      expect(find.text('Hola, dany'), findsOneWidget);
    });
  });

  group('Pantallas de celular', () {
    const pantallas = [Size(320, 568), Size(360, 640), Size(411, 891)];

    for (final tamano in pantallas) {
      final nombre = '${tamano.width.toInt()}x${tamano.height.toInt()}';

      testWidgets('el inicio de sesión y el registro caben en $nombre', (
        tester,
      ) async {
        tester.view.physicalSize = tamano;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(BrilliantApp(repositorio: _repo()));

        // Espera a que termine de comprobar la sesión guardada.

        await tester.pumpAndSettle();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await _tocar(tester, find.text('Crear cuenta'));
        expect(tester.takeException(), isNull);
        expect(find.text('Registro'), findsOneWidget);
      });
    }
  });
}
