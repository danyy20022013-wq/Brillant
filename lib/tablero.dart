import 'package:equatable/equatable.dart';

import 'zona.dart';

/// El tablero: reúne las zonas y aplica las reglas al colocar números.
class Tablero extends Equatable {
  final String id;
  final List<Zona> zonas;

  const Tablero({required this.id, required this.zonas});

  Zona zonaPorId(String zonaId) =>
      zonas.firstWhere((zona) => zona.id == zonaId);

  bool get estaCompleto => zonas.every((zona) => zona.estaCompleta);

  /// Suma los puntos de cada zona según cuántos números lleva.
  int get puntajeTotal {
    var total = 0;
    for (final zona in zonas) {
      total += zona.tipo.puntuaciones[zona.valores.length] ?? 0;
    }
    return total;
  }

  /// Agrega [valor] a la zona si cabe y cumple la regla de su tipo.
  /// Si no se puede, devuelve el mismo tablero sin cambios.
  Tablero agregarValor(String zonaId, int valor) {
    final zona = zonaPorId(zonaId);
    if (zona.estaCompleta || !zona.tipo.esPosibleAgregar(zona.valores, valor)) {
      return this;
    }
    final nueva = zona.copyWith(valores: [...zona.valores, valor]);
    return copyWith(
      zonas: [for (final z in zonas) z.id == zonaId ? nueva : z],
    );
  }

  Tablero copyWith({List<Zona>? zonas}) =>
      Tablero(id: id, zonas: zonas ?? this.zonas);

  @override
  List<Object?> get props => [id, zonas];
}