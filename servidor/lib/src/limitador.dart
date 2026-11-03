import 'servicios.dart';

/// Cuenta intentos por clave (correo, IP...) en una ventana deslizante.
///
/// Vive en memoria: se pierde al reiniciar el servidor y solo sirve con una
/// instancia. Para varias instancias haría falta un almacén compartido.
class Limitador {
  final int maximo;
  final Duration ventana;
  final Reloj _reloj;
  final Map<String, List<DateTime>> _intentos = {};

  /// Por encima de esta cantidad de claves se limpian todas las viejas.
  static const _limpiarDesde = 10000;

  Limitador({
    required Reloj reloj,
    this.maximo = 5,
    this.ventana = const Duration(minutes: 15),
  }) : _reloj = reloj;

  /// Cuánto falta para que [clave] pueda volver a intentar, o null si
  /// todavía puede.
  Duration? bloqueo(String clave) {
    final lista = _vigentes(clave);
    if (lista.length < maximo) return null;
    final libre = lista[lista.length - maximo].add(ventana);
    final falta = libre.difference(_reloj());
    return falta > Duration.zero ? falta : null;
  }

  /// Cuenta un intento de [clave].
  void registrar(String clave) {
    if (_intentos.length > _limpiarDesde) _limpiarTodo();
    (_intentos[clave] ??= []).add(_reloj());
  }

  /// Borra los intentos de [clave].
  void reiniciar(String clave) => _intentos.remove(clave);

  /// Claves que tienen intentos guardados (para las pruebas).
  int get claves => _intentos.length;

  List<DateTime> _vigentes(String clave) {
    final lista = _intentos[clave];
    if (lista == null) return const [];
    final desde = _reloj().subtract(ventana);
    lista.removeWhere((fecha) => !fecha.isAfter(desde));
    if (lista.isEmpty) _intentos.remove(clave);
    return lista;
  }

  void _limpiarTodo() {
    for (final clave in _intentos.keys.toList()) {
      _vigentes(clave);
    }
  }
}

/// Valor de la cabecera Retry-After: segundos enteros, redondeando arriba.
String segundosParaReintentar(Duration falta) {
  final segundos = (falta.inMilliseconds / 1000).ceil();
  return '${segundos < 1 ? 1 : segundos}';
}
