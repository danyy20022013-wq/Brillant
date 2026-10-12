import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/main.dart';

void main() {
  testWidgets('muestra 6 estrellas y el botón Inicio deshabilitado',
      (tester) async {
    await tester.pumpWidget(const BrilliantApp());

    expect(find.byIcon(Icons.star_rounded), findsNWidgets(6));
    final boton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(boton.onPressed, isNull);
  });
}