import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/juego_screen.dart';
import 'package:juego_brilliant/main.dart';

const _pantallas = [Size(320, 568), Size(360, 640), Size(411, 891)];

/// Alto aproximado del teclado en pantalla de un celular.
const _altoTeclado = 260.0;

void _usarPantalla(WidgetTester tester, Size tamano, {double teclado = 0}) {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  tester.view.viewInsets = FakeViewPadding(bottom: teclado);
  addTearDown(tester.view.reset);
}

String _nombre(Size tamano) =>
    '${tamano.width.toInt()}x${tamano.height.toInt()}';

void main() {
  for (final tamano in _pantallas) {
    for (final teclado in [0.0, _altoTeclado]) {
      final conTeclado = teclado > 0 ? 'con teclado' : 'sin teclado';

      testWidgets('login en ${_nombre(tamano)} $conTeclado', (tester) async {
        _usarPantalla(tester, tamano, teclado: teclado);
        await tester.pumpWidget(const BrilliantApp());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('campo-correo')), findsOneWidget);
        expect(find.byKey(const Key('campo-contrasena')), findsOneWidget);

        // El botón se alcanza desplazando aunque el teclado tape la parte
        // de abajo.
        final boton = find.widgetWithText(FilledButton, 'Iniciar sesión');
        await tester.ensureVisible(boton);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getRect(boton).bottom,
            lessThanOrEqualTo(tamano.height - teclado));
      });

      testWidgets('registro en ${_nombre(tamano)} $conTeclado',
          (tester) async {
        _usarPantalla(tester, tamano, teclado: teclado);
        await tester.pumpWidget(const BrilliantApp());
        final crear = find.text('Crear cuenta');
        await tester.ensureVisible(crear);
        await tester.pumpAndSettle();
        await tester.tap(crear);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Registro'), findsOneWidget);
        for (final campo in [
          'campo-nombre',
          'campo-correo',
          'campo-contrasena',
          'campo-confirmacion',
        ]) {
          expect(find.byKey(Key(campo)), findsOneWidget, reason: campo);
        }

        final boton = find.widgetWithText(FilledButton, 'Registrarme');
        await tester.ensureVisible(boton);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getRect(boton).bottom,
            lessThanOrEqualTo(tamano.height - teclado));
      });
    }

    testWidgets('fin de partida con 4 jugadores en ${_nombre(tamano)}',
        (tester) async {
      _usarPantalla(tester, tamano);
      await tester.pumpWidget(
        MaterialApp(
          home: JuegoScreen(
            iniciales: List.filled(4, const [1, 2, 3, 4, 5, 6]),
          ),
        ),
      );
      await tester.tap(find.text('Terminar'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final dialogo = find.byType(AlertDialog);
      expect(dialogo, findsOneWidget);
      // Nadie tiene puntos: empatan los 4 y salen las 4 líneas.
      expect(find.text('Empate entre los jugadores 1, 2, 3, 4'), findsOneWidget);
      for (var j = 1; j <= 4; j++) {
        expect(
          find.descendant(
            of: dialogo,
            matching: find.text('Jugador $j: 0 puntos'),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('Ver tablero'), findsOneWidget);
      expect(find.text('Nueva partida'), findsWidgets);

      // El diálogo entra completo en la pantalla.
      final caja = tester.getRect(dialogo);
      expect(caja.top, greaterThanOrEqualTo(0));
      expect(caja.bottom, lessThanOrEqualTo(tamano.height));
      expect(caja.left, greaterThanOrEqualTo(0));
      expect(caja.right, lessThanOrEqualTo(tamano.width));
    });
  }
}
