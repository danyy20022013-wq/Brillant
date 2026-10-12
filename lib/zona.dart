import 'package:equatable/equatable.dart';

import 'tipo.dart';

/// Un bloque del tablero con su tipo, su capacidad y los números
/// que ya se colocaron (en orden).
class Zona extends Equatable {
  final String id;
  final Tipo tipo;
  final int capacidad;
  final List<int> valores;

  const Zona({
    required this.id,
    required this.tipo,
    required this.capacidad,
    this.valores = const [],
  });

  bool get estaCompleta => valores.length >= capacidad;

  Zona copyWith({List<int>? valores}) {
    return Zona(
      id: id,
      tipo: tipo,
      capacidad: capacidad,
      valores: valores ?? this.valores,
    );
  }

  @override
  List<Object?> get props => [id, tipo, capacidad, valores];
}