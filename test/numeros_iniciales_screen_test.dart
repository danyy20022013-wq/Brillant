import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/main.dart';
import 'package:juego_brilliant/numeros_iniciales_screen.dart';

// ───────────── ayudas ─────────────

/// Los botones 1 al 6 del selector (solo existen mientras está abierto).
Finder _opcion(int numero) => find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text('$numero'),
    );

/// Toca la primera estrella vacía y elige [numero] en el selector.
Future<void> _elegir(WidgetTester tester, int numero) async {
  await tester.tap(find.byIcon(Icons.star_rounded).first);
  await tester.pumpAndSettle();
  await tester.tap(_opcion(numero));
  await tester.pumpAndSettle();
}

Future<void> _elegirTodos(WidgetTester tester, List<int> numeros) async {
  for (final numero in numeros) {
    await _elegir(tester, numero);
  }
}

FilledButton _botonInicio(WidgetTester tester) {
  return tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'Inicio'),
  );
}

Finder _textoEnCelda(int fila, int columna, String texto) => find.descendant(
      of: find.byKey(Key('celda-$fila-$columna')),
      matching: find.text(texto),
    );

void _pantalla(WidgetTester tester, Size tamano) {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('Contenido inicial', () {
    testWidgets('muestra el título, la instrucción y el botón Inicio',
        (tester) async {
      await tester.pumpWidget(const BrilliantApp());

      expect(find.text('BRILLIANT'), findsOneWidget);
      expect(find.textContaining('Toca una'), findsOneWidget);
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
    });

    testWidgets('tiene 6 casillas con estrella', (tester) async {
      await tester.pumpWidget(const BrilliantApp());

      expect(find.byIcon(Icons.star_rounded), findsNWidgets(6));
    });

    testWidgets('en modo individual no muestra el número de jugador',
        (tester) async {
      await tester.pumpWidget(const BrilliantApp());

      expect(find.textContaining('Jugador'), findsNothing);
    });

    testWidgets('el botón Inicio empieza deshabilitado', (tester) async {
      await tester.pumpWidget(const BrilliantApp());

      expect(_botonInicio(tester).onPressed, isNull);
    });

    testWidgets('al inicio no hay aviso de números repetidos', (tester) async {
      await tester.pumpWidget(const BrilliantApp());

      expect(find.text('Los números no pueden repetirse'), findsNothing);
    });
  });

  group('Selector de números', () {
    testWidgets('al tocar una estrella abre el selector del 1 al 6',
        (tester) async {
      await tester.pumpWidget(const BrilliantApp());

      await tester.tap(find.byIcon(Icons.star_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('Elige un número'), findsOneWidget);
      for (var n = 1; n <= 6; n++) {
        expect(_opcion(n), findsOneWidget, reason: 'botón $n');
      }
    });

    testWidgets('con la casilla vacía no ofrece quitar número', (tester) async {
      await tester.pumpWidget(const BrilliantApp());

      await tester.tap(find.byIcon(Icons.star_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('Quitar número'), findsNothing);
    });

    testWidgets('elegir un número lo muestra en la casilla y cierra el selector',
        (tester) async {
      await tester.pumpWidget(const BrilliantApp());

      await _elegir(tester, 3);

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
    });

    testWidgets('los números se asignan en orden a las 6 estrellas',
        (tester) async {
      await tester.pumpWidget(const BrilliantApp());

      await _elegirTodos(tester, [6, 5, 4, 3, 2, 1]);

      for (var n = 1; n <= 6; n++) {
        expect(find.text('$n'), findsOneWidget, reason: 'número $n');
      }
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('cerrar el selector sin elegir no cambia nada', (tester) async {
      await tester.pumpWidget(const BrilliantApp());
      await tester.tap(find.byIcon(Icons.star_rounded).first);
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10)); // fuera de la hoja
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(6));
    });

    testWidgets('se puede cambiar un número ya elegido', (tester) async {
      await tester.pumpWidget(const BrilliantApp());
      await _elegir(tester, 2);

      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      await tester.tap(_opcion(5));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsNothing);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('Quitar número devuelve la estrella', (tester) async {
      await tester.pumpWidget(const BrilliantApp());
      await _elegir(tester, 3);

      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      expect(find.text('Quitar número'), findsOneWidget);

      await tester.tap(find.text('Quitar número'));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(6));
    });
  });

  group('Reglas de los números', () {
    testWidgets('repetir un número avisa y deshabilita Inicio', (tester) async {
      await tester.pumpWidget(const BrilliantApp());

      await _elegir(tester, 1);
      await _elegir(tester, 1);

      expect(find.text('Los números no pueden repetirse'), findsOneWidget);
      expect(_botonInicio(tester).onPressed, isNull);
    });

    testWidgets('corregir el repetido quita el aviso', (tester) async {
      await tester.pumpWidget(const BrilliantApp());
      await _elegir(tester, 1);
      await _elegir(tester, 1);

      await tester.tap(find.text('1').first);
      await tester.pumpAndSettle();
      await tester.tap(_opcion(2));
      await tester.pumpAndSettle();

      expect(find.text('Los números no pueden repetirse'), findsNothing);
    });

    testWidgets('con menos de 6 números Inicio sigue deshabilitado',
        (tester) async {
      await tester.pumpWidget(const BrilliantApp());

      await _elegirTodos(tester, [1, 2, 3, 4, 5]);

      expect(find.text('Los números no pueden repetirse'), findsNothing);
      expect(_botonInicio(tester).onPressed, isNull);
    });

    testWidgets('con 6 números distintos Inicio se habilita', (tester) async {
      await tester.pumpWidget(const BrilliantApp());

      await _elegirTodos(tester, [1, 2, 3, 4, 5, 6]);

      expect(_botonInicio(tester).onPressed, isNotNull);
    });
  });

  group('Navegación', () {
    testWidgets('Inicio abre el juego con los números elegidos',
        (tester) async {
      await tester.pumpWidget(const BrilliantApp());
      await _elegirTodos(tester, [6, 5, 4, 3, 2, 1]);

      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();

      expect(find.text('Tirar dados'), findsOneWidget);
      // La primera estrella (0, 2) recibió el 6, la segunda (1, 5) el 5...
      expect(_textoEnCelda(0, 2, '6'), findsOneWidget);
      expect(_textoEnCelda(1, 5, '5'), findsOneWidget);
      expect(_textoEnCelda(3, 1, '4'), findsOneWidget);
      expect(_textoEnCelda(3, 4, '3'), findsOneWidget);
      expect(_textoEnCelda(5, 2, '2'), findsOneWidget);
      expect(_textoEnCelda(6, 4, '1'), findsOneWidget);
    });

    testWidgets('el botón ? abre las reglas', (tester) async {
      await tester.pumpWidget(const BrilliantApp());

      await tester.tap(find.byIcon(Icons.help_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Reglas del juego'), findsOneWidget);
    });
  });

  group('Varios jugadores', () {
    testWidgets('cada jugador elige sus números y luego empieza la partida',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NumerosInicialesScreen(jugador: 1, totalJugadores: 2),
        ),
      );
      expect(find.text('Jugador 1 de 2'), findsOneWidget);

      await _elegirTodos(tester, [1, 2, 3, 4, 5, 6]);
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();

      // Ahora le toca al jugador 2, con las estrellas vacías.
      expect(find.text('Jugador 2 de 2'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(6));

      await _elegirTodos(tester, [6, 5, 4, 3, 2, 1]);
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();

      expect(find.text('JUGADOR 1'), findsOneWidget);
      expect(find.text('JUGADOR 2'), findsOneWidget);
      expect(find.text('Tirar dados'), findsOneWidget);
    });
  });

  group('Pantallas de celular', () {
    const pantallas = [Size(320, 568), Size(360, 640), Size(411, 891)];

    for (final tamano in pantallas) {
      final nombre = '${tamano.width.toInt()}x${tamano.height.toInt()}';

      testWidgets('cabe en $nombre sin desbordarse', (tester) async {
        _pantalla(tester, tamano);
        await tester.pumpWidget(const BrilliantApp());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.star_rounded), findsNWidgets(6));
        expect(
          tester.getBottomLeft(find.text('Inicio')).dy,
          lessThanOrEqualTo(tamano.height),
        );

        // El selector también cabe.
        await tester.tap(find.byIcon(Icons.star_rounded).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Elige un número'), findsOneWidget);
      });
    }
  });
}