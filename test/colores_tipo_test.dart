import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/tipo.dart';

/// Los colores de cada tipo viven en la app (las reglas están en el paquete
/// reglas_brilliant).
void main() {
  test('Los dos naranjas comparten color y los colores son todos distintos',
      () {
    expect(Tipo.naranja46.color, Tipo.naranja13.color);
    final colores = [
      Tipo.rojo,
      Tipo.amarillo,
      Tipo.verde,
      Tipo.azul,
      Tipo.morado,
      Tipo.blanco,
      Tipo.naranja46,
    ].map((t) => t.color).toSet();
    expect(colores.length, 7);
  });

  test('cada tipo conserva su color de siempre', () {
    expect(Tipo.rojo.color, const Color(0xFFE5484D));
    expect(Tipo.amarillo.color, const Color(0xFFF5B83D));
    expect(Tipo.verde.color, const Color(0xFF3FB67A));
    expect(Tipo.azul.color, const Color(0xFF3E9BF0));
    expect(Tipo.morado.color, const Color(0xFF8E5CF0));
    expect(Tipo.blanco.color, const Color(0xFFD9DCE3));
    expect(Tipo.naranja46.color, const Color(0xFFF28C28));
  });
}
