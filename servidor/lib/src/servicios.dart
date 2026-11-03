import 'base_datos.dart';
import 'contrasenas.dart';

/// Devuelve la hora actual. Se inyecta para poder probar vencimientos y
/// límites de intentos sin esperar.
typedef Reloj = DateTime Function();

/// El reloj real, en UTC.
DateTime relojDelSistema() => DateTime.now().toUtc();

/// Todo lo que necesitan las rutas.
class Servicios {
  final RepositorioUsuarios usuarios;
  final Contrasenas contrasenas;
  final Reloj reloj;

  const Servicios({
    required this.usuarios,
    required this.contrasenas,
    this.reloj = relojDelSistema,
  });
}
