import 'package:flutter/material.dart';

/// Tipo de zona del tablero. Cada tipo trae su color, su regla de
/// colocación y su tabla de puntos.
sealed class Tipo {
  const Tipo();

  static const Tipo rojo = TipoRojo();
  static const Tipo amarillo = TipoAmarillo();
  static const Tipo verde = TipoVerde();
  static const Tipo azul = TipoAzul();
  static const Tipo morado = TipoMorado();
  static const Tipo blanco = TipoBlanco();
  static const Tipo naranja46 = TipoNaranja(minimo: 4, maximo: 6);
  static const Tipo naranja13 = TipoNaranja(minimo: 1, maximo: 3);

  Color get color;
  String get descripcion;
  Map<int, int> get puntuaciones;

  /// true si [posible] se puede agregar a los [actuales] valores de la zona.
  bool esPosibleAgregar(List<int> actuales, int posible);
}

class TipoRojo extends Tipo {
  const TipoRojo();

  @override
  Color get color => const Color(0xFFE5484D);
  @override
  String get descripcion => 'Todos los números deben de ser distintos';
  @override
  Map<int, int> get puntuaciones => {1: 8, 2: 6, 3: 4};
  @override
  bool esPosibleAgregar(List<int> actuales, int posible) =>
      !actuales.contains(posible);
}

class TipoAmarillo extends Tipo {
  const TipoAmarillo();

  @override
  Color get color => const Color(0xFFF5B83D);
  @override
  String get descripcion => 'Todos los números deben de ser distintos';
  @override
  Map<int, int> get puntuaciones => {1: 8, 2: 6, 3: 4};
  @override
  bool esPosibleAgregar(List<int> actuales, int posible) =>
      !actuales.contains(posible);
}

class TipoVerde extends Tipo {
  const TipoVerde();

  @override
  Color get color => const Color(0xFF3FB67A);
  @override
  String get descripcion => 'Se puede colocar cualquier número';
  @override
  Map<int, int> get puntuaciones => {1: 4, 2: 3, 3: 2};
  @override
  bool esPosibleAgregar(List<int> actuales, int posible) => true;
}

class TipoAzul extends Tipo {
  const TipoAzul();

  @override
  Color get color => const Color(0xFF3E9BF0);
  @override
  String get descripcion => 'Todos los números deben de ser iguales';
  @override
  Map<int, int> get puntuaciones => {1: 10, 2: 8, 3: 6};
  @override
  bool esPosibleAgregar(List<int> actuales, int posible) =>
      actuales.isEmpty || actuales.every((n) => n == posible);
}

class TipoMorado extends Tipo {
  const TipoMorado();

  @override
  Color get color => const Color(0xFF8E5CF0);
  @override
  String get descripcion => 'Máximo dos números diferentes por zona';
  @override
  Map<int, int> get puntuaciones => {1: 8, 2: 6, 3: 4};
  @override
  bool esPosibleAgregar(List<int> actuales, int posible) =>
      {...actuales, posible}.length <= 2;
}

class TipoBlanco extends Tipo {
  const TipoBlanco();

  @override
  Color get color => const Color(0xFFD9DCE3);
  @override
  String get descripcion => 'Todos los números deben de ser iguales';
  @override
  Map<int, int> get puntuaciones => const {};
  @override
  bool esPosibleAgregar(List<int> actuales, int posible) =>
      actuales.isEmpty || actuales.every((n) => n == posible);
}

/// Naranja: solo acepta números entre [minimo] y [maximo] (incluidos),
/// aunque se repitan.
class TipoNaranja extends Tipo {
  final int minimo;
  final int maximo;

  const TipoNaranja({required this.minimo, required this.maximo});

  @override
  Color get color => const Color(0xFFF28C28);
  @override
  String get descripcion => 'Solo números del $minimo al $maximo';
  @override
  Map<int, int> get puntuaciones => const {};
  @override
  bool esPosibleAgregar(List<int> actuales, int posible) =>
      posible >= minimo && posible <= maximo;
}