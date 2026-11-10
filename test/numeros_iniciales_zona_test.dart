import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/tipo.dart';
import 'package:juego_brilliant/numeros_iniciales_screen.dart';

// Mapa 4, estrellas en orden de lectura: 0 = naranja 4-6 (0,4),
// 1 morado, 2 rojo, 3 amarillo, 4 azul, 5 = naranja 1-3 (6,1).

Future<void> _abrir(WidgetTester tester, {Size? tamano}) async {
  if (tamano != null) {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    MaterialApp(home: NumerosInicialesScreen(nivel: nivel4)),
  );
}

/// Abre el selector de la estrella vacía número [k] (contando solo vacías).
Future<void> _tocarEstrellaVacia(WidgetTester tester, int k) async {
  await tester.tap(find.byIcon(Icons.star_rounded).at(k));
  await tester.pumpAndSettle();
}

Finder _boton(int numero) => find.descendant(
      of: find.byType(BottomSheet),
      matching: find.widgetWithText(FilledButton, '$numero'),
    );

bool _habilitado(WidgetTester tester, int numero) =>
    tester.widget<FilledButton>(_boton(numero)).onPressed != null;

FilledButton _botonInicio(WidgetTester tester) => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Inicio'),
    );

void main() {
  group('Selector en las estrellas naranjas del mapa 4', () {
    testWidgets('arriba: muestra la regla y deshabilita del 1 al 3',
        (tester) async {
      await _abrir(tester);
      await _tocarEstrellaVacia(tester, 0);

      expect(find.text('Solo números del 4 al 6'), findsOneWidget);
      for (var n = 1; n <= 6; n++) {
        expect(_boton(n), findsOneWidget, reason: 'el $n se ve');
        expect(_habilitado(tester, n), n >= 4, reason: '$n');
      }
    });

    testWidgets('abajo: muestra la regla y deshabilita del 4 al 6',
        (tester) async {
      await _abrir(tester);
      await _tocarEstrellaVacia(tester, 5);

      expect(find.text('Solo números del 1 al 3'), findsOneWidget);
      for (var n = 1; n <= 6; n++) {
        expect(_boton(n), findsOneWidget, reason: 'el $n se ve');
        expect(_habilitado(tester, n), n <= 3, reason: '$n');
      }
    });

    testWidgets('tocar un número deshabilitado no hace nada', (tester) async {
      await _abrir(tester);
      await _tocarEstrellaVacia(tester, 0);

      await tester.tap(_boton(2), warnIfMissed: false);
      await tester.pumpAndSettle();

      // El selector sigue abierto y la estrella sigue vacía.
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Solo números del 4 al 6'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10)); // cerrar tocando fuera
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(6));
    });

    testWidgets('una estrella de otro color tiene los 6 habilitados',
        (tester) async {
      await _abrir(tester);
      await _tocarEstrellaVacia(tester, 1); // morado

      expect(
        find.text('Máximo dos números diferentes por zona'),
        findsOneWidget,
      );
      for (var n = 1; n <= 6; n++) {
        expect(_habilitado(tester, n), isTrue, reason: '$n');
      }
    });

    testWidgets('se puede quitar el número de una estrella naranja',
        (tester) async {
      await _abrir(tester);
      await _tocarEstrellaVacia(tester, 5);
      await tester.tap(_boton(2));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));

      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar número'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_rounded), findsNWidgets(6));
    });
  });

  group('Selector en pantallas de celular', () {
    const pantallas = [Size(320, 568), Size(360, 640), Size(411, 891)];
    for (final tamano in pantallas) {
      testWidgets(
          'cabe con la regla y "Quitar número" en '
          '${tamano.width.toInt()}x${tamano.height.toInt()}', (tester) async {
        await _abrir(tester, tamano: tamano);
        await _tocarEstrellaVacia(tester, 0);
        await tester.tap(_boton(5));
        await tester.pumpAndSettle();

        // Reabre la misma estrella, ahora con número: sale "Quitar número".
        await tester.tap(find.text('5'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Solo números del 4 al 6'), findsOneWidget);
        expect(find.text('Quitar número'), findsOneWidget);
        for (var n = 1; n <= 6; n++) {
          expect(_boton(n), findsOneWidget);
        }
      });
    }
  });

  testWidgets('flujo completo del mapa 4 con 4, 5, 6, 1, 2, 3 hasta la partida',
      (tester) async {
    await _abrir(tester);
    expect(_botonInicio(tester).onPressed, isNull);

    const numeros = [4, 5, 6, 1, 2, 3];
    for (final n in numeros) {
      await _tocarEstrellaVacia(tester, 0);
      await tester.tap(_boton(n));
      await tester.pumpAndSettle();
    }

    expect(find.text('Hay números que no respetan la regla de su zona'),
        findsNothing);
    expect(find.text('Los números no pueden repetirse'), findsNothing);
    expect(_botonInicio(tester).onPressed, isNotNull);

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();

    expect(find.text('Mapa 4'), findsOneWidget);
    expect(find.text('Tirar dados'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      final p = nivel4.estrellas[i];
      expect(
        find.descendant(
          of: find.byKey(Key('celda-${p.fila}-${p.columna}')),
          matching: find.text('${numeros[i]}'),
        ),
        findsOneWidget,
        reason: 'estrella $i',
      );
    }
  });
}
