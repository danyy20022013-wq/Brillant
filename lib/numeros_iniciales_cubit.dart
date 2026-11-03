import 'package:bloc/bloc.dart';

import 'juego.dart';

/// Cuántas casillas con estrella hay (una por zona inicial).
const cantidadNumerosIniciales = 6;

class NumerosInicialesEstado {
  final List<int?> valores;

  /// Mapa en el que se eligen los números. Sin mapa no se validan zonas.
  final Nivel? nivel;

  const NumerosInicialesEstado(this.valores, {this.nivel});

  factory NumerosInicialesEstado.vacio({Nivel? nivel}) =>
      NumerosInicialesEstado(
        List.filled(cantidadNumerosIniciales, null),
        nivel: nivel,
      );

  /// Las 6 casillas deben estar llenas.
  bool get completo => valores.every((v) => v != null);

  /// Los números elegidos no pueden repetirse.
  bool get tieneRepetidos {
    final elegidos = valores.whereType<int>().toList();
    return elegidos.toSet().length != elegidos.length;
  }

  /// true si la casilla [indice] repite el número de otra casilla.
  bool casillaRepetida(int indice) {
    final valor = valores[indice];
    if (valor == null) return false;
    return valores.where((v) => v == valor).length > 1;
  }

  /// Índice de la zona del mapa donde está la estrella [indice].
  int _zonaDe(int indice) {
    final p = nivel!.estrellas[indice];
    return nivel!.estructura.indiceZona[p.fila][p.columna];
  }

  /// true si [valor] respeta la regla de la zona de la estrella [indice],
  /// teniendo en cuenta los números de las otras estrellas de esa zona.
  /// Usa la misma regla que la partida (esPosibleAgregar del tipo).
  bool esPosible(int indice, int valor) {
    if (nivel == null) return true;
    final z = _zonaDe(indice);
    final otros = <int>[
      for (var i = 0; i < valores.length; i++)
        if (i != indice && valores[i] != null && _zonaDe(i) == z) valores[i]!,
    ];
    return nivel!.estructura.zonas[z].tipo.esPosibleAgregar(otros, valor);
  }

  /// true si la casilla [indice] tiene un número que rompe su regla.
  bool casillaInvalida(int indice) {
    final valor = valores[indice];
    return valor != null && !esPosible(indice, valor);
  }

  bool get tieneInvalidos {
    for (var i = 0; i < valores.length; i++) {
      if (casillaInvalida(i)) return true;
    }
    return false;
  }

  /// La regla de la zona de la estrella [indice] (null sin mapa).
  String? reglaDe(int indice) {
    if (nivel == null) return null;
    return nivel!.estructura.zonas[_zonaDe(indice)].tipo.descripcion;
  }

  /// Habilita el botón de Inicio.
  bool get esValido => completo && !tieneRepetidos && !tieneInvalidos;
}

class NumerosInicialesCubit extends Cubit<NumerosInicialesEstado> {
  /// [nivel] es opcional: sin mapa no se valida la regla de las zonas.
  NumerosInicialesCubit({Nivel? nivel})
      : super(NumerosInicialesEstado.vacio(nivel: nivel));

  /// Pone [valor] en la casilla [indice] (null la deja vacía).
  void seleccionar(int indice, int? valor) {
    final nuevos = [...state.valores];
    nuevos[indice] = valor;
    emit(NumerosInicialesEstado(nuevos, nivel: state.nivel));
  }
}
