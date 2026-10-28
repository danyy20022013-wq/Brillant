import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/reglas.dart';

Future<void> _abrirReglas(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => mostrarReglas(context),
              child: const Text('Abrir reglas'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir reglas'));
  await tester.pumpAndSettle();
}

/// Los puntos de una fila de la tabla, sin depender de los espacios exactos.
Finder _fila(int primero, int segundo, int tercero) => find.textContaining(
      RegExp('1\\.º $primero\\s+2\\.º $segundo\\s+3\\.º $tercero'),
    );

void main() {
  group('Reglas del juego', () {
    testWidgets('se abre con el título y sus tres secciones', (tester) async {
      await _abrirReglas(tester);

      expect(find.text('Reglas del juego'), findsOneWidget);
      expect(find.text('CÓMO SE JUEGA'), findsOneWidget);
      expect(find.text('REGLA DE CADA COLOR'), findsOneWidget);
      expect(find.text('PUNTOS POR ZONA'), findsOneWidget);
    });

    testWidgets('explica cómo se juega', (tester) async {
      await _abrirReglas(tester);

      expect(find.textContaining('6 números iniciales'), findsOneWidget);
      expect(find.textContaining('tira los dos dados'), findsOneWidget);
      expect(find.textContaining('ANCLA'), findsOneWidget);
      expect(find.textContaining('nunca en diagonal'), findsOneWidget);
      expect(find.textContaining('pasa el turno'), findsOneWidget);
    });

    testWidgets('cada color explica su regla y cuántas zonas tiene',
        (tester) async {
      await _abrirReglas(tester);

      expect(find.text('Rojo · 2 zonas'), findsOneWidget);
      expect(find.text('Azul · 2 zonas'), findsOneWidget);
      expect(find.text('Verde · 2 zonas'), findsOneWidget);
      expect(find.text('Morado · 2 zonas'), findsOneWidget);
      expect(
        find.text('Amarillo · 1 zona de 5 casillas repartidas por el tablero'),
        findsOneWidget,
      );

      // Rojo y amarillo comparten la regla de números distintos.
      expect(
        find.text('Todos los números deben de ser distintos'),
        findsNWidgets(2),
      );
      expect(find.text('Se puede colocar cualquier número'), findsOneWidget);
      expect(find.text('Todos los números deben de ser iguales'),
          findsOneWidget);
      expect(find.text('Máximo dos números diferentes por zona'),
          findsOneWidget);
    });

    testWidgets('la tabla de puntos muestra 1.º, 2.º y 3.º de cada color',
        (tester) async {
      await _abrirReglas(tester);

      expect(_fila(6, 4, 2), findsNWidgets(2)); // rojo y morado
      expect(_fila(7, 5, 3), findsOneWidget); // azul
      expect(_fila(4, 3, 2), findsOneWidget); // verde
      expect(_fila(8, 6, 4), findsOneWidget); // amarillo
    });

    testWidgets('aclara que las zonas llenas no se vacían y que son independientes',
        (tester) async {
      await _abrirReglas(tester);

      expect(find.textContaining('no se vacía'), findsOneWidget);
      expect(find.textContaining('son independientes'), findsOneWidget);
      expect(find.textContaining('una sola zona'), findsOneWidget);
    });

    testWidgets('se puede desplazar hasta el final', (tester) async {
      await _abrirReglas(tester);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -3000),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getBottomLeft(_fila(8, 6, 4)).dy,
        lessThanOrEqualTo(600),
      );
    });

    testWidgets('se cierra al tocar fuera de la hoja', (tester) async {
      await _abrirReglas(tester);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Reglas del juego'), findsNothing);
    });

    testWidgets('cabe en un celular de 320 px sin desbordarse', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _abrirReglas(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Reglas del juego'), findsOneWidget);
    });
  });
}