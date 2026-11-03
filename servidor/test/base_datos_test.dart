import 'dart:io';

import 'package:servidor_brilliant/servidor_brilliant.dart';
import 'package:test/test.dart';

final _fecha = DateTime.utc(2026, 11, 3, 12);

UsuarioGuardado _crear(
  RepositorioUsuarios repo, {
  String nombre = 'dany',
  String correo = 'dany@correo.com',
}) =>
    repo.crear(
      nombre: nombre,
      correo: correo,
      hash: r'$2b$04$hash-de-prueba',
      creadoEn: _fecha,
    );

void main() {
  late RepositorioUsuarios repo;

  setUp(() => repo = RepositorioUsuarios.enMemoria());
  tearDown(() => repo.cerrar());

  test('empieza vacío', () {
    expect(repo.cantidad, 0);
    expect(repo.porCorreo('dany@correo.com'), isNull);
    expect(repo.porId(1), isNull);
  });

  test('crea la cuenta con id, nombre, correo, hash y fecha', () {
    final usuario = _crear(repo);

    expect(usuario.id, greaterThan(0));
    expect(usuario.nombre, 'dany');
    expect(usuario.correo, 'dany@correo.com');
    expect(usuario.hash, r'$2b$04$hash-de-prueba');
    expect(usuario.creadoEn, _fecha);
    expect(repo.cantidad, 1);

    final leido = repo.porId(usuario.id)!;
    expect(leido.nombre, 'dany');
    expect(leido.creadoEn, _fecha);
  });

  test('el correo se guarda en minúsculas y se busca sin distinguir', () {
    final usuario = _crear(repo, correo: '  Dany@Correo.COM ');
    expect(usuario.correo, 'dany@correo.com');
    expect(repo.porCorreo('DANY@correo.com')?.id, usuario.id);
  });

  test('correo duplicado (aunque cambien mayúsculas)', () {
    _crear(repo);
    expect(
      () => _crear(repo, nombre: 'otro', correo: 'DANY@correo.com'),
      throwsA(isA<CorreoDuplicado>()),
    );
    expect(repo.cantidad, 1);
  });

  test('nombre duplicado (aunque cambien mayúsculas)', () {
    _crear(repo);
    expect(
      () => _crear(repo, nombre: 'DANY', correo: 'otro@correo.com'),
      throwsA(isA<NombreDuplicado>()),
    );
    expect(repo.existeNombre('Dany'), isTrue);
    expect(repo.cantidad, 1);
  });

  test('borrar quita la cuenta y libera nombre y correo', () {
    final usuario = _crear(repo);

    expect(repo.borrar(usuario.id), isTrue);
    expect(repo.porId(usuario.id), isNull);
    expect(repo.porCorreo('dany@correo.com'), isNull);
    expect(repo.borrar(usuario.id), isFalse);

    final otra = _crear(repo);
    expect(otra.nombre, 'dany');
  });

  test('un id borrado nunca se reutiliza', () {
    final primera = _crear(repo);
    repo.borrar(primera.id);
    final segunda = _crear(repo);
    expect(segunda.id, greaterThan(primera.id));
  });

  test('la versión pública no incluye el hash', () {
    final usuario = _crear(repo);
    expect(usuario.aJsonPublico(), {
      'id': usuario.id,
      'nombre': 'dany',
      'correo': 'dany@correo.com',
    });
  });

  test('los datos raros se guardan como texto, sin inyección SQL', () {
    final raro = _crear(
      repo,
      nombre: "x'); DROP TABLE usuarios;--",
      correo: "a'@b.com",
    );
    expect(repo.porId(raro.id)?.nombre, "x'); DROP TABLE usuarios;--");
    expect(repo.cantidad, 1);
  });

  test('en un archivo, los datos siguen ahí al volver a abrir', () {
    final carpeta = Directory.systemTemp.createTempSync('brilliant_db_');
    addTearDown(() => carpeta.deleteSync(recursive: true));
    final ruta = '${carpeta.path}${Platform.pathSeparator}prueba.db';

    final primero = RepositorioUsuarios.abrir(ruta);
    final usuario = _crear(primero);
    primero.cerrar();

    final segundo = RepositorioUsuarios.abrir(ruta);
    expect(segundo.porId(usuario.id)?.correo, 'dany@correo.com');
    segundo.cerrar();
  });

  test('la configuración lee RUTA_BASE_DATOS', () {
    expect(Config.desde({}).rutaBaseDatos, 'brilliant.db');
    expect(
      Config.desde({'RUTA_BASE_DATOS': ' datos/cuentas.db '}).rutaBaseDatos,
      'datos/cuentas.db',
    );
  });
}
