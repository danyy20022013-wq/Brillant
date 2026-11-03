import 'package:equatable/equatable.dart';

import 'tablero_layout.dart';
import 'tipo.dart';

/// Nombre del tipo en pantalla. Tipo es "sealed": si se agrega un tipo
/// nuevo y falta aquí, el compilador avisa.
String nombreDe(Tipo tipo) => switch (tipo) {
      TipoRojo() => 'Rojo',
      TipoAmarillo() => 'Amarillo',
      TipoVerde() => 'Verde',
      TipoAzul() => 'Azul',
      TipoMorado() => 'Morado',
      TipoBlanco() => 'Blanco',
      TipoNaranja(:final minimo, :final maximo) => 'Naranja $minimo-$maximo',
    };

/// Una zona del tablero: su tipo, las casillas que la forman y los puntos
/// para el 1.º, 2.º y 3.º jugador que la llenen.
class ZonaDef {
  final String nombre;
  final Tipo tipo;
  final List<(int, int)> celdas;
  final List<int> puntos;

  const ZonaDef({
    required this.nombre,
    required this.tipo,
    required this.celdas,
    required this.puntos,
  });
}

/// Movimientos permitidos: arriba, abajo, izquierda y derecha (sin diagonales).
const List<(int, int)> _vecinos = [(1, 0), (-1, 0), (0, 1), (0, -1)];

/// Todas las zonas del tablero y a qué zona pertenece cada casilla.
class EstructuraTablero {
  final List<ZonaDef> zonas;
  final List<List<int>> indiceZona;

  const EstructuraTablero(this.zonas, this.indiceZona);

  /// Agrupa las casillas vecinas (arriba, abajo, izquierda, derecha) del
  /// mismo tipo en una zona. Los tipos de [zonaUnica] son la excepción:
  /// todas sus casillas forman una sola zona aunque estén separadas.
  /// [puntos] da los puntos (1.º, 2.º, 3.º) de cada tipo del mapa; si falta
  /// algún tipo del layout, lanza un ArgumentError.
  factory EstructuraTablero.desdeLayout(
    List<List<Tipo>> layout, {
    Set<Tipo> zonaUnica = const {Tipo.amarillo},
    required Map<Tipo, List<int>> puntos,
  }) {
    final filas = layout.length;
    final columnas = layout[0].length;
    final indice = List.generate(filas, (_) => List.filled(columnas, -1));
    final grupos = <(Tipo, List<(int, int)>)>[];

    for (var f = 0; f < filas; f++) {
      for (var c = 0; c < columnas; c++) {
        if (indice[f][c] != -1) continue;

        final tipo = layout[f][c];
        final idx = grupos.length;
        final celdas = <(int, int)>[];

        if (zonaUnica.contains(tipo)) {
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

        grupos.add((tipo, celdas));
      }
    }

    // Se numera solo si hay más de una zona del mismo tipo.
    final total = <Tipo, int>{};
    for (final (tipo, _) in grupos) {
      total[tipo] = (total[tipo] ?? 0) + 1;
    }
    final contador = <Tipo, int>{};
    final zonas = <ZonaDef>[];
    for (final (tipo, celdas) in grupos) {
      final numero = (contador[tipo] ?? 0) + 1;
      contador[tipo] = numero;
      zonas.add(ZonaDef(
        nombre: total[tipo] == 1
            ? nombreDe(tipo)
            : '${nombreDe(tipo)} $numero',
        tipo: tipo,
        celdas: celdas,
        puntos: puntos[tipo] ??
            (throw ArgumentError('Faltan los puntos de ${nombreDe(tipo)}')),
      ));
    }
    return EstructuraTablero(zonas, indice);
  }
}

/// Un mapa del juego (en pantalla se muestra como "Mapa N").
class Nivel {
  final int numero;
  final List<List<Tipo>> layout;

  /// Las 6 casillas con estrella, en orden de lectura (fila por fila).
  final List<PosicionCasilla> estrellas;

  /// Las zonas del mapa, armadas una sola vez.
  final EstructuraTablero estructura;

  Nivel({
    required this.numero,
    required this.layout,
    required this.estrellas,
    required Set<Tipo> zonaUnica,
    required Map<Tipo, List<int>> puntos,
  }) : estructura = EstructuraTablero.desdeLayout(
          layout,
          zonaUnica: zonaUnica,
          puntos: puntos,
        );

