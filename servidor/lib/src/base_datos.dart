import 'package:sqlite3/sqlite3.dart';

/// Una cuenta guardada en la base de datos.
class UsuarioGuardado {
  final int id;
  final String nombre;

  /// Siempre en minúsculas.
  final String correo;

  /// Hash bcrypt de la contraseña (nunca la contraseña).
  final String hash;
  final DateTime creadoEn;

  const UsuarioGuardado({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.hash,
    required this.creadoEn,
  });

  /// Lo que se le puede mostrar al cliente (sin el hash).
  Map<String, Object> aJsonPublico() => {
        'id': id,
        'nombre': nombre,
        'correo': correo,
      };
}

/// Ya existe una cuenta con ese correo.
class CorreoDuplicado implements Exception {
  const CorreoDuplicado();
}

/// Ya existe una cuenta con ese nombre de usuario.
class NombreDuplicado implements Exception {
  const NombreDuplicado();
}

/// Acceso a la tabla de usuarios en SQLite.
///
/// - `id` usa AUTOINCREMENT: un id borrado nunca se reutiliza, así un token
///   viejo no puede apuntar a una cuenta nueva.
/// - Nombre y correo son únicos sin distinguir mayúsculas (COLLATE NOCASE).
class RepositorioUsuarios {
  final Database _db;

  RepositorioUsuarios._(this._db) {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE COLLATE NOCASE,
        correo TEXT NOT NULL UNIQUE COLLATE NOCASE,
        hash TEXT NOT NULL,
        creado_en TEXT NOT NULL
      )
    ''');
  }

  /// Abre (o crea) la base de datos en el archivo [ruta].
  factory RepositorioUsuarios.abrir(String ruta) =>
      RepositorioUsuarios._(sqlite3.open(ruta));

  /// Base de datos en memoria, para las pruebas.
  factory RepositorioUsuarios.enMemoria() =>
      RepositorioUsuarios._(sqlite3.openInMemory());

  static String normalizarCorreo(String correo) => correo.trim().toLowerCase();

  /// Crea la cuenta. Lanza [CorreoDuplicado] o [NombreDuplicado].
  ///
  /// Las llamadas a SQLite son síncronas y Dart corre en un solo hilo, así
  /// que entre la comprobación y el INSERT no puede colarse otra petición.
  UsuarioGuardado crear({
    required String nombre,
    required String correo,
    required String hash,
    required DateTime creadoEn,
  }) {
    final correoLimpio = normalizarCorreo(correo);
    final nombreLimpio = nombre.trim();
    if (porCorreo(correoLimpio) != null) throw const CorreoDuplicado();
    if (existeNombre(nombreLimpio)) throw const NombreDuplicado();

    final fecha = creadoEn.toUtc();
    _db.execute(
      'INSERT INTO usuarios (nombre, correo, hash, creado_en) '
      'VALUES (?, ?, ?, ?)',
      [nombreLimpio, correoLimpio, hash, fecha.toIso8601String()],
    );
    return UsuarioGuardado(
      id: _db.lastInsertRowId,
      nombre: nombreLimpio,
      correo: correoLimpio,
      hash: hash,
      creadoEn: fecha,
    );
  }

  UsuarioGuardado? porCorreo(String correo) => _uno(
        'SELECT * FROM usuarios WHERE correo = ?',
        [normalizarCorreo(correo)],
      );

  UsuarioGuardado? porId(int id) =>
      _uno('SELECT * FROM usuarios WHERE id = ?', [id]);

  bool existeNombre(String nombre) =>
      _db.select('SELECT 1 FROM usuarios WHERE nombre = ?', [nombre.trim()])
          .isNotEmpty;

  /// Borra la cuenta. Devuelve false si no existía.
  bool borrar(int id) {
    _db.execute('DELETE FROM usuarios WHERE id = ?', [id]);
    return _db.updatedRows > 0;
  }

  int get cantidad =>
      _db.select('SELECT COUNT(*) AS n FROM usuarios').single['n'] as int;

  void cerrar() => _db.close();

  UsuarioGuardado? _uno(String sql, List<Object?> parametros) {
    final filas = _db.select(sql, parametros);
    if (filas.isEmpty) return null;
    final fila = filas.single;
    return UsuarioGuardado(
      id: fila['id'] as int,
      nombre: fila['nombre'] as String,
      correo: fila['correo'] as String,
      hash: fila['hash'] as String,
      creadoEn: DateTime.parse(fila['creado_en'] as String),
    );
  }
}
