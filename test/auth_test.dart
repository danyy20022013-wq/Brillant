import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/auth_cubit.dart';
import 'package:juego_brilliant/auth_repository.dart';

InMemoryAuthRepository _repo() =>
    InMemoryAuthRepository(retraso: Duration.zero);

void main() {
  group('InMemoryAuthRepository', () {
    test('registrar devuelve el usuario con el correo en minúsculas', () async {
      final repo = _repo();
      final usuario = await repo.registrar(
        nombre: ' Dany ',
        correo: ' Dany@Correo.COM ',
        contrasena: '123456',
      );

      expect(usuario.nombre, 'Dany');
      expect(usuario.correo, 'dany@correo.com');
    });

    test('no permite repetir el correo', () async {
      final repo = _repo();
      await repo.registrar(
        nombre: 'dany',
        correo: 'dany@correo.com',
        contrasena: '123456',
      );

      expect(
        repo.registrar(
          nombre: 'otro',
          correo: 'DANY@correo.com',
          contrasena: '123456',
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.mensaje,
            'mensaje',
            'Ese correo ya está registrado',
          ),
        ),
      );
    });

    test('no permite repetir el nombre de usuario', () async {
      final repo = _repo();
      await repo.registrar(
        nombre: 'dany',
        correo: 'uno@correo.com',
        contrasena: '123456',
      );

      expect(
        repo.registrar(
          nombre: 'DANY',
          correo: 'dos@correo.com',
          contrasena: '123456',
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.mensaje,
            'mensaje',
            'Ese nombre de usuario ya está en uso',
          ),
        ),
      );
    });

    test('inicia sesión con la cuenta registrada', () async {
      final repo = _repo();
      await repo.registrar(
        nombre: 'dany',
        correo: 'dany@correo.com',
        contrasena: '123456',
      );

      final usuario = await repo.iniciarSesion(
        correo: ' DANY@correo.com ',
        contrasena: '123456',
      );
      expect(usuario.nombre, 'dany');
    });

    test('rechaza contraseña incorrecta y correo desconocido igual', () async {
      final repo = _repo();
      await repo.registrar(
        nombre: 'dany',
        correo: 'dany@correo.com',
        contrasena: '123456',
      );

      Matcher incorrecto() => throwsA(
            isA<AuthException>().having(
              (e) => e.mensaje,
              'mensaje',
              'Correo o contraseña incorrectos',
            ),
          );

      expect(
        repo.iniciarSesion(correo: 'dany@correo.com', contrasena: 'mala'),
        incorrecto(),
      );
      expect(
        repo.iniciarSesion(correo: 'nadie@correo.com', contrasena: '123456'),
        incorrecto(),
      );
    });
  });

  group('AuthCubit', () {
    test('empieza sin sesión', () {
      final cubit = AuthCubit(_repo());
      expect(cubit.state, const AuthSinSesion());
    });

    test('registrar pasa por cargando y deja la sesión iniciada', () async {
      final cubit = AuthCubit(_repo());

      final esperado = expectLater(
        cubit.stream,
        emitsInOrder([
          const AuthSinSesion(cargando: true),
          const AuthConSesion(
            Usuario(nombre: 'dany', correo: 'dany@correo.com'),
          ),
        ]),
      );
      await cubit.registrar(
        nombre: 'dany',
        correo: 'dany@correo.com',
        contrasena: '123456',
      );
      await esperado;
    });

    test('un inicio de sesión incorrecto deja el error', () async {
      final cubit = AuthCubit(_repo());
      await cubit.iniciarSesion(correo: 'a@b.co', contrasena: '123456');

      expect(
        cubit.state,
        const AuthSinSesion(error: 'Correo o contraseña incorrectos'),
      );
    });

    test('limpiarError quita el mensaje', () async {
      final cubit = AuthCubit(_repo());
      await cubit.iniciarSesion(correo: 'a@b.co', contrasena: '123456');
      cubit.limpiarError();

      expect(cubit.state, const AuthSinSesion());
    });

    test('cerrar sesión vuelve al estado sin sesión', () async {
      final cubit = AuthCubit(_repo());
      await cubit.registrar(
        nombre: 'dany',
        correo: 'dany@correo.com',
        contrasena: '123456',
      );
      expect(cubit.state, isA<AuthConSesion>());

      await cubit.cerrarSesion();
      expect(cubit.state, const AuthSinSesion());
    });

    test('después de salir se puede volver a entrar', () async {
      final repo = _repo();
      final cubit = AuthCubit(repo);
      await cubit.registrar(
        nombre: 'dany',
        correo: 'dany@correo.com',
        contrasena: '123456',
      );
      await cubit.cerrarSesion();
      await cubit.iniciarSesion(
        correo: 'dany@correo.com',
        contrasena: '123456',
      );

      expect(cubit.state, isA<AuthConSesion>());
    });
  });
}