  bool esEstrella(int fila, int columna) =>
      estrellas.any((p) => p.fila == fila && p.columna == columna);
}

final Nivel nivel1 = Nivel(
  numero: 1,
  layout: layoutTableroNivel1,
  estrellas: casillasEstrella,
  zonaUnica: {Tipo.amarillo},
  puntos: {
    Tipo.azul: [7, 5, 3],
    Tipo.verde: [4, 3, 2],
    Tipo.rojo: [6, 4, 2],
    Tipo.morado: [6, 4, 2],
    Tipo.amarillo: [8, 6, 4],
  },
);

final Nivel nivel2 = Nivel(
  numero: 2,
  layout: layoutTableroNivel2,
  estrellas: casillasEstrellaNivel2,
  zonaUnica: {Tipo.amarillo, Tipo.blanco},
  puntos: {
    Tipo.azul: [7, 5, 3],
    Tipo.verde: [4, 3, 2],
    Tipo.rojo: [6, 4, 2],
    Tipo.morado: [6, 4, 2],
    Tipo.amarillo: [6, 4, 2],
    Tipo.blanco: [3, 2, 1],
  },
);

final Nivel nivel3 = Nivel(
  numero: 3,
  layout: layoutTableroNivel3,
  estrellas: casillasEstrellaNivel3,
  zonaUnica: {Tipo.blanco},
  puntos: {
    Tipo.azul: [7, 5, 3],
    Tipo.verde: [6, 5, 4],
    Tipo.rojo: [6, 4, 2],
    Tipo.morado: [7, 5, 3],
    Tipo.amarillo: [7, 5, 3],
    Tipo.blanco: [8, 6, 4],
  },
);

final Nivel nivel4 = Nivel(
  numero: 4,
  layout: layoutTableroNivel4,
  estrellas: casillasEstrellaNivel4,
  zonaUnica: {Tipo.amarillo, Tipo.azul, Tipo.verde},
  puntos: {
    Tipo.azul: [8, 6, 4],
    Tipo.verde: [3, 2, 1],
    Tipo.rojo: [6, 4, 2],
    Tipo.morado: [7, 5, 3],
    Tipo.amarillo: [8, 6, 4],
    Tipo.naranja46: [6, 4, 3],
    Tipo.naranja13: [6, 4, 3],
  },
);

/// Los mapas que se pueden elegir, en orden.
final List<Nivel> nivelesDisponibles = [nivel1, nivel2, nivel3, nivel4];

/// El tablero de UN jugador durante la partida, en un mapa.
class Juego extends Equatable {
  final List<List<int?>> tablero;

  /// Mapa en el que se juega.
  final Nivel nivel;

  const Juego._(this.tablero, this.nivel);

  /// Crea el tablero poniendo los 6 números iniciales en las estrellas
  /// del [nivel] (por defecto el mapa 1).
  factory Juego.inicial(List<int> iniciales, {Nivel? nivel}) {
    final mapa = nivel ?? nivel1;
    final filas = mapa.layout.length;
    final columnas = mapa.layout[0].length;
    final tablero =
        List.generate(filas, (_) => List<int?>.filled(columnas, null));
    for (var i = 0; i < mapa.estrellas.length; i++) {
      final p = mapa.estrellas[i];
      tablero[p.fila][p.columna] = iniciales[i];
    }
    return Juego._(tablero, mapa);
  }

  EstructuraTablero get _estructura => nivel.estructura;

  /// Números que hay ahora mismo en la zona [z].
  List<int> valoresDeZona(int z) {
    final resultado = <int>[];
    for (final (f, c) in _estructura.zonas[z].celdas) {
      final v = tablero[f][c];
      if (v != null) resultado.add(v);
    }
    return resultado;
  }

  bool zonaLlena(int z) =>
      _estructura.zonas[z].celdas.every((p) => tablero[p.$1][p.$2] != null);

  /// true cuando todas las zonas del tablero están llenas.
  bool get estaLleno {
    for (var z = 0; z < _estructura.zonas.length; z++) {
      if (!zonaLlena(z)) return false;
    }
    return true;
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
          final z = _estructura.indiceZona[nf][nc];
          final tipo = _estructura.zonas[z].tipo;
          if (tipo.esPosibleAgregar(valoresDeZona(z), aColocar)) {
            resultado.add((nf, nc));
          }
        }
      }
    }
    return resultado;
  }

  /// Devuelve un tablero nuevo con [valor] puesto en la casilla.
  /// Nada se borra: una zona llena se queda llena.
  Juego colocar(int fila, int columna, int valor) {
    final nuevo = [for (final f in tablero) [...f]];
    nuevo[fila][columna] = valor;
    return Juego._(nuevo, nivel);
  }

  @override
  List<Object?> get props => [nivel.numero, tablero];
}
