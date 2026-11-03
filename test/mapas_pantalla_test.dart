import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/juego.dart';
import 'package:juego_brilliant/juego_screen.dart';
import 'package:juego_brilliant/numeros_iniciales_screen.dart';

Finder _opcion(int numero) => find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text('$numero'),
    );

Future<void> _elegirSeis(WidgetTester tester) async {
  for (var n = 1; n <= 6; n++) {
    await tester.tap(find.byIcon(Icons.star_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(_opcion(n));
    await tester.pumpAndSettle();
  }
}

Finder _textoEn(int fila, int columna, String texto) => find.descendant(
      of: find.byKey(Key('celda-$fila-$columna')),
      matching: find.text(texto),
    );

Color _colorDe(WidgetTester tester, int fila, int columna) {
  final contenedor = tester.widget<Container>(
    find
        .descendant(
          of: find.byKey(Key('celda-$fila-$columna')),
          matching: find.byType(Container),
        )
        .first,
  );
  return (contenedor.decoration! as BoxDecoration).color!;
}

void main() {
  for (final mapa in nivelesDisponibles) {
    group('Mapa ${mapa.numero}', () {
      testWidgets('la pantalla de números muestra el mapa elegido',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: NumerosInicialesScreen(nivel: mapa)),
        );

        expect(find.text('Mapa ${mapa.numero}'), findsOneWidget);
        expect(find.byIcon(Icons.star_rounded), findsNWidgets(6));
      });

      testWidgets(
          'los 6 números van a las estrellas y el tablero usa sus colores',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: NumerosInicialesScreen(nivel: mapa)),
        );

        await _elegirSeis(tester);
        await tester.tap(find.text('Inicio'));
        await tester.pumpAndSettle();

        expect(find.text('Mapa ${mapa.numero}'), findsOneWidget);

        for (var i = 0; i < 6; i++) {
          final p = mapa.estrellas[i];
          expect(_textoEn(p.fila, p.columna, '${i + 1}'), findsOneWidget);
        }

        for (var f = 0; f < 7; f++) {
          for (var c = 0; c < 7; c++) {
            expect(
              _colorDe(tester, f, c),
              mapa.layout[f][c].color,
              reason: 'casilla ($f, $c)',
            );
          }
        }
      });
    });
  }

  testWidgets('el panel del mapa 4 muestra las zonas naranjas', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JuegoScreen(
          iniciales: const [
            [1, 2, 3, 4, 5, 6],
          ],
          nivel: nivel4,
        ),
      ),
    );

    expect(find.text('Naranja 4-6'), findsOneWidget);
    expect(find.text('Naranja 1-3'), findsOneWidget);
    expect(find.text('Verde'), findsOneWidget);
    expect(find.text('+3'), findsOneWidget); // verde: 3 2 1
  });

  testWidgets('el panel del mapa 2 muestra el blanco', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JuegoScreen(
          iniciales: const [
            [1, 2, 3, 4, 5, 6],
          ],
          nivel: nivel2,
        ),
      ),
    );

    expect(find.text('Blanco'), findsOneWidget);
    expect(find.text('Amarillo'), findsOneWidget);
    expect(find.text('+3'), findsOneWidget); // blanco: 3 2 1
  });

  group('Cabe en pantallas de celular', () {
    const pantallas = [Size(320, 568), Size(360, 640), Size(411, 891)];

    for (final mapa in nivelesDisponibles) {
      for (final tamano in pantallas) {
        final nombre =
            'Mapa ${mapa.numero} en ${tamano.width.toInt()}x${tamano.height.toInt()}';

        testWidgets(nombre, (tester) async {
          tester.view.physicalSize = tamano;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp(
              home: JuegoScreen(
                iniciales: const [
                  [1, 2, 3, 4, 5, 6],
                ],
                nivel: mapa,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Tirar dados'), findsOneWidget);
        });
      }
    }
  });

  group('Panel de zonas', () {
    for (final mapa in nivelesDisponibles) {
      testWidgets(
          'mapa ${mapa.numero}: todas sus zonas con los puntos del mapa',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: JuegoScreen(
              iniciales: const [
                [1, 2, 3, 4, 5, 6],
              ],
              nivel: mapa,
            ),
          ),
        );

        final zonas = mapa.estructura.zonas;
        for (final zona in zonas) {
          expect(find.text(zona.nombre), findsOneWidget, reason: zona.nombre);
        }

        // Cuántas zonas muestran cada "+N" (el puntaje del 1.º).
        final cuantas = <int, int>{};
        for (final zona in zonas) {
          cuantas[zona.puntos.first] = (cuantas[zona.puntos.first] ?? 0) + 1;
        }
        for (final MapEntry(key: puntos, value: n) in cuantas.entries) {
          expect(find.text('+$puntos'), findsNWidgets(n), reason: '+$puntos');
        }
      });
    }
  });

  group('Texto oscuro sobre el blanco', () {
    Color? colorDelTexto(WidgetTester tester, int fila, int columna, String t) {
      final texto = tester.widget<Text>(_textoEn(fila, columna, t));
      return texto.style?.color;
    }

    testWidgets('en la partida (mapa 3, estrella blanca en 3,3)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: JuegoScreen(
            iniciales: const [
              [1, 2, 3, 4, 5, 6],
            ],
            nivel: nivel3,
          ),
        ),
      );

      expect(nivel3.layout[3][3].color, const Color(0xFFD9DCE3));
      expect(colorDelTexto(tester, 3, 3, '3'), Colors.black87);
      // En una casilla de color el texto sigue blanco.
      expect(colorDelTexto(tester, 1, 2, '1'), Colors.white);
    });

    testWidgets('en los números iniciales (mapa 3)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: NumerosInicialesScreen(nivel: nivel3)),
      );
      await _elegirSeis(tester);

      final blanco = tester.widget<Text>(
        find.descendant(
          of: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                (w.decoration as BoxDecoration?)?.color ==
                    const Color(0xFFD9DCE3),
          ),
          matching: find.text('3'),
        ),
      );
      expect(blanco.style?.color, Colors.black);
    });
  });
}