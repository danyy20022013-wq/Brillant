import 'package:equatable/equatable.dart';

import 'tablero_layout.dart';
import 'tipo.dart';

/// Puntos que da una zona según cuántas veces se ha llenado
/// (1.er, 2.º y 3.er llenado). Después del tercero ya no puntúa.
List<int> puntosDe(Tipo tipo) {
  if (tipo is TipoRojo) return const [6, 4, 2];
  if (tipo is TipoAzul) return const [7, 5, 3];
  if (tipo is TipoVerde) return const [4, 3, 2];
  if (tipo is TipoAmarillo) return const [8, 6, 4];
  return const [6, 4, 2]; // morado
}

String nombreDe(Tipo tipo) {
  if (tipo is TipoRojo) return 'Rojo';
  if (tipo is TipoAzul) return 'Azul';
  if (tipo is TipoVerde) return 'Verde';
  if (tipo is TipoAmarillo) return 'Amarillo';
  return 'Morado';
}

/// Una zona del tablero: su tipo y las casillas que la forman.
class ZonaDef {
  final String nombre;
  final Tipo tipo;
  final List<(int, int)> celdas;

  const ZonaDef({
    required this.nombre,
    required this.tipo,
    required this.celdas,
  });
}

/// Todas las zonas del tablero y a qué zona pertenece cada casilla.
class EstructuraTablero {
  final List<ZonaDef> zonas;
  final List<List<int>> indiceZona;

  const EstructuraTablero(this.zonas, this.indiceZona);

  /// Agrupa las casillas vecinas del mismo color en una zona.
  /// El amarillo es la excepción: todas sus casillas son una sola zona.
  factory EstructuraTablero.desdeLayout(List<List<Tipo>> layout) {
    final filas = layout.length;
    final columnas = layout[0].length;
    final indice = List.generate(filas, (_) => List.filled(columnas, -1));
    final zonas = <ZonaDef>[];
    final contador = <Tipo, int>{};

    for (var f = 0; f < filas; f++) {
      for (var c = 0; c < columnas; c++) {
        if (indice[f][c] != -1) continue;

        final tipo = layout[f][c];
        final idx = zonas.length;
        final celdas = <(int, int)>[];

        if (tipo == Tipo.amarillo) {
          for (var ff = 0; ff < filas; ff++) {
            for (var cc = 0; cc < columnas; cc++) {
              if (layout[ff][cc] == tipo) {
                indice[ff][cc] = idx;
                celdas.add((ff, cc));
              }
            }
          }
        } else {
          final pendientes = <(int, int)>[(f, c)];
          indice[f][c] = idx;
          while (pendientes.isNotEmpty) {
            final (actualF, actualC) = pendientes.removeLast();
            celdas.add((actualF, actualC));
            for (final (df, dc) in _vecinos) {
              final nf = actualF + df;
              final nc = actualC + dc;
              if (nf < 0 || nf >= filas || nc < 0 || nc >= columnas) continue;
              if (indice[nf][nc] != -1 || layout[nf][nc] != tipo) continue;
              indice[nf][nc] = idx;
              pendientes.add((nf, nc));
            }
          }
        }

        final numero = (contador[tipo] ?? 0) + 1;
        contador[tipo] = numero;
        zonas.add(ZonaDef(
          nombre: tipo == Tipo.amarillo
              ? 'Amarillo'
              : '${nombreDe(tipo)} $numero',
          tipo: tipo,
          celdas: celdas,
        ));
      }
    }
    return EstructuraTablero(zonas, indice);
  }
}

/// Movimientos permitidos: arriba, abajo, izquierda y derecha (sin diagonales).
const List<(int, int)> _vecinos = [(1, 0), (-1, 0), (0, 1), (0, -1)];

final EstructuraTablero estructuraNivel1 =
    EstructuraTablero.desdeLayout(layoutTableroNivel1);

