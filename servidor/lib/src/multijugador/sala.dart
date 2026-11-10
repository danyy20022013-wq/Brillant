import 'package:reglas_brilliant/reglas_brilliant.dart';

import 'partida.dart';
import 'programador.dart';

/// Un jugador dentro de una sala.
class MiembroSala {
  final int id;
  final String nombre;
  bool listo = false;
  bool conectado = true;

  /// Salida del lobby o abandono de la partida si no vuelve a tiempo.
  Tarea? tareaDesconexion;

  MiembroSala(this.id, this.nombre);
}

/// Sala en memoria: lobby y, al iniciar, su partida.
class Sala {
  final String codigo;
  final Nivel nivel;
  final int maximo;
  final DateTime creadaEn;

  /// En orden de llegada. El primero es el anfitrión.
  final List<MiembroSala> miembros = [];

  Partida? partida;

  /// Caducidad del lobby.
  Tarea? tareaCaducidad;
  DateTime? caducaEn;

  /// Fin del plazo para mandar los números iniciales.
  Tarea? tareaNumeros;
  DateTime? vencenNumeros;

  /// Fin del turno actual.
  Tarea? tareaTurno;
  DateTime? venceTurno;

  /// Turno al que corresponde [tareaTurno].
  int turnoProgramado = 0;

  /// Cierre por no tener a nadie conectado.
  Tarea? tareaSinNadie;

  Sala({
    required this.codigo,
    required this.nivel,
    required this.maximo,
    required this.creadaEn,
  });

  bool get enLobby => partida == null;
  bool get terminada => partida?.fase == FasePartida.terminada;
  bool get llena => miembros.length >= maximo;
  bool get vacia => miembros.isEmpty;

  MiembroSala? get anfitrion => miembros.isEmpty ? null : miembros.first;

  MiembroSala? miembro(int id) {
    for (final m in miembros) {
      if (m.id == id) return m;
    }
    return null;
  }

  bool get nadieConectado => miembros.every((m) => !m.conectado);

  String get fase => switch (partida?.fase) {
    null => 'lobby',
    FasePartida.numeros => 'numeros',
    FasePartida.turnos => 'turnos',
    FasePartida.terminada => 'terminada',
  };

  /// Cancela todos los temporizadores de la sala.
  void cancelarTareas() {
    tareaCaducidad?.cancelar();
    tareaNumeros?.cancelar();
    tareaTurno?.cancelar();
    tareaSinNadie?.cancelar();
    for (final m in miembros) {
      m.tareaDesconexion?.cancelar();
    }
  }

  /// Estado COMPLETO de la sala: con esto la app puede reconstruir todo.
  Map<String, Object?> aJson(DateTime ahora) {
    final p = partida;
    int? segundosHasta(DateTime? fecha) {
      if (fecha == null) return null;
      final falta = fecha.difference(ahora).inMilliseconds;
      return falta <= 0 ? 0 : (falta / 1000).ceil();
    }

    Map<String, Object?> jugador(MiembroSala? m, JugadorPartida? j) {
      final id = m?.id ?? j!.id;
      return {
        'id': id,
        'nombre': m?.nombre ?? j!.nombre,
        'anfitrion': anfitrion?.id == id,
        'listo': m?.listo ?? false,
        'enSala': m != null,
        'conectado': m?.conectado ?? false,
        if (p != null) ...{
          'estado': j!.estado.name,
          'numerosEnviados': j.numeros != null,
          // Los números de los demás se ven al empezar los turnos.
          'tablero': j.tablero?.tablero,
          'puntaje': p.puntajeDe(id),
          'saltosPorTiempo': j.saltosPorTiempo,
        },
      };
    }

    return {
      'codigo': codigo,
      'mapa': nivel.numero,
      'maximo': maximo,
      'fase': fase,
      'anfitrion': anfitrion?.id,
      'jugadores': p == null
          ? [for (final m in miembros) jugador(m, null)]
          : [for (final j in p.jugadores) jugador(miembro(j.id), j)],
      if (p == null) ...{
        'caducaEn': caducaEn?.toIso8601String(),
        'segundosParaCaducar': segundosHasta(caducaEn),
      },
      if (p != null) ...{
        'vencenNumeros': p.fase == FasePartida.numeros
            ? vencenNumeros?.toIso8601String()
            : null,
        'segundosParaNumeros': p.fase == FasePartida.numeros
            ? segundosHasta(vencenNumeros)
            : null,
        'orden': p.orden,
        'turno': p.turnoDe == null
            ? null
            : {
                'jugador': p.turnoDe,
                'numero': p.numeroTurno,
                'dados': [p.dado1, p.dado2],
                'venceEn': venceTurno?.toIso8601String(),
                'segundosRestantes': segundosHasta(venceTurno),
              },
        'ordenZonas': p.ordenZonas,
        'ultimoMovimiento': p.ultimoMovimiento,
        'resultado': p.fase == FasePartida.terminada
            ? [for (final r in p.resultado()) r.aJson()]
            : null,
      },
    };
  }
}
