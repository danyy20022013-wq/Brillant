import 'dart:convert';
import 'dart:io';

/// La configuración no es válida: el servidor no debe arrancar.
class ConfigException implements Exception {
  final String mensaje;

  const ConfigException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Lee un archivo .env: líneas CLAVE=valor. Ignora líneas vacías y las que
/// empiezan con #. Quita comillas simples o dobles alrededor del valor.
Map<String, String> leerArchivoEnv(String contenido) {
  final valores = <String, String>{};
  for (final linea in contenido.split(RegExp(r'\r?\n'))) {
    final texto = linea.trim();
    if (texto.isEmpty || texto.startsWith('#')) continue;
    final igual = texto.indexOf('=');
    if (igual <= 0) continue;
    final clave = texto.substring(0, igual).trim();
    var valor = texto.substring(igual + 1).trim();
    if (valor.length >= 2 &&
        ((valor.startsWith('"') && valor.endsWith('"')) ||
            (valor.startsWith("'") && valor.endsWith("'")))) {
      valor = valor.substring(1, valor.length - 1);
    }
    valores[clave] = valor;
  }
  return valores;
}

/// Junta el archivo .env con las variables de entorno. Las variables de
/// entorno tienen prioridad.
Map<String, String> combinarEntorno({
  required Map<String, String> archivo,
  required Map<String, String> entorno,
}) => {...archivo, ...entorno};

/// Valor de [clave] sin espacios, o null si falta o está vacío.
String? _texto(Map<String, String> variables, String clave) {
  final valor = variables[clave]?.trim();
  return (valor == null || valor.isEmpty) ? null : valor;
}

/// Configuración del servidor.
class Config {
  final String host;
  final int puerto;

  /// En producción solo se aceptan los orígenes de [origenesPermitidos];
  /// en desarrollo, cualquier puerto de localhost y 127.0.0.1.
  final bool produccion;
  final List<String> origenesPermitidos;

  /// Archivo SQLite con las cuentas.
  final String rutaBaseDatos;

  /// Costo de bcrypt. 10 tarda unos 200 ms en el equipo de desarrollo.
  final int costoBcrypt;

  /// Clave para firmar los tokens. Solo [Config.desde] garantiza que exista
  /// y tenga al menos 32 bytes; además Tokens vuelve a comprobarlo.
  final String jwtSecreto;

  /// Segundos de cada turno del multijugador.
  final int segundosTurno;

  /// Segundos que tiene un jugador caído para volver a su partida.
  final int segundosReconexion;

  const Config({
    this.segundosTurno = segundosPorDefecto,
    this.segundosReconexion = segundosPorDefecto,
    this.host = '127.0.0.1',
    this.puerto = 8080,
    this.produccion = false,
    this.origenesPermitidos = const [],
    this.rutaBaseDatos = 'brilliant.db',
    this.costoBcrypt = costoBcryptPorDefecto,
    this.jwtSecreto = '',
  });

  /// Bytes mínimos de JWT_SECRETO.
  static const minimoBytesJwtSecreto = 32;

  static const costoBcryptPorDefecto = 10;

  /// Rango permitido: menos de 10 es débil en producción, pero sirve en
  /// pruebas; más de 15 tarda varios segundos por inicio de sesión.
  static const costoBcryptMinimo = 4;
  static const costoBcryptMaximo = 15;

  /// Turno y plazo de reconexión del multijugador.
  static const segundosPorDefecto = 60;
  static const segundosMinimos = 10;
  static const segundosMaximos = 600;

  static int _segundos(Map<String, String> variables, String clave) {
    final texto = _texto(variables, clave) ?? '$segundosPorDefecto';
    final valor = int.tryParse(texto);
    if (valor == null || valor < segundosMinimos || valor > segundosMaximos) {
      throw ConfigException(
        '$clave debe ser un número de segundos entre $segundosMinimos y '
        '$segundosMaximos (llegó "$texto").',
      );
    }
    return valor;
  }

