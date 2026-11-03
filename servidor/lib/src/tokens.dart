import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import 'servicios.dart';

/// El token falta, está dañado, fue manipulado, usa otro algoritmo, está
/// firmado con otra clave o ya venció. A propósito no dice cuál de todas.
class TokenInvalido implements Exception {
  const TokenInvalido();
}

/// Token emitido y cuándo vence.
class TokenEmitido {
  final String token;
  final DateTime expiraEn;

  const TokenEmitido(this.token, this.expiraEn);
}

/// Crea y verifica tokens JWT HS256.
///
/// No confía en la cabecera del token: exige `alg: HS256` y `typ: JWT`, y
/// exige `exp` comprobándolo con el reloj inyectado (la librería solo lo
/// revisa si viene, y con el reloj real).
class Tokens {
  /// Largo mínimo de la clave secreta, en bytes UTF-8.
  static const minimoBytesSecreto = 32;

  final SecretKey _clave;
  final Reloj _reloj;
  final Duration vigencia;

  Tokens({
    required String secreto,
    required Reloj reloj,
    this.vigencia = const Duration(hours: 1),
  }) : _clave = SecretKey(secreto),
       _reloj = reloj {
    if (utf8.encode(secreto).length < minimoBytesSecreto) {
      throw ArgumentError(
        'La clave del JWT debe tener al menos $minimoBytesSecreto bytes',
      );
    }
  }

  /// Token para el usuario [idUsuario], válido durante [vigencia].
  TokenEmitido emitir(int idUsuario) {
    final ahora = _reloj().toUtc();
    final vence = ahora.add(vigencia);
    final token = JWT({
      'sub': '$idUsuario',
      'iat': _segundos(ahora),
      'exp': _segundos(vence),
    }).sign(_clave, algorithm: JWTAlgorithm.HS256, noIssueAt: true);
    return TokenEmitido(token, _desdeSegundos(_segundos(vence)));
  }

  /// Id del usuario del token. Lanza [TokenInvalido] si algo no cuadra.
  int verificar(String token) {
    final partes = token.split('.');
    if (partes.length != 3) throw const TokenInvalido();

    // 1. La cabecera debe decir exactamente HS256 / JWT.
    final cabecera = _decodificar(partes[0]);
    if (cabecera['alg'] != 'HS256' || cabecera['typ'] != 'JWT') {
      throw const TokenInvalido();
    }

    // 2. La firma debe ser válida con nuestra clave.
    final JWT jwt;
    try {
      jwt = JWT.verify(token, _clave, checkExpiresIn: false);
    } catch (_) {
      throw const TokenInvalido();
    }

    // 3. Debe tener exp y no haber vencido según nuestro reloj.
    final datos = jwt.payload;
    if (datos is! Map) throw const TokenInvalido();
    final exp = datos['exp'];
    if (exp is! int) throw const TokenInvalido();
    if (!_reloj().toUtc().isBefore(_desdeSegundos(exp))) {
      throw const TokenInvalido();
    }

    // 4. sub debe ser un id válido.
    final sub = datos['sub'];
    final id = sub is String ? int.tryParse(sub) : null;
    if (id == null || id <= 0) throw const TokenInvalido();
    return id;
  }

  static Map<String, Object?> _decodificar(String parte) {
    try {
      final datos = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parte))),
      );
      if (datos is Map<String, Object?>) return datos;
    } catch (_) {
      // cae al error de abajo
    }
    throw const TokenInvalido();
  }

  static int _segundos(DateTime fecha) => fecha.millisecondsSinceEpoch ~/ 1000;

  static DateTime _desdeSegundos(int segundos) =>
      DateTime.fromMillisecondsSinceEpoch(segundos * 1000, isUtc: true);
}
