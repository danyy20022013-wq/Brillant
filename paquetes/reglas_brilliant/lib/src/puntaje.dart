import 'mapas.dart';

/// Puntos de una zona para quien la llena en el [lugar] (0 = 1.º).
/// Del 4.º lugar en adelante (o fuera de la tabla) ya no puntúa.
int puntosPorLugar(List<int> tabla, int lugar) =>
    lugar >= 0 && lugar < tabla.length ? tabla[lugar] : 0;

/// Puntos que [jugador] obtuvo en la zona [zona]. [ordenZonas] trae, por
/// cada zona del mapa, los jugadores que la llenaron en orden.
int puntosEnZona(
  EstructuraTablero estructura,
  List<List<int>> ordenZonas,
  int jugador,
  int zona,
) => puntosPorLugar(
  estructura.zonas[zona].puntos,
  ordenZonas[zona].indexOf(jugador),
);

/// Puntaje total de [jugador] según el orden de llenado de cada zona.
int puntajeTotal(
  EstructuraTablero estructura,
  List<List<int>> ordenZonas,
  int jugador,
) {
  var total = 0;
  for (var z = 0; z < ordenZonas.length; z++) {
    total += puntosEnZona(estructura, ordenZonas, jugador, z);
  }
  return total;
}
