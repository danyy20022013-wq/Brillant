import 'package:bloc/bloc.dart';

/// Cuántas casillas con estrella hay (una por zona inicial).
const cantidadNumerosIniciales = 6;

class NumerosInicialesEstado {
  final List<int?> valores;

  const NumerosInicialesEstado(this.valores);

  factory NumerosInicialesEstado.vacio() =>
      NumerosInicialesEstado(List.filled(cantidadNumerosIniciales, null));

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

  /// Habilita el botón de Inicio.
  bool get esValido => completo && !tieneRepetidos;
}

class NumerosInicialesCubit extends Cubit<NumerosInicialesEstado> {
  NumerosInicialesCubit() : super(NumerosInicialesEstado.vacio());

  /// Pone [valor] en la casilla [indice] (null la deja vacía).
  void seleccionar(int indice, int? valor) {
    final nuevos = [...state.valores];
    nuevos[indice] = valor;
    emit(NumerosInicialesEstado(nuevos));
  }
}