  /// Crea la configuración desde las variables (ya combinadas).
  /// Lanza [ConfigException] con una explicación si algo no es válido.
  factory Config.desde(Map<String, String> variables) {
    final puertoTexto = variables['PUERTO'] ?? '8080';
    final puerto = int.tryParse(puertoTexto);
    if (puerto == null || puerto < 1 || puerto > 65535) {
      throw ConfigException(
        'PUERTO debe ser un número entre 1 y 65535 (llegó "$puertoTexto").',
      );
    }

    final modo = (variables['MODO'] ?? 'desarrollo').trim().toLowerCase();
    if (modo != 'desarrollo' && modo != 'produccion') {
      throw ConfigException(
        'MODO debe ser "desarrollo" o "produccion" (llegó "$modo").',
      );
    }
    final produccion = modo == 'produccion';

    final origenes = (variables['ORIGENES_PERMITIDOS'] ?? '')
        .split(',')
        .map((o) => o.trim())
        .where((o) => o.isNotEmpty)
        .toList();
    if (produccion && origenes.isEmpty) {
      throw const ConfigException(
        'En producción ORIGENES_PERMITIDOS no puede estar vacío '
        '(ejemplo: https://brilliant.ejemplo.com).',
      );
    }

    // Sin espacios alrededor: un espacio por error no cuenta como clave.
    final secreto = variables['JWT_SECRETO']?.trim() ?? '';
    if (secreto.isEmpty) {
      throw const ConfigException(
        'Falta JWT_SECRETO, la clave con la que se firman los tokens. '
        'Genera una con "dart run bin/generar_secreto.dart" y ponla en el '
        'archivo .env o en una variable de entorno.',
      );
    }
    final bytesSecreto = utf8.encode(secreto).length;
    if (bytesSecreto < minimoBytesJwtSecreto) {
      throw ConfigException(
        'JWT_SECRETO es demasiado corta: tiene $bytesSecreto bytes y debe '
        'tener al menos $minimoBytesJwtSecreto. Genera una con '
        '"dart run bin/generar_secreto.dart".',
      );
    }

    final costoTexto =
        _texto(variables, 'COSTO_BCRYPT') ?? '$costoBcryptPorDefecto';
    final costo = int.tryParse(costoTexto);
    if (costo == null ||
        costo < costoBcryptMinimo ||
        costo > costoBcryptMaximo) {
      throw ConfigException(
        'COSTO_BCRYPT debe ser un número entre $costoBcryptMinimo y '
        '$costoBcryptMaximo (llegó "$costoTexto").',
      );
    }
    if (produccion && costo < costoBcryptPorDefecto) {
      throw ConfigException(
        'En producción COSTO_BCRYPT debe ser al menos '
        '$costoBcryptPorDefecto (llegó $costo).',
      );
    }

    return Config(
      host: _texto(variables, 'HOST') ?? '127.0.0.1',
      puerto: puerto,
      produccion: produccion,
      origenesPermitidos: List.unmodifiable(origenes),
      rutaBaseDatos: _texto(variables, 'RUTA_BASE_DATOS') ?? 'brilliant.db',
      costoBcrypt: costo,
      jwtSecreto: secreto,
      segundosTurno: _segundos(variables, 'SEGUNDOS_TURNO'),
      segundosReconexion: _segundos(variables, 'SEGUNDOS_RECONEXION'),
    );
  }

  /// Lee el archivo [rutaEnv] (si existe) y las variables de entorno.
  factory Config.cargar({String rutaEnv = '.env'}) {
    final archivo = File(rutaEnv);
    final delArchivo = archivo.existsSync()
        ? leerArchivoEnv(archivo.readAsStringSync())
        : <String, String>{};
    return Config.desde(
      combinarEntorno(archivo: delArchivo, entorno: Platform.environment),
    );
  }
}
