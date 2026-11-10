import 'dart:math';

import 'mapas.dart';

/// Cuántas casillas con estrella hay (una por zona inicial).
const cantidadNumerosIniciales = 6;

/// Menor y mayor número que se puede elegir.
const numeroMinimo = 1;
const numeroMaximo = 6;

int _zonaDe(Nivel nivel, int indice) {
  final p = nivel.estrellas[indice];
  return nivel.estructura.indiceZona[p.fila][p.columna];
}

/// true si [valor] respeta la regla de la zona de la estrella [indice],
/// teniendo en cuenta los números de las otras estrellas de esa zona
/// ([valores] puede tener casillas vacías). Es la misma regla de la partida.
bool esPosibleNumeroInicial(
  Nivel nivel,
  List<int?> valores,
  int indice,
  int valor,
) {
  final z = _zonaDe(nivel, indice);
  final otros = <int>[
    for (var i = 0; i < valores.length; i++)
      if (i != indice && valores[i] != null && _zonaDe(nivel, i) == z)
        valores[i]!,
  ];
  return nivel.estructura.zonas[z].tipo.esPosibleAgregar(otros, valor);
}

/// true si [valores] son 6 números del 1 al 6, sin repetir, y cada uno
/// respeta la regla de la zona de su estrella.
bool numerosInicialesValidos(Nivel nivel, List<int> valores) {
  if (valores.length != cantidadNumerosIniciales) return false;
  if (valores.toSet().length != valores.length) return false;
  for (var i = 0; i < valores.length; i++) {
    final v = valores[i];
    if (v < numeroMinimo || v > numeroMaximo) return false;
    if (!esPosibleNumeroInicial(nivel, valores, i, v)) return false;
  }
  return true;
}

/// Todas las combinaciones válidas de números iniciales del [nivel].
List<List<int>> combinacionesIniciales(Nivel nivel) {
  final resultado = <List<int>>[];
  void armar(List<int> actual, Set<int> usados) {
    if (actual.length == cantidadNumerosIniciales) {
      if (numerosInicialesValidos(nivel, actual)) {
        resultado.add(List.unmodifiable(actual));
      }
      return;
    }
    for (var n = numeroMinimo; n <= numeroMaximo; n++) {
      if (usados.contains(n)) continue;
      armar([...actual, n], {...usados, n});
    }
  }

  armar(const [], const {});
  return resultado;
}

/// Unos números iniciales válidos elegidos al azar con [random].
List<int> numerosInicialesAlAzar(Nivel nivel, Random random) {
  final opciones = combinacionesIniciales(nivel);
  return opciones[random.nextInt(opciones.length)];
}
