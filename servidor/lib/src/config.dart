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
}) =>
    {...archivo, ...entorno};

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

  const Config({
    this.host = '127.0.0.1',
    this.puerto = 8080,
    this.produccion = false,
    this.origenesPermitidos = const [],
    this.rutaBaseDatos = 'brilliant.db',
  });

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

    return Config(
      host: _texto(variables, 'HOST') ?? '127.0.0.1',
      puerto: puerto,
      produccion: produccion,
      origenesPermitidos: List.unmodifiable(origenes),
      rutaBaseDatos: _texto(variables, 'RUTA_BASE_DATOS') ?? 'brilliant.db',
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
