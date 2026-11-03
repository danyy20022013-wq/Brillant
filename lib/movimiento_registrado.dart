import 'package:equatable/equatable.dart';

/// Un movimiento del historial de la partida: una colocación o un turno
/// saltado.
class MovimientoRegistrado extends Equatable {
  final int turno;

  /// Jugador que hizo el movimiento (0 = el primero).
  final int jugador;

  /// true si el jugador saltó el turno (entonces no hay colocación).
  final bool saltado;

  final int? ancla;
  final int? colocado;

  /// Casilla de la colocación, contando desde 0.
  final int? fila;
  final int? columna;

  /// Nombre de la zona de la casilla ("Rojo 1").
  final String? zona;

  const MovimientoRegistrado.colocacion({
    required this.turno,
    required this.jugador,
    required int this.ancla,
    required int this.colocado,
    required int this.fila,
    required int this.columna,
    required String this.zona,
  }) : saltado = false;

  const MovimientoRegistrado.salto({
    required this.turno,
    required this.jugador,
  })  : saltado = true,
        ancla = null,
        colocado = null,
        fila = null,
        columna = null,
        zona = null;

  /// Texto legible. En [individual] habla en segunda persona; con varios
  /// jugadores usa "J2". La fila y la columna se muestran desde 1.
  String texto({required bool individual}) {
    final quien = 'J${jugador + 1}';
    if (saltado) {
      return individual
          ? 'Turno $turno: saltaste el turno'
          : 'Turno $turno: $quien saltó el turno';
    }
    final accion = individual ? 'colocaste' : '$quien colocó';
    return 'Turno $turno: $accion un $colocado junto a un $ancla en la fila '
        '${fila! + 1}, columna ${columna! + 1} ($zona)';
  }

  @override
  List<Object?> get props =>
      [turno, jugador, saltado, ancla, colocado, fila, columna, zona];
}
