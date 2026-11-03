import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/auth_repository.dart';
import 'package:juego_brilliant/buscar_partida_screen.dart';
import 'package:juego_brilliant/juego.dart';
import 'package:juego_brilliant/juego_screen.dart';
import 'package:juego_brilliant/numeros_iniciales_screen.dart';
import 'package:juego_brilliant/reglas.dart';
import 'package:juego_brilliant/tipo.dart';

Future<void> _abrirReglas(
  WidgetTester tester, {
  Nivel? mapa,
  Size? tamano,
}) async {
  if (tamano != null) {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => mostrarReglas(context, mapa ?? nivel1),
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

String _puntos(List<int> p) => '1.º ${p[0]}   2.º ${p[1]}   3.º ${p[2]}';

Finder _tarjeta(String nombre) => find.byKey(Key('regla-$nombre'));

/// Texto dentro de la tarjeta de la zona [nombre].
Finder _enTarjeta(String nombre, String texto) => find.descendant(
      of: _tarjeta(nombre),
      matching: find.text(texto),
    );

/// Nombres de zona esperados por mapa (datos oficiales), en orden.
const _nombres = {
  1: [
    'Amarillo', 'Verde 1', 'Azul 1', 'Morado 1', 'Verde 2', //
    'Rojo 1', 'Morado 2', 'Rojo 2', 'Azul 2',
  ],
  2: [
    'Morado 1', 'Blanco', 'Verde 1', 'Amarillo', 'Azul 1', //
    'Rojo 1', 'Rojo 2', 'Verde 2', 'Azul 2', 'Morado 2',
  ],
  3: [
    'Amarillo 1', 'Morado 1', 'Blanco', 'Amarillo 2', 'Rojo 1', //
    'Rojo 2', 'Verde', 'Azul', 'Morado 2', 'Morado 3',
  ],
  4: [
    'Naranja 4-6', 'Amarillo', 'Rojo 1', 'Azul', 'Verde', //
    'Rojo 2', 'Morado', 'Rojo 3', 'Rojo 4', 'Naranja 1-3',
  ],
};

void main() {
  group('Reglas del juego', () {
    testWidgets('se abre con el título, el mapa y sus tres secciones',
        (tester) async {
      await _abrirReglas(tester);

      expect(find.text('Reglas del juego'), findsOneWidget);
      expect(find.text('Mapa 1 · 9 zonas'), findsOneWidget);
      expect(find.text('CÓMO SE JUEGA'), findsOneWidget);
      expect(find.text('PUNTOS POR ZONA'), findsOneWidget);
      expect(find.text('ZONAS DEL MAPA 1'), findsOneWidget);
    });

    testWidgets('explica cómo se juega', (tester) async {
      await _abrirReglas(tester);

      expect(find.textContaining('6 números iniciales'), findsOneWidget);
      expect(find.textContaining('tira los dos dados'), findsOneWidget);
      expect(find.textContaining('ANCLA'), findsOneWidget);
      expect(find.textContaining('nunca en diagonal'), findsOneWidget);
      expect(find.textContaining('pasa el turno'), findsOneWidget);
    });

    testWidgets('aclara que las zonas llenas no se vacían y que son independientes',
        (tester) async {
      await _abrirReglas(tester);

      expect(find.textContaining('no se vacía'), findsOneWidget);
      expect(find.textContaining('son independientes'), findsOneWidget);
      expect(find.textContaining('una sola zona'), findsOneWidget);
    });

    testWidgets('ya no describe solo el mapa 1', (tester) async {
      await _abrirReglas(tester, mapa: nivel3);

      expect(find.textContaining('2 zonas'), findsNothing);
      expect(find.textContaining('1 zona de 5 casillas'), findsNothing);
    });

    testWidgets('se cierra al tocar fuera de la hoja', (tester) async {
      await _abrirReglas(tester);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Reglas del juego'), findsNothing);
    });
  });

  group('Los 7 tipos tienen nombre y regla', () {
    const tipos = [
      Tipo.rojo,
      Tipo.amarillo,
      Tipo.verde,
      Tipo.azul,
      Tipo.morado,
      Tipo.blanco,
      Tipo.naranja46,
      Tipo.naranja13,
    ];

    test('nombres distintos y reglas escritas', () {
      final nombres = [for (final t in tipos) nombreDe(t)];
      expect(nombres, [
        'Rojo',
        'Amarillo',
        'Verde',
        'Azul',
        'Morado',
        'Blanco',
        'Naranja 4-6',
        'Naranja 1-3',
      ]);
      for (final t in tipos) {
        expect(t.descripcion, isNotEmpty, reason: nombreDe(t));
      }
    });

    test('cada tipo que aparece en un mapa está en la lista', () {
      for (final mapa in nivelesDisponibles) {
        for (final zona in mapa.estructura.zonas) {
          expect(tipos, contains(zona.tipo), reason: zona.nombre);
        }
      }
    });
  });

  for (final mapa in nivelesDisponibles) {
    group('Hoja del mapa ${mapa.numero}', () {
      final zonas = mapa.estructura.zonas;

      testWidgets('una tarjeta por zona con nombre, regla y puntos',
          (tester) async {
        await _abrirReglas(tester, mapa: mapa);

        expect(find.text('ZONAS DEL MAPA ${mapa.numero}'), findsOneWidget);
        expect(
          find.text('Mapa ${mapa.numero} · ${zonas.length} zonas'),
          findsOneWidget,
        );
        expect(
          [for (final z in zonas) z.nombre],
          _nombres[mapa.numero],
        );
        expect(
          find.byWidgetPredicate(
            (w) => w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('regla-'),
          ),
          findsNWidgets(zonas.length),
        );

        for (final zona in zonas) {
          final n = zona.nombre;
          expect(_tarjeta(n), findsOneWidget, reason: n);
          expect(
            _enTarjeta(n, '$n · ${zona.celdas.length} casillas'),
            findsOneWidget,
            reason: n,
          );
          expect(_enTarjeta(n, zona.tipo.descripcion), findsOneWidget,
              reason: n);
          expect(_enTarjeta(n, _puntos(zona.puntos)), findsOneWidget,
              reason: n);
          final caja = tester.widget<Container>(_tarjeta(n));
          expect((caja.decoration! as BoxDecoration).color, zona.tipo.color,
              reason: n);
        }
      });

      const pantallas = [Size(320, 568), Size(360, 640), Size(411, 891)];
      for (final tamano in pantallas) {
        testWidgets(
            'cabe y se desplaza hasta la última zona en '
            '${tamano.width.toInt()}x${tamano.height.toInt()}', (tester) async {
          await _abrirReglas(tester, mapa: mapa, tamano: tamano);
          expect(tester.takeException(), isNull);

          await tester.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, -5000),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          final ultima = _tarjeta(zonas.last.nombre);
          expect(
            tester.getBottomLeft(ultima).dy,
            lessThanOrEqualTo(tamano.height),
          );
        });
      }
    });
  }

  group('Datos oficiales en la hoja', () {
    testWidgets('mapa 1: puntos de siempre', (tester) async {
      await _abrirReglas(tester);

      expect(_enTarjeta('Amarillo', '1.º 8   2.º 6   3.º 4'), findsOneWidget);
      expect(_enTarjeta('Azul 1', '1.º 7   2.º 5   3.º 3'), findsOneWidget);
      expect(_enTarjeta('Verde 2', '1.º 4   2.º 3   3.º 2'), findsOneWidget);
      expect(_enTarjeta('Rojo 1', '1.º 6   2.º 4   3.º 2'), findsOneWidget);
    });

    testWidgets('mapa 2: blanco con su regla y 3/2/1', (tester) async {
      await _abrirReglas(tester, mapa: nivel2);

      expect(_enTarjeta('Blanco', 'Blanco · 2 casillas'), findsOneWidget);
      expect(
        _enTarjeta('Blanco', 'Todos los números deben ser iguales (blanco)'),
        findsOneWidget,
      );
      expect(_enTarjeta('Blanco', '1.º 3   2.º 2   3.º 1'), findsOneWidget);
      expect(_enTarjeta('Amarillo', '1.º 6   2.º 4   3.º 2'), findsOneWidget);
    });

    testWidgets('mapa 3: verde 6/5/4 y blanco 8/6/4', (tester) async {
      await _abrirReglas(tester, mapa: nivel3);

      expect(_enTarjeta('Verde', 'Verde · 9 casillas'), findsOneWidget);
      expect(_enTarjeta('Verde', '1.º 6   2.º 5   3.º 4'), findsOneWidget);
      expect(_enTarjeta('Blanco', '1.º 8   2.º 6   3.º 4'), findsOneWidget);
      expect(_enTarjeta('Amarillo 2', '1.º 7   2.º 5   3.º 3'), findsOneWidget);
    });

    testWidgets('mapa 4: naranjas con su rango y 6/4/3', (tester) async {
      await _abrirReglas(tester, mapa: nivel4);

      expect(
        _enTarjeta('Naranja 4-6', 'Solo números del 4 al 6'),
        findsOneWidget,
      );
      expect(
        _enTarjeta('Naranja 1-3', 'Solo números del 1 al 3'),
        findsOneWidget,
      );
      expect(_enTarjeta('Naranja 4-6', '1.º 6   2.º 4   3.º 3'),
          findsOneWidget);
      expect(_enTarjeta('Naranja 1-3', '1.º 6   2.º 4   3.º 3'),
          findsOneWidget);
      expect(_enTarjeta('Verde', '1.º 3   2.º 2   3.º 1'), findsOneWidget);
      expect(_enTarjeta('Azul', '1.º 8   2.º 6   3.º 4'), findsOneWidget);
    });

    testWidgets('texto oscuro sobre amarillo y blanco', (tester) async {
      await _abrirReglas(tester, mapa: nivel2);

      for (final nombre in ['Blanco', 'Amarillo']) {
        final texto = tester.widget<Text>(
          _enTarjeta(nombre, '$nombre · ${nombre == 'Blanco' ? 2 : 5} casillas'),
        );
        expect(texto.style?.color, Colors.black87, reason: nombre);
      }
      final rojo = tester.widget<Text>(
        _enTarjeta('Rojo 1', 'Rojo 1 · 6 casillas'),
      );
      expect(rojo.style?.color, Colors.white);
    });
  });

  group('El botón ? abre la hoja del mapa correcto', () {
    testWidgets('desde la partida', (tester) async {
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
      await tester.tap(find.byTooltip('Reglas'));
      await tester.pumpAndSettle();

      expect(find.text('ZONAS DEL MAPA 3'), findsOneWidget);
      expect(_tarjeta('Amarillo 2'), findsOneWidget);
    });

    testWidgets('desde los números iniciales', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: NumerosInicialesScreen(nivel: nivel4)),
      );
      await tester.tap(find.byTooltip('Reglas'));
      await tester.pumpAndSettle();

      expect(find.text('ZONAS DEL MAPA 4'), findsOneWidget);
      expect(_tarjeta('Naranja 4-6'), findsOneWidget);
    });

    testWidgets('desde Buscar partida, con el mapa seleccionado',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BuscarPartidaScreen(
            usuario: const Usuario(nombre: 'dany', correo: 'dany@correo.com'),
            alCerrarSesion: () {},
          ),
        ),
      );

      // Sin tocar nada está el mapa 1.
      await tester.tap(find.byTooltip('Reglas'));
      await tester.pumpAndSettle();
      expect(find.text('ZONAS DEL MAPA 1'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Se elige el mapa 2 y la hoja cambia.
      final tarjeta = find.byKey(const Key('mapa-2'));
      await tester.ensureVisible(tarjeta);
      await tester.pumpAndSettle();
      await tester.tap(tarjeta);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reglas'));
      await tester.pumpAndSettle();

      expect(find.text('ZONAS DEL MAPA 2'), findsOneWidget);
      expect(_tarjeta('Blanco'), findsOneWidget);
    });
  });
}
