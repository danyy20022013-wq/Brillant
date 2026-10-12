import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'tablero.dart';
import 'zona.dart';

sealed class TableroEstado extends Equatable {
  const TableroEstado();

  @override
  List<Object?> get props => [];
}

/// El tablero está bloqueado hasta recibir sus zonas iniciales.
class TableroSinIniciar extends TableroEstado {
  const TableroSinIniciar();
}

class TableroListo extends TableroEstado {
  final Tablero tablero;

  const TableroListo(this.tablero);

  @override
  List<Object?> get props => [tablero];
}

class TableroCubit extends Cubit<TableroEstado> {
  TableroCubit() : super(const TableroSinIniciar());

  void iniciar({required String id, required List<Zona> zonas}) {
    if (zonas.isEmpty) return;
    emit(TableroListo(Tablero(id: id, zonas: zonas)));
  }

  void agregarValor(String zonaId, int valor) {
    final actual = state;
    if (actual is! TableroListo) return;
    emit(TableroListo(actual.tablero.agregarValor(zonaId, valor)));
  }
}