/// Estado del tablero durante la partida.
class Juego extends Equatable {
  final List<List<int?>> tablero;
  final List<int> completadas; // veces que se llenó cada zona
  final List<int> puntos; // puntos acumulados por zona

  const Juego._(this.tablero, this.completadas, this.puntos);

  /// Crea la partida poniendo los 6 números iniciales en las estrellas.
  factory Juego.inicial(List<int> iniciales) {
    final filas = layoutTableroNivel1.length;
    final columnas = layoutTableroNivel1[0].length;
    final tablero =
        List.generate(filas, (_) => List<int?>.filled(columnas, null));
    for (var i = 0; i < casillasEstrella.length; i++) {
      final p = casillasEstrella[i];
      tablero[p.fila][p.columna] = iniciales[i];
    }
    final n = estructuraNivel1.zonas.length;
    return Juego._(tablero, List.filled(n, 0), List.filled(n, 0));
  }

  static bool esSemilla(int fila, int columna) => casillasEstrella
      .any((p) => p.fila == fila && p.columna == columna);

  int get puntajeTotal => puntos.fold<int>(0, (a, b) => a + b);

  /// true cuando todas las zonas ya llegaron a su tercer llenado.
  bool get todasAgotadas => completadas.every((c) => c >= 3);

  /// Números que hay ahora mismo en la zona [z].
  List<int> valoresDeZona(int z) {
    final resultado = <int>[];
    for (final (f, c) in estructuraNivel1.zonas[z].celdas) {
      final v = tablero[f][c];
      if (v != null) resultado.add(v);
    }
    return resultado;
  }

  /// Casillas vacías donde se puede poner [aColocar], pegadas (arriba,
  /// abajo, izquierda o derecha) a una casilla que tenga el número [ancla]
  /// y respetando la regla de color de la zona.
  Set<(int, int)> jugadasPosibles({required int ancla, required int aColocar}) {
    final resultado = <(int, int)>{};
    for (var f = 0; f < tablero.length; f++) {
      for (var c = 0; c < tablero[f].length; c++) {
        if (tablero[f][c] != ancla) continue;
        for (final (df, dc) in _vecinos) {
          final nf = f + df;
          final nc = c + dc;
          if (nf < 0 || nf >= tablero.length) continue;
          if (nc < 0 || nc >= tablero[nf].length) continue;
          if (tablero[nf][nc] != null) continue;
          final z = estructuraNivel1.indiceZona[nf][nc];
          final tipo = estructuraNivel1.zonas[z].tipo;
          if (tipo.esPosibleAgregar(valoresDeZona(z), aColocar)) {
            resultado.add((nf, nc));
          }
        }
      }
    }
    return resultado;
  }

  /// Coloca [valor] en la casilla. Si con eso se llena la zona, suma los
  /// puntos de ese llenado (1.º, 2.º, 3.º) y la vacía para volver a llenarla.
  /// Las casillas con estrella conservan su número inicial.
  Juego colocar(int fila, int columna, int valor) {
    final nuevo = [for (final f in tablero) [...f]];
    nuevo[fila][columna] = valor;

    final z = estructuraNivel1.indiceZona[fila][columna];
    final zona = estructuraNivel1.zonas[z];
    final completadasNuevas = [...completadas];
    final puntosNuevos = [...puntos];

    final llena = zona.celdas.every((p) => nuevo[p.$1][p.$2] != null);
    if (llena) {
      final tabla = puntosDe(zona.tipo);
      if (completadasNuevas[z] < tabla.length) {
        puntosNuevos[z] += tabla[completadasNuevas[z]];
      }
      completadasNuevas[z] += 1;
      for (final (f, c) in zona.celdas) {
        if (!esSemilla(f, c)) nuevo[f][c] = null;
      }
    }
    return Juego._(nuevo, completadasNuevas, puntosNuevos);
  }

  @override
  List<Object?> get props => [tablero, completadas, puntos];
}