import 'dart:async';

/// Una tarea programada que se puede cancelar.
abstract interface class Tarea {
  void cancelar();
}

/// Programa acciones para más tarde. Se inyecta para que las pruebas puedan
/// adelantar el tiempo sin esperar (ver ProgramadorDePrueba en test/).
abstract interface class Programador {
  /// Ejecuta [accion] una vez, dentro de [espera].
  Tarea despues(Duration espera, void Function() accion);
}

/// El programador real, con Timer de dart:async.
class ProgramadorReal implements Programador {
  const ProgramadorReal();

  @override
  Tarea despues(Duration espera, void Function() accion) =>
      _TareaReal(Timer(espera, accion));
}

class _TareaReal implements Tarea {
  final Timer _timer;

  _TareaReal(this._timer);

  @override
  void cancelar() => _timer.cancel();
}
