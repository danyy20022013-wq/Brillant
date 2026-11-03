import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/auth_repository.dart';
import 'package:juego_brilliant/main.dart';

Finder _opcion(int numero) => find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text('$numero'),
    );

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

void main() {
  testWidgets('la app abre en el inicio de sesión', (tester) async {
    await tester.pumpWidget(
      BrilliantApp(repositorio: InMemoryAuthRepository(retraso: Duration.zero)),
    );

    expect(find.widgetWithText(FilledButton, 'Iniciar sesión'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
  });

  testWidgets(
      'recorrido completo: registro, elegir mapa, números, jugar y volver a Buscar partida',
      (tester) async {
    await tester.pumpWidget(
      BrilliantApp(repositorio: InMemoryAuthRepository(retraso: Duration.zero)),
    );

    // 1. Registrarse.
    await _tocar(tester, find.text('Crear cuenta'));
    await _escribir(tester, 'campo-nombre', 'dany');
    await _escribir(tester, 'campo-correo', 'dany@correo.com');
    await _escribir(tester, 'campo-contrasena', '123456');
    await _escribir(tester, 'campo-confirmacion', '123456');
    await _tocar(tester, find.widgetWithText(FilledButton, 'Registrarme'));
    expect(find.text('Hola, dany'), findsOneWidget);

    // 2. Elegir el mapa 3 y buscar partida.
    await _tocar(tester, find.byKey(const Key('mapa-3')));
    await _tocar(tester, find.widgetWithText(FilledButton, 'Buscar partida'));
    expect(find.text('Mapa 3'), findsOneWidget);

    // 3. Elegir los 6 números iniciales.
    for (var n = 1; n <= 6; n++) {
      await tester.tap(find.byIcon(Icons.star_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(_opcion(n));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();

    // 4. Está la partida del mapa 3.
    expect(find.text('Tirar dados'), findsOneWidget);
    expect(find.text('Mapa 3'), findsOneWidget);
    expect(find.text('Turno 1'), findsOneWidget);

    // 5. Terminar muestra el puntaje final.
    await tester.tap(find.text('Terminar'));
    await tester.pumpAndSettle();
    expect(find.text('Puntaje final: 0 puntos'), findsOneWidget);

    // 6. Nueva partida vuelve a Buscar partida.
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Nueva partida'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hola, dany'), findsOneWidget);
    expect(find.text('Tirar dados'), findsNothing);
  });
}