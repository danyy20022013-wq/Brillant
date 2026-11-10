import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/auth_repository.dart';
import 'package:juego_brilliant/buscar_partida_screen.dart';
import 'package:juego_brilliant/tipo.dart';

const _usuario = Usuario(nombre: 'dany', correo: 'dany@correo.com');
const _dorado = Color(0xFFFFD166);

Future<void> _abrir(WidgetTester tester, {VoidCallback? alCerrar}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BuscarPartidaScreen(
        usuario: _usuario,
        alCerrarSesion: alCerrar ?? () {},
      ),
    ),
  );
}

Future<void> _tocar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

bool _seleccionado(WidgetTester tester, int numero) {
  final contenedor = tester.widget<Container>(find.byKey(Key('mapa-$numero')));
  final borde = (contenedor.decoration! as BoxDecoration).border! as Border;
  return borde.top.color == _dorado;
}

Color _colorMini(WidgetTester tester, int mapa, int fila, int columna) {
  final contenedor = tester.widget<Container>(
    find.byKey(Key('mini-$mapa-$fila-$columna')),
  );
  return (contenedor.decoration! as BoxDecoration).color!;
}

void main() {
  group('Contenido', () {
    testWidgets('saluda al usuario y muestra el título', (tester) async {
      await _abrir(tester);

      expect(find.text('Hola, dany'), findsOneWidget);
      expect(find.text('Buscar partida'), findsNWidgets(2)); // título y botón
      expect(
        find.text('Elige el mapa en el que quieres jugar'),
        findsOneWidget,
      );
      expect(find.byTooltip('Reglas'), findsOneWidget);
      expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
    });

    testWidgets('hay una tarjeta por cada mapa', (tester) async {
      await _abrir(tester);

      for (final mapa in nivelesDisponibles) {
        final tarjeta = find.byKey(Key('mapa-${mapa.numero}'));
        await tester.ensureVisible(tarjeta);
        expect(tarjeta, findsOneWidget, reason: 'Mapa ${mapa.numero}');
        expect(
          find.text('Mapa ${mapa.numero}'),
          findsOneWidget,
          reason: 'Mapa ${mapa.numero}',
        );
      }
    });

    testWidgets('cada tarjeta dibuja las 49 casillas con los colores del mapa',
        (tester) async {
      await _abrir(tester);

      for (final mapa in nivelesDisponibles) {
        for (var f = 0; f < 7; f++) {
          for (var c = 0; c < 7; c++) {
            expect(
              _colorMini(tester, mapa.numero, f, c),
              mapa.layout[f][c].color,
              reason: 'Mapa ${mapa.numero} ($f, $c)',
            );
          }
        }
      }
    });

    testWidgets('las vistas previas marcan solo las 6 estrellas',
        (tester) async {
      await _abrir(tester);

      for (final mapa in nivelesDisponibles) {
        for (var f = 0; f < 7; f++) {
          for (var c = 0; c < 7; c++) {
            final punto = find.descendant(
              of: find.byKey(Key('mini-${mapa.numero}-$f-$c')),
              matching: find.byType(FractionallySizedBox),
            );
            expect(
              punto,
              mapa.esEstrella(f, c) ? findsOneWidget : findsNothing,
              reason: 'Mapa ${mapa.numero} ($f, $c)',
            );
          }
        }
      }
    });
  });

  group('Elegir el mapa', () {
    testWidgets('el mapa 1 empieza seleccionado', (tester) async {
      await _abrir(tester);

      expect(_seleccionado(tester, 1), isTrue);
      expect(find.text('Mapa 1 · 9 zonas'), findsOneWidget);
    });

    testWidgets('tocar un mapa lo selecciona y muestra sus zonas',
        (tester) async {
      await _abrir(tester);

      final esperadas = {2: 10, 3: 10, 4: 10};
      for (final entrada in esperadas.entries) {
        await _tocar(tester, find.byKey(Key('mapa-${entrada.key}')));

        expect(_seleccionado(tester, entrada.key), isTrue);
        expect(
          find.text('Mapa ${entrada.key} · ${entrada.value} zonas'),
          findsOneWidget,
        );
        expect(_seleccionado(tester, 1), isFalse);
      }
    });

    testWidgets('solo un mapa queda seleccionado a la vez', (tester) async {
      await _abrir(tester);
      await _tocar(tester, find.byKey(const Key('mapa-3')));

      for (final mapa in nivelesDisponibles) {
        expect(_seleccionado(tester, mapa.numero), mapa.numero == 3);
      }
    });
  });

  group('Buscar partida', () {
    testWidgets('abre los números iniciales del mapa elegido', (tester) async {
      await _abrir(tester);

      await _tocar(tester, find.byKey(const Key('mapa-4')));
      await _tocar(tester, find.widgetWithText(FilledButton, 'Buscar partida'));

      expect(find.text('Mapa 4'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(6));
      expect(find.text('Inicio'), findsOneWidget);
    });

    testWidgets('sin tocar nada abre el mapa 1', (tester) async {
      await _abrir(tester);

      await _tocar(tester, find.widgetWithText(FilledButton, 'Buscar partida'));

      expect(find.text('Mapa 1'), findsOneWidget);
    });

    testWidgets('se puede volver a elegir otro mapa', (tester) async {
      await _abrir(tester);
      await _tocar(tester, find.widgetWithText(FilledButton, 'Buscar partida'));

      await _tocar(tester, find.byTooltip('Volver'));

      expect(find.text('Hola, dany'), findsOneWidget);
      expect(_seleccionado(tester, 1), isTrue);
    });
  });

  group('Otros botones', () {
    testWidgets('cerrar sesión avisa a la app', (tester) async {
      var cerro = false;
      await _abrir(tester, alCerrar: () => cerro = true);

      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pump();

      expect(cerro, isTrue);
    });

    testWidgets('el botón ? abre las reglas', (tester) async {
      await _abrir(tester);

      await tester.tap(find.byTooltip('Reglas'));
      await tester.pumpAndSettle();

      expect(find.text('Reglas del juego'), findsOneWidget);
    });
  });

  group('Pantallas de celular', () {
    const pantallas = [
      Size(320, 568),
      Size(360, 640),
      Size(411, 891),
      Size(768, 1024),
    ];

    for (final tamano in pantallas) {
      final nombre = '${tamano.width.toInt()}x${tamano.height.toInt()}';

      testWidgets('cabe en $nombre sin desbordarse', (tester) async {
        tester.view.physicalSize = tamano;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await _abrir(tester);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.widgetWithText(FilledButton, 'Buscar partida'),
          findsOneWidget,
        );
      });
    }
  });
}
