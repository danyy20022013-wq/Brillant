import 'base_datos.dart';
import 'contrasenas.dart';
import 'limitador.dart';
import 'tokens.dart';

/// Devuelve la hora actual. Se inyecta para poder probar vencimientos y
/// límites de intentos sin esperar.
typedef Reloj = DateTime Function();

/// El reloj real, en UTC.
DateTime relojDelSistema() => DateTime.now().toUtc();

/// Todo lo que necesitan las rutas.
class Servicios {
  final RepositorioUsuarios usuarios;
  final Contrasenas contrasenas;
  final Tokens tokens;
  final Reloj reloj;

  /// Fallos de inicio de sesión, por correo y por IP.
  final Limitador intentosSesion;

  /// Intentos de registro, por IP.
  final Limitador intentosRegistro;

  Servicios({
    required this.usuarios,
    required this.contrasenas,
    required String secretoJwt,
    this.reloj = relojDelSistema,
  }) : tokens = Tokens(secreto: secretoJwt, reloj: reloj),
       intentosSesion = Limitador(reloj: reloj),
       intentosRegistro = Limitador(reloj: reloj);
}
