import 'mapas.dart';

/// El tablero de UN jugador durante la partida, en un mapa.
class Juego {
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
    final tablero = List.generate(
      filas,
      (_) => List<int?>.filled(columnas, null),
    );
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
  /// y respetando la regla de la zona.
  Set<(int, int)> jugadasPosibles({required int ancla, required int aColocar}) {
    final resultado = <(int, int)>{};
    for (var f = 0; f < tablero.length; f++) {
      for (var c = 0; c < tablero[f].length; c++) {
        if (tablero[f][c] != ancla) continue;
        for (final (df, dc) in direccionesVecinas) {
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

  /// true si con los dados [dado1] y [dado2] hay al menos una jugada,
  /// usando cualquiera de los dos como ancla.
  bool hayJugadaCon(int dado1, int dado2) =>
      jugadasPosibles(ancla: dado1, aColocar: dado2).isNotEmpty ||
      jugadasPosibles(ancla: dado2, aColocar: dado1).isNotEmpty;

  /// Devuelve un tablero nuevo con [valor] puesto en la casilla.
  /// Nada se borra: una zona llena se queda llena.
  Juego colocar(int fila, int columna, int valor) {
    final nuevo = [
      for (final f in tablero) [...f],
    ];
    nuevo[fila][columna] = valor;
    return Juego._(nuevo, nivel);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Juego || other.nivel.numero != nivel.numero) return false;
    if (other.tablero.length != tablero.length) return false;
    for (var f = 0; f < tablero.length; f++) {
      final a = tablero[f];
      final b = other.tablero[f];
      if (a.length != b.length) return false;
      for (var c = 0; c < a.length; c++) {
        if (a[c] != b[c]) return false;
      }
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(nivel.numero, Object.hashAll(tablero.expand((f) => f)));
}
